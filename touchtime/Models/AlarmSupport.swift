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
    /// The alarm time on the device's clock. For an alarm that keeps a
    /// city's clock, it follows that city's time (`syncDeviceTimeWithCity`).
    private(set) var hour: Int
    private(set) var minute: Int
    var isEnabled: Bool
    let createdAt: Date
    var sourceCityName: String?
    /// The city whose clock the alarm keeps. Nil for an alarm on the
    /// device's own clock, including one set from Local.
    var sourceCityTimeZoneIdentifier: String?
    var sourceCityCustomName: String?
    var sourceCityHour: Int?
    var sourceCityMinute: Int?
    var eventTitle: String?
    var repeatRule: AlarmRepeatRule
    /// Repeat days on the device's clock (1 = Sunday)
    private(set) var repeatWeekdays: [Int]
    /// The repeat days on the city's clock, for an alarm that keeps one.
    /// `repeatWeekdays` follows them; nil until the record is first synced.
    private(set) var sourceCityRepeatWeekdays: [Int]?

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
        case sourceCityRepeatWeekdays
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
        if let decodedCityWeekdays = try container.decodeIfPresent([Int].self, forKey: .sourceCityRepeatWeekdays) {
            sourceCityRepeatWeekdays = Self.normalizedWeekdays(decodedCityWeekdays)
        }

        // Alarms set from Local used to save the device's time zone, which
        // would now pin them to the city the device was in at the time
        if let cityName = sourceCityCustomName ?? sourceCityName,
           Self.localCityNames.contains(cityName) {
            sourceCityTimeZoneIdentifier = nil
        }
    }

    /// The city's time zone, for an alarm that keeps a city's clock
    var cityTimeZone: TimeZone? {
        guard sourceCityHour != nil, sourceCityMinute != nil,
              let sourceCityTimeZoneIdentifier else { return nil }
        return TimeZone(identifier: sourceCityTimeZoneIdentifier)
    }

    /// When the city's clock next reads the alarm time, on one of the repeat
    /// days for a weekly alarm. Nil for an alarm on the device's clock.
    func nextCityOccurrence(after date: Date = Date()) -> CityAlarmOccurrence? {
        let cityWeekdays = repeatRule == .weekly ? sourceCityRepeatWeekdays ?? [] : []
        return nextCityOccurrence(after: date, onWeekdays: cityWeekdays)
    }

    /// Moves the device time and repeat days to where the city's clock puts
    /// them now, as daylight saving or travel shifts either clock.
    mutating func syncDeviceTimeWithCity(at date: Date = Date()) {
        guard let sourceCityHour, let sourceCityMinute else { return }

        if sourceCityRepeatWeekdays == nil,
           let occurrence = nextCityOccurrence(after: date, onWeekdays: []) {
            // Saved before repeat days were kept on the city's clock: they are
            // days on the device's clock, picked while it read `hour:minute`.
            // Of the day shifts that give that time, take the one nearest
            // today's, as the clocks are at most a daylight saving hour apart
            // from when the alarm was set.
            let cityMinutes = sourceCityHour * 60 + sourceCityMinute
            let currentGap = occurrence.dayShift * 1440 + occurrence.deviceHour * 60 + occurrence.deviceMinute - cityMinutes
            let savedGapWithinDay = hour * 60 + minute - cityMinutes
            let savedDayShift = Int((Double(currentGap - savedGapWithinDay) / 1440).rounded())
            sourceCityRepeatWeekdays = Self.weekdays(repeatWeekdays, shiftedBy: -savedDayShift)
        }

        guard let occurrence = nextCityOccurrence(after: date) else { return }
        hour = occurrence.deviceHour
        minute = occurrence.deviceMinute
        repeatWeekdays = Self.weekdays(sourceCityRepeatWeekdays ?? [], shiftedBy: occurrence.dayShift)
    }

    /// Sets the repeat days, as picked on the device's clock. An alarm that
    /// keeps a city's clock remembers them as that city's days, so they move
    /// with its time.
    mutating func setRepeatWeekdays(_ weekdays: [Int], at date: Date = Date()) {
        repeatWeekdays = Self.normalizedWeekdays(weekdays)

        guard let occurrence = nextCityOccurrence(after: date, onWeekdays: []) else { return }
        sourceCityRepeatWeekdays = Self.weekdays(repeatWeekdays, shiftedBy: -occurrence.dayShift)
        syncDeviceTimeWithCity(at: date)
    }

    /// Whether `other` is set for the same time on the same clock
    func isSetForSameTime(as other: AlarmRecord) -> Bool {
        guard cityTimeZone != nil else {
            return other.cityTimeZone == nil && hour == other.hour && minute == other.minute
        }

        return sourceCityTimeZoneIdentifier == other.sourceCityTimeZoneIdentifier
            && sourceCityHour == other.sourceCityHour
            && sourceCityMinute == other.sourceCityMinute
    }

    private func nextCityOccurrence(after date: Date, onWeekdays cityWeekdays: [Int]) -> CityAlarmOccurrence? {
        guard let cityTimeZone, let sourceCityHour, let sourceCityMinute else { return nil }
        return AlarmSupport.nextCityOccurrence(
            hour: sourceCityHour,
            minute: sourceCityMinute,
            in: cityTimeZone,
            onWeekdays: cityWeekdays,
            after: date
        )
    }

    /// The city name alarms set from Local were saved with, in each of the
    /// app's languages
    private static let localCityNames: Set<String> = ["Local", "本地", String(localized: "Local")]

    private static func normalizedWeekdays(_ weekdays: [Int]) -> [Int] {
        Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
    }

    /// `weekdays` moved `days` later, wrapping around the week
    private static func weekdays(_ weekdays: [Int], shiftedBy days: Int) -> [Int] {
        normalizedWeekdays(weekdays.map { (($0 - 1 + days) % 7 + 7) % 7 + 1 })
    }
}

