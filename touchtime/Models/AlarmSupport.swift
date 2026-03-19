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

struct AlarmRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let hour: Int
    let minute: Int
    var isEnabled: Bool
    let createdAt: Date
    var sourceCityName: String?
    var sourceCityHour: Int?
    var sourceCityMinute: Int?
    var eventTitle: String?

    init(
        id: UUID,
        hour: Int,
        minute: Int,
        isEnabled: Bool,
        createdAt: Date,
        sourceCityName: String? = nil,
        sourceCityHour: Int? = nil,
        sourceCityMinute: Int? = nil,
        eventTitle: String? = nil
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.sourceCityName = sourceCityName
        self.sourceCityHour = sourceCityHour
        self.sourceCityMinute = sourceCityMinute
        self.eventTitle = eventTitle
    }
}

enum AlarmAuthorizationResult {
    case authorized
    case denied
    case failed(Error)
}

enum AlarmSupport {
    private static let alarmRecordsKey = "savedAlarmRecords"

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
        using alarmManager: AlarmManager = .shared
    ) async throws {
        let defaultAlarmTitle = String(localized: "Alarm")
        let trimmedTitle = eventTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = (trimmedTitle?.isEmpty == false ? trimmedTitle : nil) ?? defaultAlarmTitle
        let alarmTitle = LocalizedStringResource(stringLiteral: resolvedTitle)
        let doneText = LocalizedStringResource("Done")
        let alert: AlarmPresentation.Alert

        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(title: alarmTitle)
        } else {
            alert = AlarmPresentation.Alert(
                title: alarmTitle,
                stopButton: AlarmButton(
                    text: doneText,
                    textColor: .white,
                    systemImageName: "checkmark"
                )
            )
        }

        let attributes = AlarmAttributes<TouchtimeAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: .white
        )

        let schedule = Alarm.Schedule.relative(
            .init(
                time: .init(hour: hour, minute: minute),
                repeats: .never
            )
        )

        _ = try await alarmManager.schedule(
            id: id,
            configuration: .alarm(schedule: schedule, attributes: attributes)
        )
    }

    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
