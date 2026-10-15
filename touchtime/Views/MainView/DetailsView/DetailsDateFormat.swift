//
//  DetailsDateFormat.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import Foundation

/// Formats the details sheet's times and dates in the city's time zone.
struct DetailsDateFormat {
    let timeZoneIdentifier: String
    let use24HourFormat: Bool

    /// e.g. "7:24 am", or "-" without a date
    func time(_ date: Date?) -> String {
        guard let date = date else { return "-" }

        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if use24HourFormat {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm a"
            formatter.amSymbol = "am"
            formatter.pmSymbol = "pm"
        }

        let formatted = formatter.string(from: date)
        if use24HourFormat {
            return formatted
        }

        // Keep am/pm attached to the time so it won't wrap onto a second line.
        return formatted.replacingOccurrences(of: " ", with: "\u{202F}")
    }

    /// e.g. "7:24", without am/pm
    func timeWithoutPeriod(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24HourFormat ? "HH:mm" : "h:mm"

        return formatter.string(from: date)
    }

    /// e.g. "Oct 25"
    func monthDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale.current

        // Use short date format
        if Locale.current.language.languageCode?.identifier == "zh" {
            formatter.dateFormat = "MMMd日"
        } else {
            formatter.dateFormat = "MMM d"
        }

        return formatter.string(from: date)
    }
}
