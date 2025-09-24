//
//  SettingsView.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showTimeDifference") private var showTimeDifference = true
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("showLocalTime") private var showLocalTime = true
    
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
                
                Section("Time Display") {
                    
                    Toggle(isOn: $showLocalTime) {
                        HStack {
                            Image(systemName: "location.fill")
                                .fontWeight(.medium)
                                .frame(width: 28)
                                .foregroundStyle(.secondary)
                            Text("Show Local Time")
                        }
                    }
                    
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
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("yuhang")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView()
}
