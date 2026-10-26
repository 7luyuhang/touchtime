//
//  HomeView+Timer.swift
//  touchtime
//

import SwiftUI

extension HomeView {
    var hasConfiguredHomeTimer: Bool {
        homeTimerConfiguredSeconds > 0
    }

    var homeTimerDisplayName: String {
        let trimmedName = homeTimerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? String(localized: "Timer") : trimmedName
    }

    private var homeTimerAlarmID: UUID? {
        UUID(uuidString: homeTimerAlarmIDRawValue)
    }

    private var homeTimerEndDate: Date? {
        guard homeTimerEndDateEpoch > 0 else { return nil }
        return Date(timeIntervalSince1970: homeTimerEndDateEpoch)
    }

    private func homeTimerRemainingFromEndDate(at date: Date) -> Int {
        guard let endDate = homeTimerEndDate else {
            return 0
        }

        let remaining = Int(ceil(endDate.timeIntervalSince(date)))
        return max(remaining, 0)
    }

    private func homeTimerRemainingSeconds(at date: Date) -> Int {
        guard hasConfiguredHomeTimer else {
            return 0
        }

        if homeTimerPaused {
            return max(0, min(homeTimerPausedRemainingSeconds, 59 * 60 + 59))
        }

        return homeTimerRemainingFromEndDate(at: date)
    }

    func startHomeTimer(
        durationSeconds: Int,
        startPaused: Bool = false,
        requestAlarmAuthorization: Bool = true
    ) {
        let clampedDuration = min(max(durationSeconds, 1), 59 * 60 + 59)
        homeTimerConfiguredSeconds = clampedDuration

        if startPaused {
            homeTimerEndDateEpoch = 0
            homeTimerPaused = true
            homeTimerPausedRemainingSeconds = clampedDuration
        } else {
            homeTimerEndDateEpoch = Date().addingTimeInterval(TimeInterval(clampedDuration)).timeIntervalSince1970
            homeTimerPaused = false
            homeTimerPausedRemainingSeconds = 0
        }

        homeTimerCompletionHandled = false

        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }

        refreshHomeTimerAlarm(
            requestAuthorization: requestAlarmAuthorization
        )
    }

    func handleHomeTimerTap() {
        guard hasConfiguredHomeTimer else { return }

        let remaining = homeTimerRemainingSeconds(at: Date())
        if remaining == 0 {
            startHomeTimer(durationSeconds: homeTimerConfiguredSeconds)
            return
        }

        if homeTimerPaused {
            let secondsToResume = max(1, min(homeTimerPausedRemainingSeconds, 59 * 60 + 59))
            homeTimerEndDateEpoch = Date().addingTimeInterval(TimeInterval(secondsToResume)).timeIntervalSince1970
            homeTimerPaused = false
            homeTimerPausedRemainingSeconds = 0
            homeTimerCompletionHandled = false
            refreshHomeTimerAlarm(requestAuthorization: true)
        } else {
            homeTimerPausedRemainingSeconds = remaining
            homeTimerPaused = true
            homeTimerEndDateEpoch = 0
            refreshHomeTimerAlarm(requestAuthorization: false)
        }

        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }

    func resetHomeTimer() {
        guard hasConfiguredHomeTimer else { return }
        startHomeTimer(
            durationSeconds: homeTimerConfiguredSeconds,
            startPaused: homeTimerPaused,
            requestAlarmAuthorization: !homeTimerPaused
        )
    }

    func renameHomeTimer() {
        newTimerName = homeTimerName.trimmingCharacters(in: .whitespacesAndNewlines)
        showingTimerRenameAlert = true

        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }

    func saveHomeTimerName() {
        let trimmedName = newTimerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousName = homeTimerName
        withAnimation(.smooth(duration: 0.25)) {
            homeTimerName = trimmedName
        }
        newTimerName = ""

        // Keep the Timer Recents entry for this timer in sync with the latest name
        RecentTimerStore.renameMatching(
            durationSeconds: homeTimerConfiguredSeconds,
            oldName: RecentTimerStore.normalizedName(previousName),
            newName: RecentTimerStore.normalizedName(trimmedName)
        )

        refreshHomeTimerAlarm(requestAuthorization: false)
    }

    func clearHomeTimer() {
        homeTimerConfiguredSeconds = 0
        homeTimerEndDateEpoch = 0
        homeTimerCompletionHandled = false
        homeTimerPaused = false
        homeTimerPausedRemainingSeconds = 0
        homeTimerName = ""
        refreshHomeTimerAlarm(requestAuthorization: false)

        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }

    func restoreHomeTimerStateIfNeeded() {
        defer {
            refreshHomeTimerAlarm(requestAuthorization: false)
        }

        if !homeTimerAlarmIDRawValue.isEmpty, homeTimerAlarmID == nil {
            homeTimerAlarmIDRawValue = ""
        }

        let clampedConfiguredSeconds = min(max(homeTimerConfiguredSeconds, 0), 59 * 60 + 59)
        if clampedConfiguredSeconds != homeTimerConfiguredSeconds {
            homeTimerConfiguredSeconds = clampedConfiguredSeconds
        }

        guard clampedConfiguredSeconds > 0 else {
            homeTimerEndDateEpoch = 0
            homeTimerCompletionHandled = false
            homeTimerPaused = false
            homeTimerPausedRemainingSeconds = 0
            return
        }

        if homeTimerPaused {
            let clampedPausedRemaining = min(max(homeTimerPausedRemainingSeconds, 0), 59 * 60 + 59)
            if clampedPausedRemaining != homeTimerPausedRemainingSeconds {
                homeTimerPausedRemainingSeconds = clampedPausedRemaining
            }
            if homeTimerPausedRemainingSeconds == 0 {
                homeTimerPausedRemainingSeconds = clampedConfiguredSeconds
            }
            homeTimerEndDateEpoch = 0
            homeTimerCompletionHandled = homeTimerPausedRemainingSeconds == 0
            return
        }

        if homeTimerEndDateEpoch <= 0 {
            homeTimerEndDateEpoch = Date().addingTimeInterval(TimeInterval(clampedConfiguredSeconds)).timeIntervalSince1970
            homeTimerCompletionHandled = false
            return
        }

        let remaining = homeTimerRemainingFromEndDate(at: Date())
        if remaining == 0 {
            // The timer ran out while this view was away: still count that run
            if !homeTimerCompletionHandled {
                recordHomeTimerCompletion()
            }
        } else {
            homeTimerCompletionHandled = false
        }
    }

    /// Marks the current run as finished, counting it once towards the
    /// usage count of its Recents entry.
    private func recordHomeTimerCompletion() {
        RecentTimerStore.recordCompletion(
            durationSeconds: homeTimerConfiguredSeconds,
            name: RecentTimerStore.normalizedName(homeTimerName)
        )
        homeTimerCompletionHandled = true
    }

    private func refreshHomeTimerAlarm(
        requestAuthorization: Bool
    ) {
        Task {
            await HomeTimerAlarm.refresh(requestAuthorization: requestAuthorization)
        }
    }

    func handleHomeTimerTick(at now: Date) {
        guard hasConfiguredHomeTimer, !homeTimerPaused else { return }

        let remaining = homeTimerRemainingSeconds(at: now)
        if remaining == 0 {
            guard !homeTimerCompletionHandled else { return }
            recordHomeTimerCompletion()

            if hapticEnabled {
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.prepare()
                notificationFeedback.notificationOccurred(.success)
            }
        } else if homeTimerCompletionHandled {
            homeTimerCompletionHandled = false
        }
    }
}
