//
//  WatchTimerStore.swift
//  touchtimeWatch
//
//  The timer, run as the iPhone app's is: for up to 59:59, counting down to
//  an end kept in the watch's own defaults, so it runs on with the app
//  closed, and ending with a notification where the iPhone rings an alarm,
//  as AlarmKit isn't on the watch.
//

import Foundation
import Observation
import UserNotifications

/// The time the timer is set to, and its run: counting down to an end,
/// paused with time left, or none.
@Observable
final class WatchTimerStore: NSObject, UNUserNotificationCenterDelegate {
    /// As on iPhone, the timer runs for at most 59:59.
    static let maxSeconds = 59 * 60 + 59

    enum Phase: Equatable {
        /// Set, but not started, cancelled, or run down to zero.
        case idle
        case running(endDate: Date)
        case paused(remaining: TimeInterval)
    }

    private enum Key {
        static let duration = "timerDuration"
        static let endDate = "timerEndDate"
        static let pausedRemaining = "timerPausedRemaining"
    }

    private nonisolated static let notificationID = "timer"

    /// The time the timer is set to, in seconds, which the pickers show
    /// between runs.
    var duration: Int {
        didSet { UserDefaults.standard.set(duration, forKey: Key.duration) }
    }

    /// The last run, as it was left: one counting down still, once its end
    /// has passed, is over.
    private var phase: Phase {
        didSet { save() }
    }

    /// The notification's replacement under way, which the next one waits
    /// for, so a pause can't take it away before the run's is in.
    private var notificationRefresh: Task<Void, Never>?

    override init() {
        let defaults = UserDefaults.standard
        // Two minutes, as on iPhone until a timer is first set
        duration = min(max(defaults.object(forKey: Key.duration) as? Int ?? 2 * 60, 0), Self.maxSeconds)
        let endDate = defaults.double(forKey: Key.endDate)
        let pausedRemaining = defaults.double(forKey: Key.pausedRemaining)
        if endDate > 0 {
            phase = .running(endDate: Date(timeIntervalSince1970: endDate))
        } else if pausedRemaining > 0 {
            phase = .paused(remaining: pausedRemaining)
        } else {
            phase = .idle
        }
        super.init()

        UNUserNotificationCenter.current().delegate = self
        refreshNotification(requestingAuthorization: false)
    }

    /// The end of the last run, even once it's passed, while it counts down.
    var endDate: Date? {
        if case .running(let endDate) = phase { endDate } else { nil }
    }

    /// The run at `date`, idle once its end has passed.
    func phase(at date: Date) -> Phase {
        if case .running(let endDate) = phase, endDate <= date {
            return .idle
        }
        return phase
    }

    /// Counted down to zero, and not started again since.
    func isFinished(at date: Date) -> Bool {
        if case .running(let endDate) = phase { endDate <= date } else { false }
    }

    /// Whole seconds left at `date`, rounded up as on iPhone, so the last
    /// second shows as 00:01 rather than 00:00.
    func remainingSeconds(at date: Date) -> Int {
        switch phase(at: date) {
        case .idle:
            0
        case .running(let endDate):
            Int(endDate.timeIntervalSince(date).rounded(.up))
        case .paused(let remaining):
            Int(remaining.rounded(.up))
        }
    }

    func start() {
        guard duration > 0 else { return }
        phase = .running(endDate: .now.addingTimeInterval(TimeInterval(duration)))
        refreshNotification(requestingAuthorization: true)
    }

    /// Sets the timer to `seconds`, kept within its range as the iPhone
    /// keeps a recent timer's, and starts it.
    func start(seconds: Int) {
        duration = min(max(seconds, 1), Self.maxSeconds)
        start()
    }

    func pause() {
        let now = Date.now
        guard case .running(let endDate) = phase(at: now) else { return }
        phase = .paused(remaining: endDate.timeIntervalSince(now))
        refreshNotification(requestingAuthorization: false)
    }

    func resume() {
        guard case .paused(let remaining) = phase else { return }
        phase = .running(endDate: .now.addingTimeInterval(remaining))
        refreshNotification(requestingAuthorization: true)
    }

    /// Back to the time it's set to.
    func cancel() {
        phase = .idle
        refreshNotification(requestingAuthorization: false)
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(endDate?.timeIntervalSince1970 ?? 0, forKey: Key.endDate)
        if case .paused(let remaining) = phase {
            defaults.set(remaining, forKey: Key.pausedRemaining)
        } else {
            defaults.set(0, forKey: Key.pausedRemaining)
        }
    }

    /// Replaces the notification with one at the run's end, or none while
    /// it's paused or over. Asks for permission first, when `requesting`, as
    /// the iPhone asks for its alarm's on starting or resuming the timer.
    private func refreshNotification(requestingAuthorization: Bool) {
        let previousRefresh = notificationRefresh
        notificationRefresh = Task {
            await previousRefresh?.value

            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
            guard case .running(let endDate) = phase(at: .now),
                  await isAuthorized(in: center, requesting: requestingAuthorization),
                  // Still the same run, after the wait for permission
                  phase(at: .now) == .running(endDate: endDate) else { return }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "Timer")
            content.body = Duration.seconds(duration).formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated))
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: Self.notificationID,
                content: content,
                // The interval must be positive, and the end can be only just ahead.
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(endDate.timeIntervalSinceNow, 1), repeats: false)
            )
            try? await center.add(request)
        }
    }

    private func isAuthorized(in center: UNUserNotificationCenter, requesting: Bool) async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined:
            guard requesting else { return false }
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .authorized, .provisional:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// The timer's end shows with the app open too, as the iPhone's alarm
    /// rings over its app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        notification.request.identifier == Self.notificationID ? [.banner, .sound, .list] : []
    }
}
