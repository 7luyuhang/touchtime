//
//  SettingsView.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import SwiftUI
import Combine

struct SettingsView: View {
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showTimeDifference") private var showTimeDifference = true
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("showLocalTime") private var showLocalTime = true
    @State private var currentDate = Date()
    
    // Timer for updating the preview
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Format time for preview
    func formatTime(use24Hour: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        
        if use24Hour {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm a"
            formatter.amSymbol = "am"
            formatter.pmSymbol = "pm"
        }
        
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
            return "0HRS"
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
                        HStack {
                            Image(systemName: "location.fill")
                                .fontWeight(.medium)
                                .frame(width: 28)
                                .foregroundStyle(.secondary)
                            Text("Show Local Time")
                        }
                    }
                }
                
                Section("Time Display") {
                    // Preview Section
                    VStack(alignment: .center, spacing: 8) {
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // Top row: Time difference and Date
                            if showTimeDifference {
                                HStack {
                                    Text(timeDifference())
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .contentTransition(.numericText())
                                    
                                    Spacer()
                                    
                                    Text(formatDate())
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .contentTransition(.numericText())
                                }
                            } else {
                                HStack {
                                    Spacer()
                                    
                                    Text(formatDate())
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .contentTransition(.numericText())
                                }
                            }
                            
                            // Bottom row: City name and Time
                            HStack(alignment: .lastTextBaseline) {
                                Text("London")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text(formatTime(use24Hour: use24HourFormat))
                                    .font(.system(size: 36))
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                    .id(use24HourFormat)
                            }
                            
                            
                            
                        }
                        .padding()
                        .background(Color(UIColor.tertiarySystemGroupedBackground))
                        .clipShape(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                        )
                        
                        
                        // Preview Text
                        Text("Preview")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }
                    .padding(.bottom, -8)
                    .listRowSeparator(.hidden)

                    Toggle(isOn: $use24HourFormat) {
                        HStack {
                            Image(systemName: "24.circle")
                                .fontWeight(.medium)
                                .frame(width: 28)
                                .foregroundStyle(.secondary)
                            Text("24-Hour Format")
                        }
                        
                    }
                    
                    Toggle(isOn: $showTimeDifference) {
                        HStack {
                            Image(systemName: "plusminus")
                                .fontWeight(.medium)
                                .frame(width: 28)
                                .foregroundStyle(.secondary)
                            Text("Show Time Difference")
                        }
                    }
                }
                
                Section(header: Text("About"), footer: Text("Designed by yuhang in London.")) {
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
}

#Preview {
    SettingsView()
}
