//
//  WatchTimeFormat.swift
//  touchtimeWatch
//

import Foundation

/// Time and date strings for the watch's clocks.
enum WatchTimeFormat {
    private static var formatters: [String: DateFormatter] = [:]

    /// `date`'s time in `timeZone` as digits ("9:41" or "21:41", by
    /// `hourCycle`) and, in 12-hour time, the "AM"/"PM" that follows them.
    static func time(_ date: Date, in timeZone: TimeZone, hourCycle: Locale.HourCycle) -> (digits: String, period: String?) {
        switch hourCycle {
        case .zeroToTwentyThree, .oneToTwentyFour:
            return (formatter("HH:mm", in: timeZone).string(from: date), nil)
        default:
            return (
                formatter("h:mm", in: timeZone).string(from: date),
                formatter("a", in: timeZone).string(from: date)
            )
        }
    }

    /// An hour of the day (0–23) as a 24-hour dial marks it: "06" and "18"
    /// in 24-hour time, and "6" for both in 12-hour time, like `time`'s hours.
    static func dialHour(_ hour: Int, hourCycle: Locale.HourCycle) -> String {
        switch hourCycle {
        case .zeroToTwentyThree, .oneToTwentyFour:
            return String(format: "%02d", hour)
        default:
            return String(hour % 12 == 0 ? 12 : hour % 12)
        }
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
