//
//  DateFormatting.swift
//  touchtime
//
//  Created on 02/11/2025.
//

import Foundation

extension Date {
    /// Format the date with relative style (Today/Yesterday/Tomorrow) or absolute style (E, d MMM)
    /// - Parameters:
    ///   - dateStyle: "Relative" or "Absolute" style preference
    ///   - timeZone: TimeZone to use for formatting (defaults to current)
    ///   - referenceDate: The reference date to compare against (defaults to Date())
    /// - Returns: Formatted date string
    func formattedDate(
        style dateStyle: String,
        timeZone: TimeZone = TimeZone.current,
        relativeTo referenceDate: Date = Date()
    ) -> String {
        // If Relative date style is selected, use Today/Yesterday/Tomorrow
        if dateStyle == "Relative" {
            var calendar = Calendar.current
            calendar.timeZone = timeZone
            
            // Get reference date components in the target timezone
            let referenceDateComponents = calendar.dateComponents([.year, .month, .day], from: referenceDate)
            let currentDateComponents = calendar.dateComponents([.year, .month, .day], from: self)
            
            // Check if it's today
            if currentDateComponents.year == referenceDateComponents.year &&
               currentDateComponents.month == referenceDateComponents.month &&
               currentDateComponents.day == referenceDateComponents.day {
                return String(localized: "Today")
            }
            
            // Check if it's tomorrow
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceDate) {
                let tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                if currentDateComponents.year == tomorrowComponents.year &&
                   currentDateComponents.month == tomorrowComponents.month &&
                   currentDateComponents.day == tomorrowComponents.day {
                    return String(localized: "Tomorrow")
                }
            }
            
            // Check if it's yesterday
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate) {
                let yesterdayComponents = calendar.dateComponents([.year, .month, .day], from: yesterday)
                if currentDateComponents.year == yesterdayComponents.year &&
                   currentDateComponents.month == yesterdayComponents.month &&
                   currentDateComponents.day == yesterdayComponents.day {
                    return String(localized: "Yesterday")
                }
            }
        }
        
        // Show the full date format (when dateStyle is "Absolute" or not Today/Yesterday/Tomorrow)
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = timeZone
        formatter.dateFormat = "E, d MMM"
        return formatter.string(from: self)
    }
    
    /// Convenience method for formatting date with time offset
    /// - Parameters:
    ///   - dateStyle: "Relative" or "Absolute" style preference
    ///   - timeZoneIdentifier: TimeZone identifier string
    ///   - timeOffset: Optional time offset to add to the date
    /// - Returns: Formatted date string
    func formattedDate(
        style dateStyle: String,
        timeZoneIdentifier: String,
        timeOffset: TimeInterval = 0
    ) -> String {
        let adjustedDate = self.addingTimeInterval(timeOffset)
        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
        return adjustedDate.formattedDate(style: dateStyle, timeZone: timeZone, relativeTo: Date())
    }
}
