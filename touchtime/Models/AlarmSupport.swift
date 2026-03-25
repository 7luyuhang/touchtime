//
//  AlarmSupport.swift
//  touchtime
//
//  Shared AlarmKit models and helpers.
//

import Foundation
import AlarmKit
import UIKit
import SwiftUI

nonisolated struct TouchtimeAlarmMetadata: AlarmMetadata {
    // Empty metadata
}

enum AlarmRepeatRule: String, Codable, CaseIterable {
    case once
    case weekly

    var localizedTitle: String {
        switch self {
        case .once:
            return String(localized: "Once")
        case .weekly:
            return String(localized: "Weekly")
        }
    }
}

struct AlarmRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let hour: Int
    let minute: Int
    var isEnabled: Bool
    let createdAt: Date
    var sourceCityName: String?
    var sourceCityTimeZoneIdentifier: String?
    var sourceCityCustomName: String?
    var sourceCityHour: Int?
    var sourceCityMinute: Int?
    var eventTitle: String?
    var repeatRule: AlarmRepeatRule
    var repeatWeekdays: [Int]

    enum CodingKeys: String, CodingKey {
        case id
        case hour
        case minute
        case isEnabled
        case createdAt
        case sourceCityName
        case sourceCityTimeZoneIdentifier
        case sourceCityCustomName
        case sourceCityHour
        case sourceCityMinute
        case eventTitle
        case repeatRule
        case repeatWeekdays
    }

    init(
        id: UUID,
        hour: Int,
        minute: Int,
        isEnabled: Bool,
        createdAt: Date,
        sourceCityName: String? = nil,
        sourceCityTimeZoneIdentifier: String? = nil,
        sourceCityCustomName: String? = nil,
        sourceCityHour: Int? = nil,
        sourceCityMinute: Int? = nil,
        eventTitle: String? = nil,
        repeatRule: AlarmRepeatRule = .once,
        repeatWeekdays: [Int] = []
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.sourceCityName = sourceCityName
        self.sourceCityTimeZoneIdentifier = sourceCityTimeZoneIdentifier
        self.sourceCityCustomName = sourceCityCustomName
        self.sourceCityHour = sourceCityHour
        self.sourceCityMinute = sourceCityMinute
        self.eventTitle = eventTitle
        self.repeatRule = repeatRule
        self.repeatWeekdays = Self.normalizedWeekdays(repeatWeekdays)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        hour = try container.decode(Int.self, forKey: .hour)
        minute = try container.decode(Int.self, forKey: .minute)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        sourceCityName = try container.decodeIfPresent(String.self, forKey: .sourceCityName)
        sourceCityTimeZoneIdentifier = try container.decodeIfPresent(String.self, forKey: .sourceCityTimeZoneIdentifier)
        sourceCityCustomName = try container.decodeIfPresent(String.self, forKey: .sourceCityCustomName)
        sourceCityHour = try container.decodeIfPresent(Int.self, forKey: .sourceCityHour)
        sourceCityMinute = try container.decodeIfPresent(Int.self, forKey: .sourceCityMinute)
        eventTitle = try container.decodeIfPresent(String.self, forKey: .eventTitle)
        repeatRule = try container.decodeIfPresent(AlarmRepeatRule.self, forKey: .repeatRule) ?? .once
        let decodedWeekdays = try container.decodeIfPresent([Int].self, forKey: .repeatWeekdays) ?? []
        repeatWeekdays = Self.normalizedWeekdays(decodedWeekdays)
    }

    private static func normalizedWeekdays(_ weekdays: [Int]) -> [Int] {
        Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
    }
}

enum AlarmAuthorizationResult {
    case authorized
    case denied
    case failed(Error)
}

enum AlarmSupport {
    private static let alarmRecordsKey = "savedAlarmRecords"
    private static let alarmSnoozeEnabledKey = "alarmSnoozeEnabled"
    private static let alarmSnoozeDurationKey = "alarmSnoozeDuration"
    private static let defaultSnoozeDurationMinutes = 5

    private struct SnoozeSettings {
        let isEnabled: Bool
        let durationMinutes: Int

        var durationSeconds: TimeInterval {
            TimeInterval(durationMinutes * 60)
        }
    }

    static func loadRecords() -> [AlarmRecord] {
        guard let data = UserDefaults.standard.data(forKey: alarmRecordsKey),
              let decoded = try? JSONDecoder().decode([AlarmRecord].self, from: data) else {
            return []
        }

        return decoded
    }

