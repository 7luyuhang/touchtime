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
    
    var body: some View {
        NavigationView {
            Form {
                Section("General") {
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
                
                Section("Time Display") {
                    Toggle("24-Hour Format", isOn: $use24HourFormat)
                    Toggle("Show Time Difference", isOn: $showTimeDifference)
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
