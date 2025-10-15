//
//  AvailableTimePicker.swift
//  touchtime
//
//  Created on 15/10/2025.
//

import SwiftUI

struct AvailableTimePicker: View {
    let worldClocks: [WorldClock]
    @AppStorage("availableTimeEnabled") private var availableTimeEnabled = false
    @AppStorage("availableStartTime") private var availableStartTime = "09:00"
    @AppStorage("availableEndTime") private var availableEndTime = "17:00"
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    
    @State private var startDate = Date()
    @State private var endDate = Date()
    @Environment(\.dismiss) private var dismiss
    
    // Computed property to get locale based on time format preference
    private var datePickerLocale: Locale {
        if use24HourFormat {
            // Use locale that defaults to 24-hour format
            return Locale(identifier: "en_GB")
        } else {
            // Use locale that defaults to 12-hour format
            return Locale(identifier: "en_US")
        }
    }
    
    // Convert time string to Date for DatePicker
    private func timeStringToDate(_ timeString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        // If conversion fails, return current date
        guard let date = formatter.date(from: timeString) else {
            return Date()
        }
        
        // Combine with today's date to get a proper Date object
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return calendar.date(bySettingHour: components.hour ?? 9, 
                           minute: components.minute ?? 0, 
                           second: 0, 
                           of: Date()) ?? Date()
    }
    
    // Convert Date to time string for storage
    private func dateToTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    // Format time for display
    private func formatTimeForDisplay(_ timeString: String) -> String {
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
            return formatter.string(from: date)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Enable/Disable Toggle
                Section {
                    Toggle(isOn: $availableTimeEnabled) {
                            Text("Show Available Time")
                    }
                    .tint(.blue)
                    .disabled(worldClocks.isEmpty)
                    
                } footer: {
                    if worldClocks.isEmpty {
                        HStack(spacing: 4) {
                            Text("Tap")
                            Image(systemName: "magnifyingglass")
                                .fontWeight(.medium)
                            Text("and add cities first to enable.")
                        }
                    } else {
                        HStack(spacing: 4) {
                            Text("Enable showing")
                            Image(systemName: "circlebadge.fill")
                            Text("indicator inside system time.")
                        }
                    }
                }
                
                // Time Range Selection
                if availableTimeEnabled {
                    Section {
                        // Start Time
                        DatePicker(
                            selection: $startDate,
                            displayedComponents: .hourAndMinute
                        ) {
                                Text("Start Time")
                        }
                        .datePickerStyle(.compact)
                        .environment(\.locale, datePickerLocale)
                        .onChange(of: startDate) { oldValue, newValue in
                            availableStartTime = dateToTimeString(newValue)
                            
                            // Ensure end time is after start time
                            if newValue >= endDate {
                                let calendar = Calendar.current
                                if let newEndDate = calendar.date(byAdding: .hour, value: 1, to: newValue) {
                                    endDate = newEndDate
                                    availableEndTime = dateToTimeString(newEndDate)
                                }
                            }
                        }
                        
                        // End Time
                        DatePicker(
                            selection: $endDate,
                            displayedComponents: .hourAndMinute
                        ) {
                                Text("End Time")   
                        }
                        .datePickerStyle(.compact)
                        .environment(\.locale, datePickerLocale)
                        .onChange(of: endDate) { oldValue, newValue in
                            availableEndTime = dateToTimeString(newValue)
                            
                            // Ensure end time is after start time
                            if newValue <= startDate {
                                let calendar = Calendar.current
                                if let newStartDate = calendar.date(byAdding: .hour, value: -1, to: newValue) {
                                    startDate = newStartDate
                                    availableStartTime = dateToTimeString(newStartDate)
                                }
                            }
                        }
                    }
                }
            }
            // Title
            .navigationTitle("Available Time")
            .navigationBarTitleDisplayMode(.inline)
            
            .onAppear {
                // Initialize dates from stored values
                startDate = timeStringToDate(availableStartTime)
                endDate = timeStringToDate(availableEndTime)
                // Auto-disable if no cities available
                if worldClocks.isEmpty && availableTimeEnabled {
                    availableTimeEnabled = false
                }
            }
        }
    }
}