/// A moment a city's clock reads an alarm time, and where it falls on the
/// device's clock
struct CityAlarmOccurrence {
    let date: Date
    let deviceHour: Int
    let deviceMinute: Int
    /// How many days the device's date is ahead of the city's at that
    /// moment: -1 while the device is still on the day before
    let dayShift: Int
}

enum AlarmAuthorizationResult {
    case authorized
    case denied
    case failed(Error)
}

enum AlarmSupport {
    private static let alarmRecordsKey = "savedAlarmRecords"
    /// The resync in progress, which the next one waits for, so two never
    /// cancel and reschedule the same alarm at once
    private static var cityAlarmResync: Task<Void, Never>?

    /// The saved alarms, with the device times of those that keep a city's
    /// clock brought up to date
    static func loadRecords() -> [AlarmRecord] {
        syncedWithCityClocks(savedRecords())
    }

    static func saveRecords(_ records: [AlarmRecord]) {
        guard let encoded = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(encoded, forKey: alarmRecordsKey)
    }

    /// Moves weekly alarms set from a city's time to where that city's clock
    /// now puts them on the device's clock, after daylight saving or a time
    /// zone change on either side. AlarmKit repeats an alarm only at a time
    /// on the device's clock, so this has to run whenever that may have
    /// shifted: when the app becomes active, and when the clock changes
    /// while it is.
    static func resyncCityAlarms(using alarmManager: AlarmManager = .shared) async {
        let previousResync = cityAlarmResync
        let resync = Task {
            await previousResync?.value
            await performCityAlarmResync(using: alarmManager)
        }
        cityAlarmResync = resync
        await resync.value
    }

    /// When `timeZone`'s clock next reads `hour:minute` after `date`, on one
    /// of `weekdays` (1 = Sunday) when given, and where that falls on the
    /// device's clock
    static func nextCityOccurrence(
        hour: Int,
        minute: Int,
        in timeZone: TimeZone,
        onWeekdays weekdays: [Int] = [],
        after date: Date = Date()
    ) -> CityAlarmOccurrence? {
        var cityCalendar = Calendar(identifier: .gregorian)
        cityCalendar.timeZone = timeZone
        var deviceCalendar = Calendar(identifier: .gregorian)
        deviceCalendar.timeZone = .current

        let matchingComponents = weekdays.isEmpty
            ? [DateComponents(hour: hour, minute: minute)]
            : weekdays.map { DateComponents(hour: hour, minute: minute, weekday: $0) }
        guard let occurrenceDate = matchingComponents
            .compactMap({ cityCalendar.nextDate(after: date, matching: $0, matchingPolicy: .nextTime) })
            .min() else { return nil }

        let deviceComponents = deviceCalendar.dateComponents([.hour, .minute, .weekday], from: occurrenceDate)
        guard let deviceHour = deviceComponents.hour,
              let deviceMinute = deviceComponents.minute,
              let deviceWeekday = deviceComponents.weekday else { return nil }

        // UTC offsets are at most 26 hours apart, so the dates are at most
        // two days apart either way
        var dayShift = (deviceWeekday - cityCalendar.component(.weekday, from: occurrenceDate) + 7) % 7
        if dayShift > 3 {
            dayShift -= 7
        }

        return CityAlarmOccurrence(
            date: occurrenceDate,
            deviceHour: deviceHour,
            deviceMinute: deviceMinute,
            dayShift: dayShift
        )
    }

