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
                    HStack {
                        Label("Appearance", systemImage: "moon.circle")
                        Spacer()
                        Picker("", selection: $appearanceMode) {
                            Text("Light")
                                .tag("light")
                            Text("Dark")
                                .tag("dark")
                            Text("System")
                                .tag("system")
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                        .labelsHidden()
                    }
                }
                
                Section("Time Display") {
                    Toggle(isOn: $use24HourFormat) {
                        Label("24-Hour Format", systemImage: "clock")
                    }
                    Toggle(isOn: $showTimeDifference) {
                        Label("Show Time Difference", systemImage: "arrow.left.arrow.right")
                    }
                }
                
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Developer", systemImage: "person.circle")
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
