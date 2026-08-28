//
//  CountdownReminderManager.swift
//  touchtime
//
//  Created on 28/08/2026.
//

import Foundation
import UserNotifications

/// Schedules one local notification per countdown with a reminder: on the
/// event day, at the user-chosen time.
final class CountdownReminderManager {
    static let shared = CountdownReminderManager()

    static let identifierPrefix = "countdownReminder-"

    private init() {}

    /// Returns true when notifications are (or become) authorized.
    func requestAuthorization() async -> Bool {
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
        Task {
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
                content.body = String(localized: "The event is today.")
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
    }
}
