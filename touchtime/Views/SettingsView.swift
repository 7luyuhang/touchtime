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
    @AppStorage("use24HourFormat") private var use24HourFormat = true
    @AppStorage("showTimeDifference") private var showTimeDifference = true
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("showLocalTime") private var showLocalTime = false
    @AppStorage("showSkyDot") private var showSkyDot = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var currentDate = Date()
    @State private var showResetConfirmation = false
    
    // Timer for updating the preview
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Format time for preview (time part only)
    func formatTime(use24Hour: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        
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
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.dateFormat = "a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter.string(from: currentDate)
    }
    
    // Format date for preview
    func formatDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.dateFormat = "E, d MMM"
        return formatter.string(from: currentDate)
    }
    
    // Calculate time difference
    func timeDifference() -> String {
        guard let londonTimeZone = TimeZone(identifier: "Europe/London") else { return "" }
        let localTimeZone = TimeZone.current
        
        let londonOffset = londonTimeZone.secondsFromGMT(for: currentDate)
        let localOffset = localTimeZone.secondsFromGMT(for: currentDate)
        
        let difference = (londonOffset - localOffset) / 3600
        
        if difference == 0 {
            return "0h"
        } else if difference > 0 {
            return "+\(abs(difference))h"
        } else {
            return "-\(abs(difference))h"
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // General
                Section("General") {
                    HStack {
                        Picker("Appearance", selection: $appearanceMode) {
                            Text("System")
                                .tag("system")
                            Text("Light")
                                .tag("light")
                            Text("Dark")
                                .tag("dark")
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                    }
                }
                
                // Local Time
                Section(footer: Text("Enable showing local time at the top of the list.")) {
                    Toggle(isOn: $showLocalTime) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "location.fill", topColor: .gray, bottomColor: Color(UIColor.systemGray3))
                            Text("Local Time")
                        }
                    }
                    .frame(height: 0)
                }
                
                // Haptic
                Section {
                    Toggle(isOn: $hapticEnabled) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "wave.3.down", topColor: .blue, bottomColor: .cyan)
                            Text("Haptic")
                        }
                    }
                    .frame(height: 0)
                }
                
                
                // Time Display
                Section("Time Display") {
                    
                    // Preview Section
                    VStack(alignment: .center, spacing: 10) {

                        VStack(alignment: .leading, spacing: 4) {
                            // Top row: Time difference and Date
                            HStack {
                                if showSkyDot {
                                    SkyDotView(
                                        date: currentDate,
                                        timeZoneIdentifier: "Europe/London"
                                    )
                                }
                                
                                if showTimeDifference {
                                    Text(timeDifference())
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(formatDate())
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Bottom row: City name and Time
                            HStack(alignment: .lastTextBaseline) {
                                Text("City")
                                    .font(.headline)
                                
                                Spacer()
                                
                                HStack(alignment: .lastTextBaseline, spacing: 4) {
                                    Text(formatTime(use24Hour: use24HourFormat))
                                        .font(.system(size: 36))
                                        .monospacedDigit()
                                    
                                    if !use24HourFormat {
                                        Text(formatAMPM())
                                            .font(.headline)
                                    }
                                }
                                .id(use24HourFormat)
                            }
                        }
                        .padding()
                        .padding(.bottom, -8)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 1.5)
                        )
                        
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
                
                // Reset Section
                Section{
                    Button(action: {
                        showResetConfirmation = true
                    }) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "arrowshape.backward.fill", topColor: .red, bottomColor: .yellow)
                            Text("Reset Cities")
                        }
                        .frame(height: 0)
                        
                    }
                    .foregroundStyle(.primary)
                    .confirmationDialog("", isPresented: $showResetConfirmation) {
                        Button("Reset", role: .destructive) {
                            resetToDefault()
                        }
                    } message: {
                        Text("This will reset all cities to the default list.")
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
                    HStack{
                        Text("Terms of Use")}
                    HStack{
                        Text("Privacy Policy")
                    }
                }
                
                
                Section(footer:
                            HStack(spacing: 4) {
                                Text("Designed by")
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
            .onReceive(timer) { _ in
                currentDate = Date()
            }
            .safeAreaPadding(.bottom, 24)
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
