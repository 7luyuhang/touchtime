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

    /// e.g. "19" or "7 pm", for a single hourly forecast card
    func forecastHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24HourFormat ? "HH" : "h a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"

        return formatter.string(from: date)
            .replacingOccurrences(of: " ", with: "\u{202F}")
    }

    /// e.g. "Oct 25"
    func monthDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale.current

        // Use short date format
        switch Locale.current.language.languageCode?.identifier {
        case "zh", "ja":
            formatter.dateFormat = "MMMd日"
        case "ko":
            formatter.dateFormat = "MMM d일"
        default:
            formatter.dateFormat = "MMM d"
        }

        return formatter.string(from: date)
    }

    /// e.g. "Oct 25, 2026"
    func monthDayYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale.current

        switch Locale.current.language.languageCode?.identifier {
        case "zh":
            formatter.dateFormat = "y年MMMd日"
        case "ja", "ko":
            // Follows the device calendar, e.g. "2026年10月25日" or "令和8年10月25日",
            // and "2026년 10월 25일" in Korean
            formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        default:
            formatter.dateFormat = "MMM d, y"
        }

        return formatter.string(from: date)
    }
}
