//
//  SettingsView.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import SwiftUI
import Combine

struct SettingsView: View {
    @Binding var worldClocks: [WorldClock]
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showTimeDifference") private var showTimeDifference = true
    @AppStorage("showLocalTime") private var showLocalTime = false
    @AppStorage("showSkyDot") private var showSkyDot = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("defaultEventDuration") private var defaultEventDuration: Double = 3600 // Default 1 hour in seconds
    @AppStorage("showCitiesInNotes") private var showCitiesInNotes = true
    @AppStorage("selectedCitiesForNotes") private var selectedCitiesForNotes: String = ""
    @State private var currentDate = Date()
    @State private var showResetConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    // Timer for updating the preview
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Format time for preview (time part only)
    func formatTime(use24Hour: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        if use24Hour {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm"
        }
        
        return formatter.string(from: currentDate)
    }
    
    // Format AM/PM for preview
    func formatAMPM() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter.string(from: currentDate)
    }
    
    // Format date for preview
    func formatDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "E, d MMM"
        return formatter.string(from: currentDate)
    }
    
    // Calculate time difference
    func timeDifference() -> String {
        // Since we're showing local time, there's no time difference
        return "0h"
    }
    
    // Get city count text for Notes setting
    func getCityCountText() -> String {
        if !showCitiesInNotes {
            return ""
        }
        
        let selectedIds = selectedCitiesForNotes.split(separator: ",").map { String($0) }
        // Filter to only count cities that still exist in worldClocks
        let existingIds = worldClocks.map { $0.id.uuidString }
        let validSelectedIds = selectedIds.filter { !$0.isEmpty && existingIds.contains($0) }
        let count = validSelectedIds.count
        
        if count == 0 {
            return ""
        } else if count == 1 {
            return "1 City"
        } else {
            return "\(count) Cities"
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // General
                Section(header: Text("General"), footer: Text("Enable showing system time at the top of the list.")) {
                    Toggle(isOn: $hapticEnabled) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "water.waves", topColor: .blue, bottomColor: .cyan)
                            Text("Haptics")
                        }
                    }
                    Toggle(isOn: $showLocalTime) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "location.fill", topColor: .gray, bottomColor: Color(UIColor.systemGray3))
                            Text("System Time")
                        }
                    }
                }
 
                // Display
                Section("Display") {
                    // Preview Section
                    VStack(alignment: .center, spacing: 10) {

                        VStack(alignment: .leading, spacing: 4) {
                            // Top row: Time difference and Date
                            HStack {
                                if showSkyDot {
                                        SkyDotView(
                                            date: currentDate,
                                            timeZoneIdentifier: TimeZone.current.identifier
                                        )
                                        .transition(.blurReplace)
                                }
                                
                                
                                if showTimeDifference {
                                    Text(timeDifference())
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .blendMode(.plusLighter)
                                }
                                
                                Spacer()
                                
                                // Date
                                Text(formatDate())
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .contentTransition(.numericText())
                                    .blendMode(.plusLighter)
                                    .animation(.spring(), value: currentDate)
                                
                            }
                            .animation(.spring(), value: showSkyDot)
                            
                            // Bottom row: City name and Time
                            HStack(alignment: .lastTextBaseline) {
                                Text("City")
                                    .font(.headline)
                                
                                Spacer()
                                
                                HStack(alignment: .lastTextBaseline, spacing: 2) {
                                    Text(formatTime(use24Hour: use24HourFormat))
                                        .font(.system(size: 36))
                                        .fontWeight(.light)
                                        .monospacedDigit()
                                        .contentTransition(.numericText())
                                        .animation(.spring(), value: currentDate)
                                    
                                    if !use24HourFormat {
                                        Text(formatAMPM())
                                            .font(.headline)
                                            .contentTransition(.numericText())
                                    }
                                }
                                .id(use24HourFormat)
                            }
                        }
                        .padding()
                        .padding(.bottom, -8)
                        .background(
                            showSkyDot ? 
                            ZStack {
                                Color.black
                                SkyBackgroundView(
                                    date: currentDate,
                                    timeZoneIdentifier: TimeZone.current.identifier
                                )
                            } : nil
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 1.5)
                                .blendMode(.plusLighter)
                        )
                        .animation(.spring(), value: showSkyDot)
                        
                        // Preview Text
                        Text("Preview")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, -16)
                        
                    }
                    .listRowSeparator(.hidden)
                    
                    
                    // Options in Settings
                    Toggle(isOn: $showSkyDot) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "cloud.fill", topColor: .blue, bottomColor: .white)
                            Text("Sky Colour")
                        }
                    }
                    
                    Toggle(isOn: $showTimeDifference) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "plusminus", topColor: .indigo, bottomColor: .pink)
                            Text("Time Difference")
                        }
                    }
                    
                    Toggle(isOn: $use24HourFormat) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "24.circle", topColor: .gray, bottomColor: Color(UIColor.systemGray3))
                            Text("24-Hour Format")
                        }
                    }
                    
                }
                
                // Calendar
                Section("Calender") {
                    Picker(selection: $defaultEventDuration) {
                        Text("15 min").tag(900.0)
                        Text("30 min").tag(1800.0)
                        Text("45 min").tag(2700.0)
                        Text("1 hr").tag(3600.0)
                        Text("2 hrs").tag(7200.0)
                    } label: {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "clock.fill", topColor: .blue, bottomColor: .cyan)
                            Text("Event Duration")
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    
                    // Show cities in note
                    NavigationLink(destination: CitySelectionSheet(
                        worldClocks: worldClocks,
                        selectedCitiesForNotes: $selectedCitiesForNotes,
                        showCitiesInNotes: $showCitiesInNotes
                    )) {
                        HStack {
                            HStack(spacing: 12) {
                                SystemIconImage(systemName: "pencil.tip", topColor: .orange, bottomColor: .yellow)
                                Text("Time in Notes")
                            }
                            Spacer()
                            Text(getCityCountText())
                            .foregroundStyle(.secondary)
                        }
                    }
                }
     
                // Reset Section
                Section{
                    Button(action: {
                        showResetConfirmation = true
                    }) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "arrowshape.backward.fill", topColor: .red, bottomColor: .yellow)
                            Text("Reset Cities")
                        }
                        
                    }
                    .foregroundStyle(.primary)
                    .confirmationDialog("", isPresented: $showResetConfirmation) {
                        Button("Reset", role: .destructive) {
                            resetToDefault()
                        }
                    } message: {
                        Text("This will reset all cities to the default list and clear any custom city names.")
                    }
                }
                
                Section(header: Text("Others")) {
                    Button(action: {
                        if let url = URL(string: "mailto:7luyuhang@gmail.com?subject=TouchTime%20Feedback") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Send Feedback")
                            
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    
                    Link(destination: URL(string: "https://apps.apple.com/app/touchtime/id123456789?action=write-review")!) {
                        HStack {
                            Text("Review on App Store")
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    ShareLink(
                        item: URL(string: "https://apps.apple.com/app/touchtime")!,
                        message: Text("Download Touch Time.")
                    ) {
                        HStack {
                            Text("Share with Friends")
                        }
                    }
                    .foregroundStyle(.primary)
                }
                
                
                Section {
                    Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                        HStack {
                            Text("Terms of Use")
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Link(destination: URL(string: "https://www.handstime.app/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                        }
                    }
                    .foregroundStyle(.primary)
                }
                
                
                Section(footer:
                            HStack(spacing: 4) {
                                Text("Designed & built by")
                                    .foregroundColor(.secondary)
                                    .font(.footnote)
                                
                                Menu {
                                    Link(destination: URL(string: "https://luyuhang.net")!) {
                                        Text("Website")
                                    }
                                    
                                    Link(destination: URL(string: "https://www.instagram.com/7ahang/")!) {
                                        Text("Instagram")
                                    }
                                    
                                    Link(destination: URL(string: "https://x.com/7luyuhang")!) {
                                        Text("X")
                                    }
                                } label: {
                                    Text("yuhang")
                                        .font(.footnote)
                                        .fontWeight(.semibold)
                                }
                                .buttonStyle(.plain)
                                
                                Text("in London.")
                                    .foregroundColor(.secondary)
                                    .font(.footnote)
                            }
                            .foregroundStyle(.primary)
                                
                        ) {
                    // App Info Section
                    Text("Copyright © 2025 Negative Time Limited. \nAll rights reserved.") // "\n" 换行
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
 
                    // Version
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(getVersionString())
                            .foregroundColor(.secondary)
                    }
                }
                
                
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                    }
                }
            }
            .onReceive(timer) { _ in
                currentDate = Date()
            }
        }
    }
    
    // UserDefaults key for storing world clocks
    private let worldClocksKey = "savedWorldClocks"
    
    // Reset to default clocks
    func resetToDefault() {
        // Set to default clocks
        worldClocks = WorldClockData.defaultClocks
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(worldClocks) {
            UserDefaults.standard.set(encoded, forKey: worldClocksKey)
        }
        
        // Provide haptic feedback if enabled
        if hapticEnabled {
            let impactFeedback = UINotificationFeedbackGenerator()
            impactFeedback.prepare()
            impactFeedback.notificationOccurred(.success)
        }
    }
    
    // Get version and build number string
    func getVersionString() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
