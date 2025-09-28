//
//  TimeOffsetPickerView.swift
//  touchtime
//
//  Created on 26/09/2025.
//

import SwiftUI

struct TimeOffsetPickerView: View {
    @Binding var timeOffset: TimeInterval
    @Binding var showTimePicker: Bool
    @State private var selectedTime: Date
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    
    init(timeOffset: Binding<TimeInterval>, showTimePicker: Binding<Bool>) {
        self._timeOffset = timeOffset
        self._showTimePicker = showTimePicker
        
        // Initialize selectedTime to current time plus existing offset
        self._selectedTime = State(initialValue: Date().addingTimeInterval(timeOffset.wrappedValue))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // System DatePicker for both formats
                DatePicker(
                    "",
                    selection: Binding(
                        get: { selectedTime },
                        set: { newTime in
                            selectedTime = newTime
                            
                            // Calculate offset from current real time
                            let calendar = Calendar.current
                            let currentDate = Date()
                            
                            // Get components from both times
                            let currentComponents = calendar.dateComponents([.hour, .minute], from: currentDate)
                            let selectedComponents = calendar.dateComponents([.hour, .minute], from: newTime)
                            
                            // Calculate the time difference
                            let currentMinutes = (currentComponents.hour ?? 0) * 60 + (currentComponents.minute ?? 0)
                            let selectedMinutes = (selectedComponents.hour ?? 0) * 60 + (selectedComponents.minute ?? 0)
                            
                            var minuteDifference = selectedMinutes - currentMinutes
                            
                            // Handle day boundary
                            if minuteDifference < -720 {
                                minuteDifference += 1440
                            } else if minuteDifference > 720 {
                                minuteDifference -= 1440
                            }
                            
                            timeOffset = TimeInterval(minuteDifference * 60)
                        }
                    ),
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: use24HourFormat ? "de_DE" : "en_US"))
                
            }
            .navigationTitle("Set Time")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}
