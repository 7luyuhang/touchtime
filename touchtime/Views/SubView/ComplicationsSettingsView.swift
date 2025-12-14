//
//  ComplicationsSettingsView.swift
//  touchtime
//
//  Created on 14/12/2025.
//

import SwiftUI

struct ComplicationsSettingsView: View {
    @Binding var showAnalogClock: Bool
    @Binding var showSunPosition: Bool
    @Binding var showSunAzimuth: Bool
    @Binding var showWeatherCondition: Bool
    var showWeather: Bool
    
    var body: some View {
        List {
            Section {
                Toggle(isOn: Binding(
                    get: { showAnalogClock },
                    set: { newValue in
                        showAnalogClock = newValue
                        if newValue {
                            showSunPosition = false
                            showWeatherCondition = false
                            showSunAzimuth = false
                        }
                    }
                )) {
                    HStack(spacing: 12) {
                        SystemIconImage(systemName: "watchface.applewatch.case", topColor: .gray, bottomColor: Color(UIColor.systemGray3))
                        Text(String(localized: "Analog Clock"))
                    }
                }
                .tint(.blue)
                
                Toggle(isOn: Binding(
                    get: { showSunPosition },
                    set: { newValue in
                        showSunPosition = newValue
                        if newValue {
                            showAnalogClock = false
                            showWeatherCondition = false
                            showSunAzimuth = false
                        }
                    }
                )) {
                    HStack(spacing: 12) {
                        SystemIconImage(systemName: "sun.horizon.fill", topColor: .yellow, bottomColor: .orange)
                        Text(String(localized: "Sun Elevation"))
                    }
                }
                .tint(.blue)
                
                Toggle(isOn: Binding(
                    get: { showSunAzimuth },
                    set: { newValue in
                        showSunAzimuth = newValue
                        if newValue {
                            showAnalogClock = false
                            showSunPosition = false
                            showWeatherCondition = false
                        }
                    }
                )) {
                    HStack(spacing: 12) {
                        SystemIconImage(systemName: "compass.drawing", topColor: .blue, bottomColor: .blue)
                        Text(String(localized: "Sun Azimuth"))
                    }
                }
                .tint(.blue)
                
                if showWeather {
                    Toggle(isOn: Binding(
                        get: { showWeatherCondition },
                        set: { newValue in
                            showWeatherCondition = newValue
                            if newValue {
                                showAnalogClock = false
                                showSunPosition = false
                                showSunAzimuth = false
                            }
                        }
                    )) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "snowflake", topColor: .gray, bottomColor: Color(UIColor.systemGray3))
                            Text(String(localized: "Weather Condition"))
                        }
                    }
                    .tint(.blue)
                }
            } footer: {
                Text("Add complications in the middle of the city list.")
            }
        }
        .navigationTitle("Complications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

