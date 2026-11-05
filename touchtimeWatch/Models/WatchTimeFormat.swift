//
//  WatchTimeFormat.swift
//  touchtimeWatch
//

import Foundation

/// Time and date strings for the watch's clocks.
enum WatchTimeFormat {
    /// The watch app's own 24-Hour Format setting.
    static let use24HourFormatKey = "use24HourFormat"

    /// The 24-Hour Format setting until it's first changed: the watch's region
    /// settings, 24-Hour Time included.
    static var systemUses24HourFormat: Bool {
        switch Locale.autoupdatingCurrent.hourCycle {
        case .zeroToTwentyThree, .oneToTwentyFour:
            return true
        default:
            return false
        }
    }

    private static var formatters: [String: DateFormatter] = [:]

    /// `date`'s time in `timeZone` as digits ("9:41" or "21:41", by
    /// `use24HourFormat`) and, in 12-hour time, the "AM"/"PM" that follows them.
    static func time(_ date: Date, in timeZone: TimeZone, use24HourFormat: Bool) -> (digits: String, period: String?) {
        if use24HourFormat {
            return (formatter("HH:mm", in: timeZone).string(from: date), nil)
        }
        return (
            formatter("h:mm", in: timeZone).string(from: date),
            formatter("a", in: timeZone).string(from: date)
        )
    }

    /// An hour of the day (0–23) as a 24-hour dial marks it: "06" and "18"
    /// in 24-hour time, and "6" for both in 12-hour time, like `time`'s hours.
    static func dialHour(_ hour: Int, use24HourFormat: Bool) -> String {
        if use24HourFormat {
            return String(format: "%02d", hour)
        }
        return String(hour % 12 == 0 ? 12 : hour % 12)
    }

    private static func formatter(_ format: String, in timeZone: TimeZone) -> DateFormatter {
        let key = "\(format)|\(timeZone.identifier)"
        if let formatter = formatters[key] {
            return formatter
        }
        let formatter = DateFormatter()
        // Latin digits and AM/PM in every language, like the iPhone app
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        formatters[key] = formatter
        return formatter
    }
}
