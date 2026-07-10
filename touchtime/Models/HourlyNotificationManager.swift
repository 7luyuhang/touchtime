//
//  HourlyNotificationManager.swift
//  touchtime
//
//  Created on 03/07/2026.
//

import Foundation
import UserNotifications

/// Schedules local notifications on the hour (system default notifications).
/// Title: On the Hour
/// Body:  Shanghai 17:00 · New York 05:00    (selected cities)
final class HourlyNotificationManager: NSObject {
    static let shared = HourlyNotificationManager()

    // UserDefaults keys (shared with SettingsView)
    static let enabledKey = "hourlyNotificationEnabled"
    static let selectedCityIdsKey = "hourlyNotificationCityIds"

    private let identifierPrefix = "hourlyNotification-"
    private let hoursToSchedule = 24

    private override init() {
        super.init()
        // Present our notifications as banners even while the app is in the foreground
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Selected cities persistence

    static func loadSelectedCityIds() -> Set<UUID> {
        guard let raw = UserDefaults.standard.string(forKey: selectedCityIdsKey), !raw.isEmpty else {
            return []
        }
        return Set(raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }

    static func saveSelectedCityIds(_ ids: Set<UUID>) {
        let raw = ids.map(\.uuidString).joined(separator: ",")
        UserDefaults.standard.set(raw, forKey: selectedCityIdsKey)
    }

    // MARK: - Authorization

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

    /// Turns the in-app toggle off when notification permission has been revoked in system Settings.
    /// Call when the app becomes active.
    func syncEnabledWithAuthorization() {
        Task {
            let defaults = UserDefaults.standard
            guard defaults.bool(forKey: Self.enabledKey) else { return }

            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            if status == .denied {
                await MainActor.run {
                    defaults.set(false, forKey: Self.enabledKey)
                }
                cancelAll()
            }
        }
    }

    // MARK: - Scheduling

    /// Re-reads settings and reschedules the next 24 on-the-hour notifications.
    /// Call after any related setting changes or when the app becomes active.
    func reschedule() {
        Task {
            let center = UNUserNotificationCenter.current()

            // Remove previously scheduled hourly notifications
            let pending = await center.pendingNotificationRequests()
            let staleIds = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            if !staleIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: staleIds)
            }

            let defaults = UserDefaults.standard
            guard defaults.bool(forKey: Self.enabledKey) else { return }

            let authorization = await center.notificationSettings().authorizationStatus
            guard authorization == .authorized || authorization == .provisional else { return }

            let calendar = Calendar.current
            guard let firstHour = calendar.nextDate(
                after: Date(),
                matching: DateComponents(minute: 0, second: 0),
                matchingPolicy: .nextTime
            ) else { return }

            for hourOffset in 0..<hoursToSchedule {
                guard let fireDate = calendar.date(byAdding: .hour, value: hourOffset, to: firstHour) else { continue }

                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let identifier = identifierPrefix + String(Int(fireDate.timeIntervalSince1970))

                let request = UNNotificationRequest(identifier: identifier, content: makeContent(for: fireDate), trigger: trigger)
                try? await center.add(request)
            }
        }
    }

    /// Removes all pending hourly notifications.
    func cancelAll() {
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let ids = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }

    // MARK: - Helpers

    private func makeContent(for date: Date) -> UNMutableNotificationContent {
        let use24Hour = UserDefaults.standard.bool(forKey: "use24HourFormat")

        let content = UNMutableNotificationContent()
        content.title = String(localized: "On the Hour")
        let body = loadSelectedClocks()
            .compactMap { clock -> String? in
                guard let timeZone = TimeZone(identifier: clock.timeZoneIdentifier) else { return nil }
                return "\(clock.localizedCityName) \(timeString(for: date, in: timeZone, use24Hour: use24Hour))"
            }
            .joined(separator: " · ")
        if !body.isEmpty {
            content.body = body
        }
        content.sound = .default
        return content
    }

    /// Selected world clocks, in the same order as the saved clock list.
    private func loadSelectedClocks() -> [WorldClock] {
        let selectedIds = Self.loadSelectedCityIds()
        guard !selectedIds.isEmpty else { return [] }

        guard let data = UserDefaults.standard.data(forKey: "savedWorldClocks"),
              let clocks = try? JSONDecoder().decode([WorldClock].self, from: data) else {
            return []
        }
        return clocks.filter { selectedIds.contains($0.id) }
    }

    fileprivate func isHourlyNotification(_ notification: UNNotification) -> Bool {
        notification.request.identifier.hasPrefix(identifierPrefix)
    }

    private func timeString(for date: Date, in timeZone: TimeZone, use24Hour: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        if use24Hour {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm a"
            formatter.amSymbol = "am"
            formatter.pmSymbol = "pm"
        }
        return formatter.string(from: date)
    }
}

extension HourlyNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show our hourly/test notifications even while the app is open
        isHourlyNotification(notification) ? [.banner, .sound] : []
    }
}
