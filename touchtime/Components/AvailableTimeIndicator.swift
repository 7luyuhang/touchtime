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
    
    // Static DateFormatter to avoid creating new instances on every calculation
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    // Cached calculation result struct
    private struct AvailableTimeState {
        let progress: Double
        let isWithinTime: Bool
    }
    
    // Single unified calculation that returns both progress and isWithinTime
    private var availableTimeState: AvailableTimeState {
        let adjustedCurrentTime = currentDate.addingTimeInterval(timeOffset)
        let calendar = Calendar.current
        
        // Check if it's a selected weekday
        let weekday = calendar.component(.weekday, from: adjustedCurrentTime)
        let selectedDays = availableWeekdays.split(separator: ",").compactMap { Int($0) }
        guard selectedDays.contains(weekday) else {
            return AvailableTimeState(progress: 0, isWithinTime: false)
        }
        
        // Get current time in minutes
        let currentComponents = calendar.dateComponents([.hour, .minute], from: adjustedCurrentTime)
        let currentMinutes = Double((currentComponents.hour ?? 0) * 60 + (currentComponents.minute ?? 0))
        
        // Parse start time
        guard let startDate = Self.timeFormatter.date(from: availableStartTime) else {
            return AvailableTimeState(progress: 0, isWithinTime: false)
        }
        let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
        let startMinutes = Double((startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0))
        
        // Parse end time
        guard let endDate = Self.timeFormatter.date(from: availableEndTime) else {
            return AvailableTimeState(progress: 0, isWithinTime: false)
        }
        let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)
        var endMinutes = Double((endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0))
        
        // Handle overnight shifts
        let isOvernightShift = endMinutes <= startMinutes
        if isOvernightShift {
            endMinutes += 24 * 60
        }
        
        // Adjust current time for overnight shifts
        var adjustedCurrentMinutes = currentMinutes
        if isOvernightShift && currentMinutes < startMinutes {
            adjustedCurrentMinutes += 24 * 60
        }
        
        // Calculate progress
        let totalDuration = endMinutes - startMinutes
        let elapsed = adjustedCurrentMinutes - startMinutes
        let progress = min(max(elapsed / totalDuration, 0), 1)
        
        // Check if within available time
        let isWithinTime: Bool
        if isOvernightShift {
            isWithinTime = currentMinutes >= startMinutes || currentMinutes <= (endMinutes - 24 * 60)
        } else {
            isWithinTime = currentMinutes >= startMinutes && currentMinutes <= endMinutes
        }
        
        return AvailableTimeState(progress: progress, isWithinTime: isWithinTime)
    }
    
    // Cached formatted time strings
    private var formattedStartTime: String {
        if use24HourFormat {
            return availableStartTime
        }
        guard let date = Self.timeFormatter.date(from: availableStartTime) else {
            return availableStartTime
        }
        return Self.displayFormatter.string(from: date).lowercased()
    }
    
    private var formattedEndTime: String {
        if use24HourFormat {
            return availableEndTime
        }
        guard let date = Self.timeFormatter.date(from: availableEndTime) else {
            return availableEndTime
        }
        return Self.displayFormatter.string(from: date).lowercased()
    }
    
    var body: some View {
        // Calculate state once and reuse
        let state = availableTimeState
        
        HStack(alignment: .center, spacing: 12) {
            
            // Start Time
            Text(formattedStartTime)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .blendMode(.plusLighter)
            
            
            // Progress Bar
            GeometryReader { geometry in
                Circle()
                    .fill(state.isWithinTime ? Color.white : Color.white.opacity(0.25))
                    .glassEffect(.clear)
                    .frame(width: 10, height: 10)
                    .offset(x: max(0, min(geometry.size.width - 10, geometry.size.width * state.progress - 5)))
                    .animation(.spring(), value: state.progress)
            }
            .frame(height: 10)
            
            // End Time
            Text(formattedEndTime)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .blendMode(.plusLighter)
        }
        .padding(.top, 4)
    }
}
