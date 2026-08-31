//
//  CountdownStore.swift
//  touchtime
//
//  Shared storage for countdown events.
//

import Foundation
import Observation

/// A countdown towards a future date, shown in the countdown grid.
struct CountdownItem: Identifiable, Codable, Equatable {
    /// How the countdown rolls forward once its target date has passed.
    enum RepeatFrequency: String, Codable, CaseIterable {
        case never
        case weekly
        case monthly
        case annually

        var displayName: String {
            switch self {
            case .never: String(localized: "Never")
            case .weekly: String(localized: "Weekly")
            case .monthly: String(localized: "Monthly")
            case .annually: String(localized: "Annually")
            }
        }
    }

    let id: UUID
    var title: String
    var targetDate: Date
    let createdAt: Date
    var isPinned: Bool
    var repeatFrequency: RepeatFrequency
    var emoji: String?
    /// Downsampled JPEG shown in the centre badge, with a blurred version
    /// as the card background. Mutually exclusive with `emoji`.
    var photoData: Data?
    /// Notification on the day of the event at this time of day; only the
    /// hour and minute are meaningful. Nil when the reminder is off.
    var reminderTime: Date?
    /// How many days before the event day the reminder fires; 0 means on
    /// the day of the event.
    var reminderLeadDays: Int

    init(id: UUID, title: String, targetDate: Date, createdAt: Date, isPinned: Bool = false, repeatFrequency: RepeatFrequency = .never, emoji: String? = nil, photoData: Data? = nil, reminderTime: Date? = nil, reminderLeadDays: Int = 0) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.repeatFrequency = repeatFrequency
        self.emoji = emoji
        self.photoData = photoData
        self.reminderTime = reminderTime
        self.reminderLeadDays = reminderLeadDays
    }

    // Items saved before pinning/repeat/emoji/photo existed are missing
    // those keys.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        targetDate = try container.decode(Date.self, forKey: .targetDate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        // Decoded via the raw string so an unknown value from a newer app
        // version degrades to .never instead of dropping the whole store.
        if let rawFrequency = try container.decodeIfPresent(String.self, forKey: .repeatFrequency),
           let frequency = RepeatFrequency(rawValue: rawFrequency) {
            repeatFrequency = frequency
        } else {
            repeatFrequency = .never
        }
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji)
        photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        reminderTime = try container.decodeIfPresent(Date.self, forKey: .reminderTime)
        reminderLeadDays = try container.decodeIfPresent(Int.self, forKey: .reminderLeadDays) ?? 0
    }

    /// The stored date for one-off countdowns; for repeating ones, the
    /// next occurrence on or after `now`'s calendar day.
    func effectiveTargetDate(at now: Date) -> Date {
        Self.nextOccurrence(of: targetDate, frequency: repeatFrequency, after: now)
    }

    /// Rolls `targetDate` forward by whole repeat intervals until it lands
    /// on or after `now`'s calendar day (so a repeating event still reads
    /// "Today" for the rest of its day). Every addition anchors on the
    /// original date so month-end dates don't drift (Jan 31 → Feb 28 →
    /// Mar 31, not Mar 28).
    static func nextOccurrence(of targetDate: Date, frequency: RepeatFrequency, after now: Date) -> Date {
        let component: Calendar.Component
        switch frequency {
        case .never:
            return targetDate
        case .weekly:
            component = .weekOfYear
        case .monthly:
            component = .month
        case .annually:
            component = .year
        }

        let calendar = Calendar.current
        let nowDay = calendar.startOfDay(for: now)
        guard calendar.startOfDay(for: targetDate) < nowDay else { return targetDate }

        // Jump close in one step, then settle on the first occurrence
        // whose day is not in the past.
        var count = max(calendar.dateComponents([component], from: targetDate, to: now).value(for: component) ?? 0, 0)
        var next = calendar.date(byAdding: component, value: count, to: targetDate) ?? targetDate
        while calendar.startOfDay(for: next) < nowDay {
            count += 1
            next = calendar.date(byAdding: component, value: count, to: targetDate) ?? targetDate
        }
        return next
    }

    /// When the reminder notification should next fire: `reminderLeadDays`
    /// before the (next) occurrence day, at the reminder's time of day.
    /// Nil without a reminder, or when the time has already passed on a
    /// countdown that never repeats.
    func nextReminderFireDate(after now: Date) -> Date? {
        guard let reminderTime else { return nil }
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: reminderTime)

        // A repeating countdown whose reminder already rang today still
        // reads "Today" all day, so step past that occurrence to the next.
        var searchFrom = now
        for _ in 0..<4 {
            let occurrence = Self.nextOccurrence(of: targetDate, frequency: repeatFrequency, after: searchFrom)
            let reminderDay = calendar.date(byAdding: .day, value: -reminderLeadDays, to: occurrence) ?? occurrence
            if let fireDate = calendar.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: reminderDay),
               fireDate > now {
                return fireDate
            }
            guard repeatFrequency != .never,
                  let nextSearchFrom = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: occurrence)) else {
                return nil
            }
            searchFrom = nextSearchFrom
        }
        return nil
    }
}

/// Single source of truth for countdowns, created once at the app root and
/// shared through the environment. Every mutation notifies all observing
/// views (e.g. the Home cards update live while the countdown sheet is up)
/// and is persisted to UserDefaults automatically.
@Observable
final class CountdownStore {
    private static let storageKey = "savedCountdowns"

    var countdowns: [CountdownItem] {
        didSet {
            Self.persist(countdowns)
            // Keep pending reminder notifications in step with every mutation.
            CountdownReminderManager.shared.reschedule(for: countdowns)
        }
    }

    init() {
        countdowns = Self.load()
    }

    private static func load() -> [CountdownItem] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([CountdownItem].self, from: data) else {
            return []
        }
        return items
    }

    private static func persist(_ items: [CountdownItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