    private static func savedRecords() -> [AlarmRecord] {
        guard let data = UserDefaults.standard.data(forKey: alarmRecordsKey),
              let decoded = try? JSONDecoder().decode([AlarmRecord].self, from: data) else {
            return []
        }

        return decoded
    }

    private static func syncedWithCityClocks(_ records: [AlarmRecord], at date: Date = Date()) -> [AlarmRecord] {
        records.map { record in
            var record = record
            record.syncDeviceTimeWithCity(at: date)
            return record
        }
    }

    private static func performCityAlarmResync(using alarmManager: AlarmManager) async {
        let now = Date()
        let storedRecords = savedRecords()
        let records = syncedWithCityClocks(storedRecords, at: now)
        if records != storedRecords {
            saveRecords(records)
        }

        guard alarmManager.authorizationState == .authorized,
              let alarms = try? alarmManager.alarms else { return }

        for record in records where record.cityTimeZone != nil {
            // Leave alone an alarm that has already rung, or is ringing or snoozed
            guard let alarm = alarms.first(where: { $0.id == record.id }),
                  alarm.state == .scheduled else { continue }

            let wantedSchedule = alarmSchedule(for: record, at: now)
            guard needsReschedule(alarm.schedule, toMatch: wantedSchedule) else { continue }

            try? alarmManager.cancel(id: record.id)
            do {
                try await scheduleAlarm(for: record, on: wantedSchedule, using: alarmManager)
            } catch {
                // Better on its old time than gone
                if let oldSchedule = alarm.schedule {
                    try? await scheduleAlarm(for: record, on: oldSchedule, using: alarmManager)
                }
            }
        }
    }

    /// Whether an alarm scheduled on `current` rings at a different time
    /// than `wanted`
    private static func needsReschedule(_ current: Alarm.Schedule?, toMatch wanted: Alarm.Schedule) -> Bool {
        guard let current else { return true }

        switch (current, wanted) {
        case (.fixed, .fixed):
            // A fixed moment doesn't drift
            return false
        case (.relative(let currentRelative), .relative(let wantedRelative)):
            return currentRelative.time != wantedRelative.time
                || repeatDays(of: currentRelative) != repeatDays(of: wantedRelative)
        default:
            return true
        }
    }

