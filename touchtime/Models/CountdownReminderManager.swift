//
//  CountdownReminderManager.swift
//  touchtime
//
//  Created on 28/08/2026.
//

import Foundation
import AlarmKit
import UserNotifications

/// Schedules one reminder per countdown that has one, at the user-chosen
/// time on (or some days before) the event day: a local notification, or
/// an AlarmKit alarm like the ones in the Alarms sheet, depending on the
/// countdown's reminder kind.
final class CountdownReminderManager {
    static let shared = CountdownReminderManager()

    static let identifierPrefix = "countdownReminder-"

    /// UserDefaults key for the ids of the alarms scheduled last time, so
    /// they can be cancelled on the next pass even when their countdown
    /// has since been deleted or switched back to a notification.
    private static let scheduledAlarmIDsKey = "countdownReminderAlarmIDs"

    /// The reschedule in flight, if any; the next one waits for it so two
    /// quick store mutations can't interleave their cancel/schedule steps.
    private var rescheduleTask: Task<Void, Never>?

    private init() {}

    /// Asks for the permission a reminder of `kind` needs; true when it is
    /// (or becomes) granted.
    func requestAuthorization(for kind: CountdownItem.ReminderKind) async -> Bool {
        switch kind {
        case .notification:
            return await requestNotificationAuthorization()
        case .alarm:
            if case .authorized = await AlarmSupport.ensureAuthorization() {
                return true
            }
            return false
        }
    }

    /// Returns true when notifications are (or become) authorized.
    private func requestNotificationAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            return false
        default:
            return true
        }
    }

    /// Drops every pending countdown reminder, then schedules the next fire
    /// date for each countdown that has one. Called on every store mutation
    /// and when the app becomes active (so repeating reminders roll forward).
    func reschedule(for countdowns: [CountdownItem]) {
        let previousTask = rescheduleTask
        rescheduleTask = Task {
            await previousTask?.value
            await rescheduleNotifications(for: countdowns.filter { $0.reminderKind == .notification })
            await rescheduleAlarms(for: countdowns.filter { $0.reminderKind == .alarm })
        }
    }

    private func rescheduleNotifications(for countdowns: [CountdownItem]) async {
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
        let staleIds = pending.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
        if !staleIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleIds)
        }

        let authorization = await center.notificationSettings().authorizationStatus
        guard authorization == .authorized || authorization == .provisional else { return }

        let now = Date()
        let calendar = Calendar.current
        for item in countdowns {
            guard let fireDate = item.nextReminderFireDate(after: now) else { continue }

            let content = UNMutableNotificationContent()
            content.title = item.title
            switch item.reminderLeadDays {
            case 0:
                content.body = String(localized: "The event is today.")
            case 1:
                content.body = String(localized: "The event is tomorrow.")
            default:
                content.body = String(format: String(localized: "The event is in %d days."), item.reminderLeadDays)
            }
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.identifierPrefix + item.id.uuidString,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    /// Alarm reminders are one-shot AlarmKit alarms, one per countdown and
    /// keyed by the countdown's id. Like the notifications they are all
    /// cancelled and set again so title, time and date edits carry over.
    private func rescheduleAlarms(for countdowns: [CountdownItem]) async {
        let alarmManager = AlarmManager.shared
        let defaults = UserDefaults.standard

        let previousIDs = defaults.stringArray(forKey: Self.scheduledAlarmIDsKey) ?? []
        for id in previousIDs.compactMap(UUID.init(uuidString:)) {
            // A missing alarm (already rung, or stopped by the user) is fine.
            try? alarmManager.cancel(id: id)
        }
        defaults.set([String](), forKey: Self.scheduledAlarmIDsKey)

        // Never prompt from here; the editor asks when the kind is picked.
        guard alarmManager.authorizationState == .authorized else { return }

        let now = Date()
        var scheduledIDs: [String] = []
        for item in countdowns {
            guard let fireDate = item.nextReminderFireDate(after: now) else { continue }
            do {
                try await AlarmSupport.scheduleFixedAlarm(
                    id: item.id,
                    fireDate: fireDate,
                    eventTitle: item.title,
                    using: alarmManager
                )
                scheduledIDs.append(item.id.uuidString)
            } catch {
                // Left out this time; the next reschedule tries again.
            }
        }
        defaults.set(scheduledIDs, forKey: Self.scheduledAlarmIDsKey)
    }
}
