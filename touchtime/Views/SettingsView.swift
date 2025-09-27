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
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("showLocalTime") private var showLocalTime = true
    @AppStorage("showSkyDot") private var showSkyDot = true
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
        NavigationView {
            Form {
                Section("General") {
                    HStack {
                        Picker("Appearance", selection: $appearanceMode) {
                            Text("Light")
                                .tag("light")
                            Text("Dark")
                                .tag("dark")
                            Text("System")
                                .tag("system")
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                    }
                }
                
                Section(footer: Text("Enable showing local time at the top of the list.")) {
                    Toggle(isOn: $showLocalTime) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "location.fill", topColor: .gray, bottomColor: Color(UIColor.systemGray3))
                            Text("Local Time")
                        }
                    }
                }
                
                Section("Time Display") {
                    
                    // Preview Section
                    VStack(alignment: .center, spacing: 10) {
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // Top row: Time difference and Date
                            if showTimeDifference {
                                HStack {
                                    if showSkyDot {
                                        SkyDotView(
                                            date: currentDate,
                                            timeZoneIdentifier: "Europe/London"
                                        )
                                    }
                                    
                                    Text(timeDifference())
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    Text(formatDate())
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                       
                                }
                            } else {
                                HStack {
                                    if showSkyDot {
                                        SkyDotView(
                                            date: currentDate,
                                            timeZoneIdentifier: "Europe/London"
                                        )
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatDate())
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        
                                }
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
                        .padding(.bottom, -4)
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
                
                Section(header: Text("About"), footer: 
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
                    
                    Button(action: {
                        if let url = URL(string: "mailto:7luyuhang@gmail.com?subject=TouchTime%20Feedback") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                            Text("Send Feedback")
                    }
                    .foregroundStyle(.primary)
                    
                    
                    HStack {
                        Text("Leave a Review")
                    }
                    
                    HStack {
                        Text("Share with Friends")
                    }
                    
                    // Version
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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
        
        // Provide haptic feedback
        let impactFeedback = UINotificationFeedbackGenerator()
        impactFeedback.prepare()
        impactFeedback.notificationOccurred(.success)
    }
}
