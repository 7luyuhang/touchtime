//
//  LiveActivityManager.swift
//  touchtime
//
//  Mirrors the Home timer and stopwatch onto their Live Activities.
//

import ActivityKit
import AppIntents
import SwiftUI

/// Keeps the timer and stopwatch Live Activities in step with the state the
/// Home cards persist, which stays the single source of truth. An activity
/// only starts from something the person did; otherwise it is just updated
/// or taken down, so one dismissed from the Lock Screen stays away.
@MainActor
enum LiveActivityManager {
    private static var syncTask: Task<Void, Never>?

    /// Queues a sync behind any that is still running.
    /// - Parameter allowStart: Whether a running timer or stopwatch without
    ///   an activity gets one.
    static func requestSync(allowStart: Bool) {
        let previousSync = syncTask
        syncTask = Task {
            await previousSync?.value
            await syncTimer(allowStart: allowStart)
            await syncStopwatch(allowStart: allowStart)
        }
    }

    /// Like `requestSync(allowStart:)`, returning once the activities are up to date.
    static func sync(allowStart: Bool) async {
        requestSync(allowStart: allowStart)
        await syncTask?.value
    }

    /// Carries out a Live Activity button: the same change the Home card
    /// would make, then the activities follow.
    static func perform(_ action: LiveActivityAction) async {
        let now = Date()

        switch action {
        case .toggleTimer:
            var timer = HomeTimerSnapshot()
            if timer.isFinished(at: now), !timer.completionHandled {
                // The run that just ended still counts, as when Home next appears
                RecentTimerStore.recordCompletion(
                    durationSeconds: timer.configuredSeconds,
                    name: RecentTimerStore.normalizedName(timer.name)
                )
            }
            timer.togglePlayPause(at: now)
            timer.save()
            await HomeTimerAlarm.refresh(requestAuthorization: false)

        case .cancelTimer:
            var timer = HomeTimerSnapshot()
            timer.clear()
            timer.save()
            await HomeTimerAlarm.refresh(requestAuthorization: false)

        case .toggleStopwatch:
            var stopwatch = StopwatchSnapshot.stored()
            guard !stopwatch.isFinished else { break }
            if stopwatch.isRunning {
                stopwatch.accumulatedSeconds = stopwatch.elapsed(at: now)
                stopwatch.startEpoch = 0
            } else {
                stopwatch.startEpoch = now.timeIntervalSince1970
            }
            stopwatch.save()

        case .lapOrResetStopwatch:
            var stopwatch = StopwatchSnapshot.stored()
            if stopwatch.isRunning {
                stopwatch.laps.append(stopwatch.currentLapElapsed(at: now))
            } else {
                // Reset files the session under the Stopwatch records, as on Home
                if stopwatch.hasStarted {
                    StopwatchRecordStore.remember(totalSeconds: stopwatch.elapsed(at: now), laps: stopwatch.laps)
                }
                stopwatch = StopwatchSnapshot(startEpoch: 0, accumulatedSeconds: 0, laps: [])
            }
            stopwatch.save()
        }

        await sync(allowStart: true)
    }

    // MARK: - Timer

    private static func syncTimer(allowStart: Bool) async {
        let content = timerContent(for: HomeTimerSnapshot(), at: Date())
        await reconcile(
            attributes: TimerActivityAttributes(),
            content: content,
            canStart: allowStart && content?.state.isRunning == true
        )
    }

    /// Nil once the timer is cleared or has finished.
    private static func timerContent(
        for timer: HomeTimerSnapshot,
        at now: Date
    ) -> ActivityContent<TimerActivityAttributes.ContentState>? {
        guard timer.isConfigured, !timer.isFinished(at: now) else { return nil }

        let state = TimerActivityAttributes.ContentState(
            title: timer.displayName,
            durationText: HomeTimerSection.formattedConfiguredDuration(seconds: timer.configuredSeconds),
            configuredSeconds: timer.clampedConfiguredSeconds,
            endDateEpoch: timer.runningEndDate?.timeIntervalSince1970 ?? 0,
            pausedRemainingSeconds: timer.isPaused ? timer.remainingSeconds(at: now) : 0
        )
        // Stale past the end: the activity shows the timer finished until it is taken down
        return ActivityContent(state: state, staleDate: state.endDate, relevanceScore: 100)
    }

    // MARK: - Stopwatch

    private static func syncStopwatch(allowStart: Bool) async {
        let stopwatch = StopwatchSnapshot.stored()
        let content = stopwatchContent(for: stopwatch)
        await reconcile(
            attributes: StopwatchActivityAttributes(title: String(localized: "Stopwatch")),
            content: content,
            canStart: allowStart && stopwatch.isRunning
        )
    }

    /// Nil once the stopwatch is reset.
    private static func stopwatchContent(
        for stopwatch: StopwatchSnapshot
    ) -> ActivityContent<StopwatchActivityAttributes.ContentState>? {
        guard stopwatch.hasStarted else { return nil }

        let state = StopwatchActivityAttributes.ContentState(
            startEpoch: stopwatch.startEpoch,
            accumulatedSeconds: stopwatch.accumulatedSeconds,
            lapsText: stopwatch.laps.isEmpty ? "" : HomeStopwatchSection.lapCountText(lapCount: stopwatch.laps.count)
        )
        return ActivityContent(state: state, staleDate: nil, relevanceScore: 50)
    }

