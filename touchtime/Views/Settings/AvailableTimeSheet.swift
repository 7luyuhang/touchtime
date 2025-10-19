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
    @AppStorage("availableWeekdays") private var availableWeekdays = "2,3,4,5,6" // Default Mon-Fri
    
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var selectedWeekdays: Set<Int> = []
    @Environment(\.dismiss) private var dismiss
    
    // Weekday names and indices (1 = Sunday, 2 = Monday, etc. in Calendar)
    private let weekdays: [(name: String, index: Int)] = [
        ("M", 2),
        ("T", 3),
        ("W", 4),
        ("T", 5),
        ("F", 6),
        ("S", 7),
        ("S", 1)
    ]
    
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
    
    // Load weekdays from storage
    private func loadWeekdays() {
        let weekdayNumbers = availableWeekdays.split(separator: ",").compactMap { Int($0) }
        selectedWeekdays = Set(weekdayNumbers)
    }
    
    // Save weekdays to storage
    private func saveWeekdays() {
        let sortedWeekdays = selectedWeekdays.sorted()
        availableWeekdays = sortedWeekdays.map { String($0) }.joined(separator: ",")
    }
    
    // Toggle weekday selection
    private func toggleWeekday(_ index: Int) {
        if selectedWeekdays.contains(index) {
            selectedWeekdays.remove(index)
        } else {
            selectedWeekdays.insert(index)
        }
        saveWeekdays()
    }
    
    
    // Generate footer text based on selected weekdays
    private func getWeekdayFooterText() -> String? {
        guard !selectedWeekdays.isEmpty else {
            return "Please select at least one day."
        }
        
        let weekdaySet = Set([2, 3, 4, 5, 6]) // Mon-Fri
        let weekendSet = Set([1, 7]) // Sun, Sat
        
        var selectedText = ""
        
        // Check if exactly Mon-Fri are selected
        if selectedWeekdays == weekdaySet {
            selectedText = "Weekdays"
        }
        // Check if exactly Sat-Sun are selected
        else if selectedWeekdays == weekendSet {
            selectedText = "Weekend"
        }
        // Otherwise, show the selected day names
        else {
            let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let sortedDays = selectedWeekdays.sorted()
            let selectedNames = sortedDays.map { dayIndex in
                // Convert calendar weekday (1=Sun, 2=Mon, etc.) to array index
                dayNames[dayIndex - 1]
            }
            selectedText = selectedNames.joined(separator: ", ")
        }
        
        return "Date selected: \(selectedText)"
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
                HStack(spacing: 16){
                    Image(systemName: "info.circle.fill")
                        .fontWeight(.semibold)
                    
                    Text("Set available time to compare and show availability across different cities.")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
                
                
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
                
                
                // Weekday Selection
                Section {
                    HStack(spacing: 0) {
                        ForEach(Array(weekdays.enumerated()), id: \.element.index) { index, weekday in
                            if index > 0 {
                                Spacer(minLength: 0)
                            }
                            
                            Button(action: {
                                toggleWeekday(weekday.index)
                            }) {
                                Text(weekday.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                    .frame(width: 36, height: 36)
                                    .glassEffect(
                                        .clear
                                        .tint(selectedWeekdays.contains(weekday.index) ? Color.blue : nil)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                } footer: {
                    if let footerText = getWeekdayFooterText() {
                        Text(footerText)
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
                // Load selected weekdays
                loadWeekdays()
                // Auto-disable if no cities available
                if worldClocks.isEmpty && availableTimeEnabled {
                    availableTimeEnabled = false
                }
            }
        }
    }
}