    private static func repeatDays(of relative: Alarm.Schedule.Relative) -> Set<Locale.Weekday> {
        switch relative.repeats {
        case .weekly(let weekdays):
            return Set(weekdays)
        case .never:
            return []
        @unknown default:
            return []
        }
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

    static func scheduleAlarm(for record: AlarmRecord, using alarmManager: AlarmManager = .shared) async throws {
        try await scheduleAlarm(for: record, on: alarmSchedule(for: record), using: alarmManager)
    }

    private static func scheduleAlarm(
        for record: AlarmRecord,
        on schedule: Alarm.Schedule,
        using alarmManager: AlarmManager
    ) async throws {
        let alarmTitle = resolvedAlarmTitle(record.eventTitle, fallback: String(localized: "Alarm"))
        let attributes = AlarmAttributes<TouchtimeAlarmMetadata>(
            presentation: AlarmPresentation(alert: alertPresentation(title: alarmTitle)),
            tintColor: .white
        )

        _ = try await alarmManager.schedule(
            id: record.id,
            configuration: .alarm(schedule: schedule, attributes: attributes)
        )
    }

    /// When the record's alarm rings. One that keeps a city's clock rings as
    /// that clock reads its time: a one-off alarm at that very moment, a
    /// weekly one at the matching time on the device's clock, which
    /// `resyncCityAlarms()` moves whenever either clock shifts.
    private static func alarmSchedule(for record: AlarmRecord, at date: Date = Date()) -> Alarm.Schedule {
        var record = record
        record.syncDeviceTimeWithCity(at: date)

        if record.repeatRule == .once, let occurrence = record.nextCityOccurrence(after: date) {
            return .fixed(occurrence.date)
        }

        let recurrence: Alarm.Schedule.Relative.Recurrence
        switch record.repeatRule {
        case .once:
            recurrence = .never
        case .weekly:
            let localizedWeekdays = record.repeatWeekdays.compactMap { localeWeekday(from: $0) }
            recurrence = .weekly(localizedWeekdays.isEmpty ? [todayLocaleWeekday()] : localizedWeekdays)
        }

        return .relative(
            .init(
                time: .init(hour: record.hour, minute: record.minute),
                repeats: recurrence
            )
        )
    }

    /// Schedules a one-shot alarm that rings once at `fireDate`, presented
    /// like the alarms from the Alarms sheet. Used for countdown reminders
    /// delivered as alarms, which fall on a specific day rather than a
    /// time of day.
    static func scheduleFixedAlarm(
        id: UUID,
        fireDate: Date,
        eventTitle: String? = nil,
        using alarmManager: AlarmManager = .shared
    ) async throws {
        let alarmTitle = resolvedAlarmTitle(eventTitle, fallback: String(localized: "Alarm"))
        let attributes = AlarmAttributes<TouchtimeAlarmMetadata>(
            presentation: AlarmPresentation(alert: alertPresentation(title: alarmTitle)),
            tintColor: .white
        )

        _ = try await alarmManager.schedule(
            id: id,
            configuration: .alarm(schedule: .fixed(fireDate), attributes: attributes)
        )
    }

    /// Schedules the alert that rings when the Home timer ends at `fireDate`.
    static func scheduleTimerAlarm(
        id: UUID,
        fireDate: Date,
        eventTitle: String? = nil,
        using alarmManager: AlarmManager = .shared
    ) async throws {
        let alarmTitle = resolvedAlarmTitle(eventTitle, fallback: String(localized: "Timer"))
        // Alert only: a countdown presentation would make AlarmKit show its
        // own countdown Live Activity next to the timer's TimerActivityAttributes one.
        let attributes = AlarmAttributes<TouchtimeAlarmMetadata>(
            presentation: AlarmPresentation(alert: alertPresentation(title: alarmTitle)),
            tintColor: .orange // Timer Orange
        )

        _ = try await alarmManager.schedule(
            id: id,
            configuration: .alarm(
                schedule: .fixed(fireDate),
                attributes: attributes,
                stopIntent: TimerAlarmStopIntent()
            )
        )
    }

    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// The alert title: the trimmed event title, or `fallback` when there
    /// is none.
    private static func resolvedAlarmTitle(_ eventTitle: String?, fallback: String) -> LocalizedStringResource {
        let trimmedTitle = eventTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = (trimmedTitle?.isEmpty == false ? trimmedTitle : nil) ?? fallback
        return LocalizedStringResource(stringLiteral: resolvedTitle)
    }

    /// The ringing alert shared by every alarm the app schedules. iOS 26.1
    /// draws its own stop button; earlier releases need one supplied.
    private static func alertPresentation(title: LocalizedStringResource) -> AlarmPresentation.Alert {
        if #available(iOS 26.1, *) {
            return AlarmPresentation.Alert(title: title)
        }

        return AlarmPresentation.Alert(
            title: title,
            stopButton: AlarmButton(
                text: LocalizedStringResource("Done"),
                textColor: .white,
                systemImageName: "checkmark"
            )
        )
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
}

/// The alarm that rings when the Home timer ends. There is at most one; its
/// id is kept under the same key as the timer views' `homeTimerAlarmID`.
@MainActor
enum HomeTimerAlarm {
    private static let alarmIDKey = "homeTimerAlarmID"
    /// Bumped by every refresh, so one still waiting on AlarmKit can tell a
    /// newer one has taken over.
    private static var refreshVersion = 0

    /// Replaces the alarm with one for the timer's current end. A paused,
    /// finished or cleared timer is left without one.
    static func refresh(requestAuthorization: Bool) async {
        refreshVersion += 1
        let version = refreshVersion
        let isOvertaken = { version != refreshVersion || Task.isCancelled }
        let defaults = UserDefaults.standard
        let alarmManager = AlarmManager.shared
        let timer = HomeTimerSnapshot(defaults: defaults)

        if let existingAlarmID = UUID(uuidString: defaults.string(forKey: alarmIDKey) ?? "") {
            try? alarmManager.cancel(id: existingAlarmID)
        }

        guard !isOvertaken() else { return }

        guard let fireDate = timer.runningEndDate, fireDate > Date() else {
            defaults.set("", forKey: alarmIDKey)
            return
        }

        if requestAuthorization {
            switch await AlarmSupport.ensureAuthorization(using: alarmManager) {
            case .authorized:
                break
            case .denied:
                defaults.set("", forKey: alarmIDKey)
                return
            case .failed(let error):
                defaults.set("", forKey: alarmIDKey)
                print("Failed to authorize AlarmKit for timer: \(error.localizedDescription)")
                return
            }
        } else if alarmManager.authorizationState != .authorized {
            defaults.set("", forKey: alarmIDKey)
            return
        }

        let newAlarmID = UUID()

        do {
            try await AlarmSupport.scheduleTimerAlarm(
                id: newAlarmID,
                fireDate: fireDate,
                eventTitle: timer.displayName,
                using: alarmManager
            )
        } catch {
            defaults.set("", forKey: alarmIDKey)
            print("Failed to schedule AlarmKit timer reminder: \(error.localizedDescription)")
            return
        }

        guard !isOvertaken() else {
            try? alarmManager.cancel(id: newAlarmID)
            return
        }

        defaults.set(newAlarmID.uuidString, forKey: alarmIDKey)
    }
}