    // MARK: - Activities

    /// Brings the activities of one kind in line with `content`: ends them
    /// when it is nil, otherwise keeps one up to date, starting it only
    /// when `canStart`.
    private static func reconcile<Attributes: ActivityAttributes & Sendable>(
        attributes: @autoclosure () -> Attributes,
        content: ActivityContent<Attributes.ContentState>?,
        canStart: Bool
    ) async {
        let activities = Activity<Attributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }

        guard let content else {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        if let activity = activities.first {
            for duplicate in activities.dropFirst() {
                await duplicate.end(nil, dismissalPolicy: .immediate)
            }
            if activity.content.state != content.state || activity.content.staleDate != content.staleDate {
                await activity.update(content)
            }
        } else if canStart, ActivityAuthorizationInfo().areActivitiesEnabled {
            do {
                _ = try Activity<Attributes>.request(attributes: attributes(), content: content)
            } catch {
                print("Failed to start Live Activity: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Stored Stopwatch

private extension StopwatchSnapshot {
    private enum Key {
        static let startEpoch = "homeStopwatchStartEpoch"
        static let accumulatedSeconds = "homeStopwatchAccumulatedSeconds"
        static let lapsData = "homeStopwatchLapsData"
    }

    /// The Home stopwatch, read from the keys the stopwatch views keep in `@AppStorage`.
    static func stored(in defaults: UserDefaults = .standard) -> StopwatchSnapshot {
        StopwatchSnapshot(
            startEpoch: defaults.double(forKey: Key.startEpoch),
            accumulatedSeconds: defaults.double(forKey: Key.accumulatedSeconds),
            laps: StopwatchLapStore.decode(defaults.data(forKey: Key.lapsData) ?? Data())
        )
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(startEpoch, forKey: Key.startEpoch)
        defaults.set(accumulatedSeconds, forKey: Key.accumulatedSeconds)
        defaults.set(laps.isEmpty ? Data() : StopwatchLapStore.encode(laps), forKey: Key.lapsData)
    }
}

// MARK: - Timer Alarm Stop

/// Runs when the timer's alarm is stopped, so the timer's Live Activity
/// leaves together with the alert.
struct TimerAlarmStopIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Timer Alarm"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await LiveActivityManager.sync(allowStart: false)
        return .result()
    }
}

// MARK: - Sync Triggers

extension View {
    /// Syncs the timer and stopwatch Live Activities whenever the Home timer
    /// or stopwatch changes, and each time the app comes to the foreground.
    func syncsLiveActivities() -> some View {
        modifier(LiveActivitySyncModifier())
    }
}

private struct LiveActivitySyncModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("homeTimerConfiguredSeconds") private var timerConfiguredSeconds = 0
    @AppStorage("homeTimerEndDateEpoch") private var timerEndDateEpoch: Double = 0
    @AppStorage("homeTimerPaused") private var timerPaused = false
    @AppStorage("homeTimerPausedRemainingSeconds") private var timerPausedRemainingSeconds = 0
    @AppStorage("homeTimerName") private var timerName = ""
    @AppStorage("homeTimerCompletionHandled") private var timerCompletionHandled = false
    @AppStorage("homeStopwatchStartEpoch") private var stopwatchStartEpoch: Double = 0
    @AppStorage("homeStopwatchAccumulatedSeconds") private var stopwatchAccumulatedSeconds: Double = 0
    @AppStorage("homeStopwatchLapsData") private var stopwatchLapsData = Data()

    /// Everything the timer's activity shows or depends on.
    private struct TimerFingerprint: Equatable {
        let configuredSeconds: Int
        let endDateEpoch: Double
        let isPaused: Bool
        let pausedRemainingSeconds: Int
        let name: String
        let completionHandled: Bool
    }

    /// Everything the stopwatch's activity shows or depends on.
    private struct StopwatchFingerprint: Equatable {
        let startEpoch: Double
        let accumulatedSeconds: Double
        let lapsData: Data
    }

    private var timerFingerprint: TimerFingerprint {
        TimerFingerprint(
            configuredSeconds: timerConfiguredSeconds,
            endDateEpoch: timerEndDateEpoch,
            isPaused: timerPaused,
            pausedRemainingSeconds: timerPausedRemainingSeconds,
            name: timerName,
            completionHandled: timerCompletionHandled
        )
    }

    private var stopwatchFingerprint: StopwatchFingerprint {
        StopwatchFingerprint(
            startEpoch: stopwatchStartEpoch,
            accumulatedSeconds: stopwatchAccumulatedSeconds,
            lapsData: stopwatchLapsData
        )
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: timerFingerprint) {
                LiveActivityManager.requestSync(allowStart: true)
            }
            .onChange(of: stopwatchFingerprint) {
                LiveActivityManager.requestSync(allowStart: true)
            }
            .onChange(of: scenePhase, initial: true) { _, newPhase in
                guard newPhase == .active else { return }
                LiveActivityManager.requestSync(allowStart: false)
            }
    }
}
