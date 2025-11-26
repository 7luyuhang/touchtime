//
//  AvailableTimeIndicator.swift
//  touchtime
//
//  Created on 15/10/2025.
//

import SwiftUI

struct AvailableTimeIndicator: View {
    let currentDate: Date
    let timeOffset: TimeInterval
    let availableStartTime: String
    let availableEndTime: String
    let use24HourFormat: Bool
    let availableWeekdays: String // Comma-separated list of weekday numbers
    
    // Calculate progress for available time indicator
    private func calculateAvailableTimeProgress() -> Double {
        // Return 0 if not a selected weekday
        guard isSelectedWeekday() else { return 0 }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        // Get current time adjusted by offset
        let adjustedCurrentTime = currentDate.addingTimeInterval(timeOffset)
        let calendar = Calendar.current
        let currentComponents = calendar.dateComponents([.hour, .minute], from: adjustedCurrentTime)
        let currentMinutes = Double((currentComponents.hour ?? 0) * 60 + (currentComponents.minute ?? 0))
        
        // Parse start time
        guard let startDate = formatter.date(from: availableStartTime) else { return 0 }
        let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
        let startMinutes = Double((startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0))
        
        // Parse end time
        guard let endDate = formatter.date(from: availableEndTime) else { return 0 }
        let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)
        var endMinutes = Double((endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0))
        
        // Handle case where end time is next day (e.g., working overnight)
        if endMinutes <= startMinutes {
            endMinutes += 24 * 60
        }
        
        // Adjust current time if it's after midnight for overnight shifts
        var adjustedCurrentMinutes = currentMinutes
        if endMinutes > 24 * 60 && currentMinutes < startMinutes {
            adjustedCurrentMinutes += 24 * 60
        }
        
        // Calculate progress
        let totalDuration = endMinutes - startMinutes
        let elapsed = adjustedCurrentMinutes - startMinutes
        
        let progress = elapsed / totalDuration
        return min(max(progress, 0), 1) // Clamp between 0 and 1
    }
    
    // Check if current day is a selected weekday
    private func isSelectedWeekday() -> Bool {
        let adjustedCurrentTime = currentDate.addingTimeInterval(timeOffset)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: adjustedCurrentTime)
        
        let selectedDays = availableWeekdays.split(separator: ",").compactMap { Int($0) }
        return selectedDays.contains(weekday)
    }
    
    // Check if current time is within available hours
    private func isWithinAvailableTime() -> Bool {
        // First check if it's a selected weekday
        guard isSelectedWeekday() else { return false }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        // Get current time adjusted by offset
        let adjustedCurrentTime = currentDate.addingTimeInterval(timeOffset)
        let calendar = Calendar.current
        let currentComponents = calendar.dateComponents([.hour, .minute], from: adjustedCurrentTime)
        let currentMinutes = (currentComponents.hour ?? 0) * 60 + (currentComponents.minute ?? 0)
        
        // Parse start time
        guard let startDate = formatter.date(from: availableStartTime) else { return false }
        let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        
        // Parse end time
        guard let endDate = formatter.date(from: availableEndTime) else { return false }
        let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        
        // Handle overnight shifts
        if endMinutes <= startMinutes {
            // Overnight shift (e.g., 22:00 to 06:00)
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        } else {
            // Normal shift (e.g., 09:00 to 17:00)
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        }
    }
    
    // Format available time for display
    private func formatAvailableTime(_ timeString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        guard let date = formatter.date(from: timeString) else {
            return timeString
        }
        
        if use24HourFormat {
            return timeString
        } else {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date).lowercased()
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            
            // Start Time
            Text(formatAvailableTime(availableStartTime))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .blendMode(.plusLighter)
            
            
            // Progress Bar
            GeometryReader { geometry in
                    Circle()
                        .fill(isWithinAvailableTime() ? Color.white : Color.white.opacity(0.25))
                        .glassEffect(.clear)
                        .frame(width: 12, height: 12)
                        .offset(x: max(0, min(geometry.size.width - 10, geometry.size.width * calculateAvailableTimeProgress() - 5)))
                        .animation(.spring(), value: calculateAvailableTimeProgress())
                        .padding(.top, 1)
            }
            
            // End Time
            Text(formatAvailableTime(availableEndTime))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .blendMode(.plusLighter)
        }
        .padding(.top, 4)
    }
}
