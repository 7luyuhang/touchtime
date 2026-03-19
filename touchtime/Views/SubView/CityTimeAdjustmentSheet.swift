//
//  CityTimeAdjustmentSheet.swift
//  touchtime
//
//  Created on 12/12/2025.
//

import SwiftUI
import AlarmKit
import UIKit

struct CityTimeAdjustmentSheet: View {
    let cityName: String
    let timeZoneIdentifier: String
    @Binding var timeOffset: TimeInterval
    @Binding var showSheet: Bool
    @Binding var showScrollTimeButtons: Bool
    
    @State private var selectedTime: Date
    @State private var showAlarmPermissionAlert = false
    @State private var showAlarmErrorAlert = false
    @State private var alarmErrorMessage = ""
    @State private var isSchedulingAlarm = false
    @State private var showAlarmSuccessIcon = false
    @State private var alarmIconResetTask: Task<Void, Never>? = nil
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("additionalTimeDisplay") private var additionalTimeDisplay = "None"
    @AppStorage("continuousScrollMode") private var continuousScrollMode = true

    private let alarmManager = AlarmManager.shared
    
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
            .safeAreaPadding(.bottom, 8)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(action: {
                    Task {
                        await setAlarmFromSelectedCityTime()
                    }
                }) {
                        HStack(spacing: 12) {
                            HStack (spacing: 8) {
                                Image(systemName: showAlarmSuccessIcon ? "checkmark.circle.fill" : "alarm.fill")
                                    .font(.headline)
                                    .contentTransition(.symbolEffect(.replace))
                                    .animation(.snappy(duration: 0.15), value: showAlarmSuccessIcon)
                                
                                Text(String(localized: "Set Alarm"))
                                    .font(.subheadline.weight(.semibold))
                            }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.subheadline.weight(.semibold))
                            
                            Text(adjustedLocalTimeText)
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .animation(.smooth(duration: 0.25), value: adjustedLocalTimeText)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.tint(.blue))
                        .foregroundStyle(.white)
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 10)
                    .padding(.vertical, 10)
                }
                // Border
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        .blendMode(.plusLighter)
                )
                .contentShape(Capsule(style: .continuous))
                .glassEffect(.regular.interactive())
                .buttonStyle(.plain)
                .disabled(isSchedulingAlarm)
                .opacity(isSchedulingAlarm ? 0.50 : 1)
                .offset(y: 8) // Overall button offset
            }
        }
        .onDisappear {
            alarmIconResetTask?.cancel()
            alarmIconResetTask = nil
            showAlarmSuccessIcon = false
        }
        .alert("Alarm Permission Needed", isPresented: $showAlarmPermissionAlert) {
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Go to Settings")) {
                AlarmSupport.openSystemSettings()
            }
        } message: {
            Text("Please allow alarm access in Settings to create alarms.")
        }
        .alert("Alarm Error", isPresented: $showAlarmErrorAlert) {
            Button(String(localized: "Done"), role: .cancel) { }
        } message: {
            Text(alarmErrorMessage)
        }
        .presentationDetents([.height(360)])
    }

    @MainActor
    private func setAlarmFromSelectedCityTime() async {
        guard !isSchedulingAlarm else { return }
        guard let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) else { return }

        isSchedulingAlarm = true
        defer { isSchedulingAlarm = false }

        guard await ensureAlarmAuthorization() else { return }

        let selectedComponents = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        guard let cityHour = selectedComponents.hour,
              let cityMinute = selectedComponents.minute else { return }

        let localTime = convertCityTimeToLocalTime(
            cityHour: cityHour,
            cityMinute: cityMinute,
            targetTimeZone: targetTimeZone
        )
        var records = loadAlarmRecords()

        do {
            let matchingIndices = records.indices.filter { records[$0].hour == localTime.hour && records[$0].minute == localTime.minute }

            if let existingIndex = matchingIndices.first {
                for duplicateIndex in matchingIndices.dropFirst().sorted(by: >) {
                    let duplicateID = records[duplicateIndex].id
                    try? alarmManager.cancel(id: duplicateID)
                    records.remove(at: duplicateIndex)
                }

                var updatedRecords = records
                var updatedRecord = updatedRecords[existingIndex]
                updatedRecord.isEnabled = true
                updatedRecord.sourceCityName = cityName
                updatedRecord.sourceCityHour = cityHour
                updatedRecord.sourceCityMinute = cityMinute
                updatedRecords[existingIndex] = updatedRecord

                try? alarmManager.cancel(id: updatedRecord.id)
                try await AlarmSupport.scheduleAlarm(
                    id: updatedRecord.id,
                    hour: localTime.hour,
                    minute: localTime.minute,
                    using: alarmManager
                )
                saveAlarmRecords(updatedRecords)
            } else {
                let record = AlarmRecord(
                    id: UUID(),
                    hour: localTime.hour,
                    minute: localTime.minute,
                    isEnabled: true,
                    createdAt: Date(),
                    sourceCityName: cityName,
                    sourceCityHour: cityHour,
                    sourceCityMinute: cityMinute
                )

                try await AlarmSupport.scheduleAlarm(
                    id: record.id,
                    hour: localTime.hour,
                    minute: localTime.minute,
                    using: alarmManager
                )

                var updatedRecords = records
                updatedRecords.append(record)
                saveAlarmRecords(updatedRecords)
            }

            if hapticEnabled {
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.prepare()
                notificationFeedback.notificationOccurred(.success)
            }
            showAlarmSuccessTemporarily()
        } catch {
            alarmErrorMessage = error.localizedDescription
            showAlarmErrorAlert = true
        }
    }

    @MainActor
    private func ensureAlarmAuthorization() async -> Bool {
        switch await AlarmSupport.ensureAuthorization(using: alarmManager) {
        case .authorized:
            return true
        case .denied:
            showAlarmPermissionAlert = true
            return false
        case .failed(let error):
            alarmErrorMessage = error.localizedDescription
            showAlarmErrorAlert = true
            return false
        }
    }

    private func convertCityTimeToLocalTime(cityHour: Int, cityMinute: Int, targetTimeZone: TimeZone) -> (hour: Int, minute: Int) {
        let now = Date()
        let localOffsetMinutes = TimeZone.current.secondsFromGMT(for: now) / 60
        let targetOffsetMinutes = targetTimeZone.secondsFromGMT(for: now) / 60

        let selectedCityTotalMinutes = cityHour * 60 + cityMinute
        let localTotalMinutes = selectedCityTotalMinutes + (localOffsetMinutes - targetOffsetMinutes)
        let normalizedMinutes = ((localTotalMinutes % 1440) + 1440) % 1440

        return (hour: normalizedMinutes / 60, minute: normalizedMinutes % 60)
    }

    private func loadAlarmRecords() -> [AlarmRecord] {
        AlarmSupport.loadRecords()
    }

    private func saveAlarmRecords(_ records: [AlarmRecord]) {
        AlarmSupport.saveRecords(records)
    }

    private var adjustedLocalTimeText: String {
        guard let localTime = selectedLocalAlarmTime else {
            return "--:--"
        }

        return formattedLocalTime(hour: localTime.hour, minute: localTime.minute)
    }

    private var selectedLocalAlarmTime: (hour: Int, minute: Int)? {
        guard let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }

        let selectedComponents = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        let cityHour = selectedComponents.hour ?? 0
        let cityMinute = selectedComponents.minute ?? 0
        return convertCityTimeToLocalTime(
            cityHour: cityHour,
            cityMinute: cityMinute,
            targetTimeZone: targetTimeZone
        )
    }

    private func formattedLocalTime(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let calendar = Calendar.current
        let date = calendar.date(from: components) ?? Date()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: use24HourFormat ? "de_DE" : "en_US")
        formatter.timeZone = .current
        formatter.dateFormat = use24HourFormat ? "HH:mm" : "h:mm a"

        if use24HourFormat {
            return formatter.string(from: date)
        }

        return formatter.string(from: date).lowercased()
    }

    @MainActor
    private func showAlarmSuccessTemporarily() {
        alarmIconResetTask?.cancel()
        withAnimation(.snappy(duration: 0.15)) {
            showAlarmSuccessIcon = true
        }

        alarmIconResetTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                withAnimation(.snappy(duration: 0.15)) {
                    showAlarmSuccessIcon = false
                }
            }
        }
    }
}