    static func saveRecords(_ records: [AlarmRecord]) {
        guard let encoded = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(encoded, forKey: alarmRecordsKey)
    }

    @MainActor
    static func ensureAuthorization(using alarmManager: AlarmManager = .shared) async -> AlarmAuthorizationResult {
        switch alarmManager.authorizationState {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            do {
                let state = try await alarmManager.requestAuthorization()
                return state == .authorized ? .authorized : .denied
            } catch {
                return .failed(error)
            }
        @unknown default:
            return .denied
        }
    }

    static func scheduleAlarm(
        id: UUID,
        hour: Int,
        minute: Int,
        eventTitle: String? = nil,
        repeatRule: AlarmRepeatRule = .once,
        repeatWeekdays: [Int] = [],
        using alarmManager: AlarmManager = .shared
    ) async throws {
        let defaultAlarmTitle = String(localized: "Alarm")
        let trimmedTitle = eventTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = (trimmedTitle?.isEmpty == false ? trimmedTitle : nil) ?? defaultAlarmTitle
        let alarmTitle = LocalizedStringResource(stringLiteral: resolvedTitle)
        let doneText = LocalizedStringResource("Done")
        let snoozeText = LocalizedStringResource("Snooze")
        let snoozeSettings = currentSnoozeSettings()
        let secondaryButton = snoozeSettings.isEnabled
            ? AlarmButton(
                text: snoozeText,
                textColor: .black,
                systemImageName: "zzz"
            )
            : nil
        let secondaryButtonBehavior: AlarmPresentation.Alert.SecondaryButtonBehavior? = snoozeSettings.isEnabled ? .countdown : nil
        let alert: AlarmPresentation.Alert

        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(
                title: alarmTitle,
                secondaryButton: secondaryButton,
                secondaryButtonBehavior: secondaryButtonBehavior
            )
        } else {
            alert = AlarmPresentation.Alert(
                title: alarmTitle,
                stopButton: AlarmButton(
                    text: doneText,
                    textColor: .white,
                    systemImageName: "checkmark"
                ),
                secondaryButton: secondaryButton,
                secondaryButtonBehavior: secondaryButtonBehavior
            )
        }

        let attributes = AlarmAttributes<TouchtimeAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: .white
        )

        let recurrence: Alarm.Schedule.Relative.Recurrence
        switch repeatRule {
        case .once:
            recurrence = .never
        case .weekly:
            let localizedWeekdays = Array(Set(repeatWeekdays.filter { (1...7).contains($0) }))
                .sorted()
                .compactMap(localeWeekday(from:))
            recurrence = .weekly(localizedWeekdays.isEmpty ? [todayLocaleWeekday()] : localizedWeekdays)
        }

        let schedule = Alarm.Schedule.relative(
            .init(
                time: .init(hour: hour, minute: minute),
                repeats: recurrence
            )
        )

        let countdownDuration = snoozeSettings.isEnabled
            ? Alarm.CountdownDuration(preAlert: nil, postAlert: snoozeSettings.durationSeconds)
            : nil

        _ = try await alarmManager.schedule(
            id: id,
            configuration: AlarmManager.AlarmConfiguration<TouchtimeAlarmMetadata>(
                countdownDuration: countdownDuration,
                schedule: schedule,
                attributes: attributes
            )
        )
    }

    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private static func localeWeekday(from weekday: Int) -> Locale.Weekday? {
        switch weekday {
        case 1:
            return .sunday
        case 2:
            return .monday
        case 3:
            return .tuesday
        case 4:
            return .wednesday
        case 5:
            return .thursday
        case 6:
            return .friday
        case 7:
            return .saturday
        default:
            return nil
        }
    }

    private static func todayLocaleWeekday() -> Locale.Weekday {
        let currentWeekday = Calendar.current.component(.weekday, from: Date())
        return localeWeekday(from: currentWeekday) ?? .monday
    }

    private static func currentSnoozeSettings() -> SnoozeSettings {
        let defaults = UserDefaults.standard
        let isEnabled = defaults.bool(forKey: alarmSnoozeEnabledKey)
        let storedDuration = defaults.object(forKey: alarmSnoozeDurationKey) as? Int ?? defaultSnoozeDurationMinutes
        let clampedDuration = min(max(storedDuration, 1), 15)

        return SnoozeSettings(
            isEnabled: isEnabled,
            durationMinutes: clampedDuration
        )
    }
}
