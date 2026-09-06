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
    ///
    /// The presets are the Repeat menu's standard choices; `custom` covers
    /// every other cadence ("every 2 weeks", "every 18 months"). Build
    /// custom values through `every(_:_:)`, which folds an interval of 1
    /// back into the matching preset so each cadence has one representation.
    enum RepeatFrequency: RawRepresentable, Hashable, Codable {
        /// The calendar unit a custom interval is counted in.
        enum Unit: String, CaseIterable {
            case week
            case month
            case year

            var component: Calendar.Component {
                switch self {
                case .week: .weekOfYear
                case .month: .month
                case .year: .year
                }
            }

            /// The preset that repeats every single one of this unit.
            var preset: RepeatFrequency {
                switch self {
                case .week: .weekly
                case .month: .monthly
                case .year: .annually
                }
            }
        }

        case never
        case weekly
        case monthly
        case annually
        case custom(interval: Int, unit: Unit)

        /// The choices listed directly in the Repeat menu, ahead of Custom.
        static let presets: [RepeatFrequency] = [.never, .weekly, .monthly, .annually]

        /// Repeats every `interval` units, normalised so that "every 1 week"
        /// is `.weekly` rather than a custom value.
        static func every(_ interval: Int, _ unit: Unit) -> RepeatFrequency {
            interval > 1 ? .custom(interval: interval, unit: unit) : unit.preset
        }

        /// How far apart occurrences are; nil when the countdown never repeats.
        var period: (count: Int, unit: Unit)? {
            switch self {
            case .never: nil
            case .weekly: (1, .week)
            case .monthly: (1, .month)
            case .annually: (1, .year)
            case .custom(let interval, let unit): (interval, unit)
            }
        }

        var isCustom: Bool {
            if case .custom = self { return true }
            return false
        }

        var displayName: String {
            switch self {
            case .never: String(localized: "Never")
            case .weekly: String(localized: "Weekly")
            case .monthly: String(localized: "Monthly")
            case .annually: String(localized: "Annually")
            case .custom(let interval, let unit):
                switch unit {
                case .week: String(format: String(localized: "Every %d Weeks"), interval)
                case .month: String(format: String(localized: "Every %d Months"), interval)
                case .year: String(format: String(localized: "Every %d Years"), interval)
                }
            }
        }

        // MARK: Persistence

        // Stored as a string: the presets keep their original raw values so
        // existing saves still decode, and custom values ("custom:2:week")
        // read as .never in app versions that predate them (see the
        // CountdownItem decoder) instead of breaking the whole store.

        init?(rawValue: String) {
            switch rawValue {
            case "never": self = .never
            case "weekly": self = .weekly
            case "monthly": self = .monthly
            case "annually": self = .annually
            default:
                let parts = rawValue.split(separator: ":")
                guard parts.count == 3, parts[0] == "custom",
                      let interval = Int(parts[1]), interval >= 1,
                      let unit = Unit(rawValue: String(parts[2])) else { return nil }
                self = .every(interval, unit)
            }
        }

        var rawValue: String {
            switch self {
            case .never: "never"
            case .weekly: "weekly"
            case .monthly: "monthly"
            case .annually: "annually"
            case .custom(let interval, let unit): "custom:\(interval):\(unit.rawValue)"
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            guard let frequency = RepeatFrequency(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown repeat frequency \(rawValue)")
            }
            self = frequency
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
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

    /// Rolls `targetDate` forward by whole repeat periods until it lands
    /// on or after `now`'s calendar day (so a repeating event still reads
    /// "Today" for the rest of its day). Every addition anchors on the
    /// original date so month-end dates don't drift (Jan 31 → Feb 28 →
    /// Mar 31, not Mar 28).
    static func nextOccurrence(of targetDate: Date, frequency: RepeatFrequency, after now: Date) -> Date {
        guard let period = frequency.period else { return targetDate }
        let component = period.unit.component
        let stride = max(period.count, 1)

        let calendar = Calendar.current
        let nowDay = calendar.startOfDay(for: now)
        guard calendar.startOfDay(for: targetDate) < nowDay else { return targetDate }

        // Jump close in one step, rounded down to whole periods so the
        // result stays on the repeat grid, then settle on the first
        // occurrence whose day is not in the past.
        let elapsed = max(calendar.dateComponents([component], from: targetDate, to: now).value(for: component) ?? 0, 0)
        var count = elapsed - elapsed % stride
        var next = calendar.date(byAdding: component, value: count, to: targetDate) ?? targetDate
        while calendar.startOfDay(for: next) < nowDay {
            count += stride
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
            // Deleted countdowns take their space attachments with them.
            CountdownSpaceStore.shared.prune(keeping: countdowns.map(\.id))
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
