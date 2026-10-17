//
//  DSTReminderManager.swift
//  touchtime
//
//  Created on 16/10/2026.
//

import Foundation
import UserNotifications

/// Reminds the user of a city's next DST change with a local notification
/// at 9:00 on the device's clock, the day before the change. One reminder
/// per time zone and change, so cities sharing a time zone share it.
final class DSTReminderManager {
    static let shared = DSTReminderManager()

    static let identifierPrefix = "dstReminder-"

    private static let reminderHour = 9

    private init() {}

    /// When the reminder for the change at `transitionDate` goes off; nil
    /// once that time has passed.
    func fireDate(before transitionDate: Date) -> Date? {
        let calendar = Calendar.current
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: transitionDate),
              let fireDate = calendar.date(bySettingHour: Self.reminderHour, minute: 0, second: 0, of: dayBefore),
              fireDate > Date() else {
            return nil
        }
        return fireDate
    }

    func isScheduled(timeZoneIdentifier: String, transitionDate: Date) async -> Bool {
        let identifier = Self.identifier(timeZoneIdentifier: timeZoneIdentifier, transitionDate: transitionDate)
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending.contains { $0.identifier == identifier }
    }

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

    /// Schedules the reminder; false when its time has passed or the
    /// request could not be added. `offsetChange` is how far the clocks
    /// move, in seconds (negative when they go back), and `dateText` the
    /// day of the change as the DST pill writes it, e.g. "Oct 25".
    func schedule(
        cityName: String,
        timeZoneIdentifier: String,
        transitionDate: Date,
        isStart: Bool,
        offsetChange: Int,
        dateText: String
    ) async -> Bool {
        guard let fireDate = fireDate(before: transitionDate) else { return false }

        let content = UNMutableNotificationContent()
        content.title = isStart ? String(localized: "DST Starts") : String(localized: "DST Ends")
        content.subtitle = cityName
        content.body = notificationBody(offsetChange: offsetChange, dateText: dateText)
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: Self.identifier(timeZoneIdentifier: timeZoneIdentifier, transitionDate: transitionDate),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    func cancel(timeZoneIdentifier: String, transitionDate: Date) {
        let identifier = Self.identifier(timeZoneIdentifier: timeZoneIdentifier, transitionDate: transitionDate)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// e.g. "Clocks go back 1 hour on Oct 25." Lord Howe Island's clocks
    /// move half an hour, hence minutes as well as hours.
    private func notificationBody(offsetChange: Int, dateText: String) -> String {
        let amount = Duration.seconds(abs(offsetChange))
            .formatted(.units(allowed: [.hours, .minutes], width: .wide))
        let format = offsetChange > 0
            ? String(localized: "Clocks go forward %@ on %@.")
            : String(localized: "Clocks go back %@ on %@.")
        return String(format: format, amount, dateText)
    }

    private static func identifier(timeZoneIdentifier: String, transitionDate: Date) -> String {
        "\(identifierPrefix)\(timeZoneIdentifier)-\(Int(transitionDate.timeIntervalSince1970))"
    }
}
