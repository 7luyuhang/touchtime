//
//  CityTimeAdjustmentSheet.swift
//  touchtime
//
//  Created on 12/12/2025.
//

import SwiftUI

struct CityTimeAdjustmentSheet: View {
    let cityName: String
    let timeZoneIdentifier: String
    @Binding var timeOffset: TimeInterval
    @Binding var showSheet: Bool
    @Binding var showScrollTimeButtons: Bool
    
    @State private var selectedTime: Date
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("additionalTimeDisplay") private var additionalTimeDisplay = "None"
    @AppStorage("continuousScrollMode") private var continuousScrollMode = false
    
    init(cityName: String, timeZoneIdentifier: String, timeOffset: Binding<TimeInterval>, showSheet: Binding<Bool>, showScrollTimeButtons: Binding<Bool>) {
        self.cityName = cityName
        self.timeZoneIdentifier = timeZoneIdentifier
        self._timeOffset = timeOffset
        self._showSheet = showSheet
        self._showScrollTimeButtons = showScrollTimeButtons
        
        // Initialize selectedTime to show current time in the city's timezone
        let currentDate = Date().addingTimeInterval(timeOffset.wrappedValue)
        
        if let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) {
            let calendar = Calendar.current
            // Get the current time components in the target timezone
            let targetComponents = calendar.dateComponents(in: targetTimeZone, from: currentDate)
            
            // Create a date with those hour/minute values in the local timezone
            // This way the DatePicker will display the correct time for the city
            var localComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
            localComponents.hour = targetComponents.hour
            localComponents.minute = targetComponents.minute
            localComponents.second = 0
            
            if let adjustedDate = calendar.date(from: localComponents) {
                self._selectedTime = State(initialValue: adjustedDate)
            } else {
                self._selectedTime = State(initialValue: currentDate)
            }
        } else {
            self._selectedTime = State(initialValue: currentDate)
        }
    }
    
    // Calculate the current time displayed in the target city
    private var currentCityTime: Date {
        Date().addingTimeInterval(timeOffset)
    }
    
    // Calculate additional time text for this city
    private var additionalTimeText: String {
        guard let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) else { return "" }
        
        switch additionalTimeDisplay {
        case "Time Difference":
            let localOffset = TimeZone.current.secondsFromGMT()
            let targetOffset = targetTimeZone.secondsFromGMT()
            let diffHours = (targetOffset - localOffset) / 3600
            if diffHours == 0 {
                return String(format: String(localized: "%d hours"), 0)
            } else if diffHours > 0 {
                return String(format: String(localized: "+%d hours"), diffHours)
            } else {
                return String(format: String(localized: "%d hours"), diffHours)
            }
        case "UTC":
            let offsetSeconds = targetTimeZone.secondsFromGMT()
            let offsetHours = offsetSeconds / 3600
            if offsetHours == 0 {
                return "UTC +0"
            } else if offsetHours > 0 {
                return "UTC +\(offsetHours)"
            } else {
                return "UTC \(offsetHours)"
            }
        default:
            return ""
        }
    }
    
    // Reset to current time
    func resetTime() {
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
        
        withAnimation(.spring()) {
            timeOffset = 0
            selectedTime = Date()
            showScrollTimeButtons = false
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // DatePicker configured for the city's timezone
                DatePicker(
                    "",
                    selection: Binding(
                        get: { selectedTime },
                        set: { newTime in
                            selectedTime = newTime
                            
                            // Calculate offset from current real time
                            // When user picks a time, they're picking what time they want to see in THIS city
                            // We need to calculate the global offset that would make this city show that time
                            
                            guard let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) else { return }
                            
                            let calendar = Calendar.current
                            let currentDate = Date()
                            
                            // Get current time in target timezone
                            let currentComponents = calendar.dateComponents(in: targetTimeZone, from: currentDate)
                            
                            // Get selected time components (the picker returns in current device timezone, we interpret it as target timezone)
                            let selectedComponents = calendar.dateComponents([.hour, .minute], from: newTime)
                            
                            // Calculate the time difference in the target timezone
                            let currentMinutes = (currentComponents.hour ?? 0) * 60 + (currentComponents.minute ?? 0)
                            let selectedMinutes = (selectedComponents.hour ?? 0) * 60 + (selectedComponents.minute ?? 0)
                            
                            var minuteDifference = selectedMinutes - currentMinutes
                            
                            // Handle day boundary (wrap around midnight)
                            if minuteDifference < -720 {
                                minuteDifference += 1440
                            } else if minuteDifference > 720 {
                                minuteDifference -= 1440
                            }
                            
                            timeOffset = TimeInterval(minuteDifference * 60)
                            
                            // Show buttons when time is adjusted (only in normal mode, not continuous scroll mode)
                            if minuteDifference != 0 && !continuousScrollMode {
                                showScrollTimeButtons = true
                            }
                        }
                    ),
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: use24HourFormat ? "de_DE" : "en_US"))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 4) {
                        Text(cityName)
                            .font(.headline)
                        if !additionalTimeText.isEmpty {
                            Text(additionalTimeText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .blendMode(.plusLighter)
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    if showScrollTimeButtons || (continuousScrollMode && timeOffset != 0) {
                        Button(action: resetTime) {
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showSheet = false
                        
                        if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                            impactFeedback.prepare()
                            impactFeedback.impactOccurred()
                        }
                    }) {
                        Image(systemName: "checkmark")
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}

