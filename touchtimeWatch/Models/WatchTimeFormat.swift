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

    /// The city's date in the iPhone app's date style ("Tomorrow",
    /// "Wed, 28 Oct", …) and the iPhone app's time difference, e.g.
    /// "Tomorrow, +8h". Just the date when the clocks are less than an hour
    /// apart.
    static func dayAndOffset(_ date: Date, in timeZone: TimeZone, now: Date, dateStyle: String) -> String {
        let day = date.formattedDate(style: dateStyle, timeZone: timeZone, relativeTo: now)
        let timeDifference = WorldClock.timeDifference(to: timeZone, at: date)
        guard !timeDifference.isEmpty else { return day }
        return String(localized: "\(day), \(timeDifference)")
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
