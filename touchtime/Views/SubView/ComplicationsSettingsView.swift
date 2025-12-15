//
//  ComplicationsSettingsView.swift
//  touchtime
//
//  Created on 14/12/2025.
//

import SwiftUI
import Combine

struct ComplicationsSettingsView: View {
    @Binding var showAnalogClock: Bool
    @Binding var showSunPosition: Bool
    @Binding var showSunAzimuth: Bool
    @Binding var showWeatherCondition: Bool
    var showWeather: Bool
    @ObservedObject var weatherManager: WeatherManager
    
    @State private var currentDate = Date()
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Currently selected complication type
    private enum ComplicationType: CaseIterable {
        case analogClock
        case sunElevation
        case sunAzimuth
        case weatherCondition
        
        var localizedName: String {
            switch self {
            case .analogClock: return String(localized: "Analog Clock")
            case .sunElevation: return String(localized: "Sun Elevation")
            case .sunAzimuth: return String(localized: "Sun Azimuth")
            case .weatherCondition: return String(localized: "Weather Condition")
            }
        }
        
    }
    
    private func selectComplication(_ type: ComplicationType?) {
        withAnimation(.spring()) {
            showAnalogClock = type == .analogClock
            showSunPosition = type == .sunElevation
            showSunAzimuth = type == .sunAzimuth
            showWeatherCondition = type == .weatherCondition
        }
    }
    
    var body: some View {
        VStack {
            Spacer()
            // Complications
            complicationSelector
                .padding(.horizontal, 24)
            Spacer()
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Complications")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            currentDate = Date()
        }
    }
    
    // MARK: - Complication Selector
    private var complicationSelector: some View {
        HStack(alignment: .top, spacing: 16) {
            // Analog Clock
            complicationOption(
                type: .analogClock,
                isSelected: showAnalogClock
            ) {
                AnalogClockView(
                    date: currentDate,
                    size: 64,
                    timeZone: TimeZone.current,
                    useMaterialBackground: false
                )
            }
            
            // Sun Elevation
            complicationOption(
                type: .sunElevation,
                isSelected: showSunPosition
            ) {
                SunPositionIndicator(
                    date: currentDate,
                    timeZone: TimeZone.current,
                    size: 64,
                    useMaterialBackground: false
                )
            }
            
            // Sun Azimuth
            complicationOption(
                type: .sunAzimuth,
                isSelected: showSunAzimuth
            ) {
                SunAzimuthIndicator(
                    date: currentDate,
                    timeZone: TimeZone.current,
                    size: 64,
                    useMaterialBackground: false
                )
            }
            
            // Weather Condition (only show if weather is enabled)
            if showWeather {
                complicationOption(
                    type: .weatherCondition,
                    isSelected: showWeatherCondition
                ) {
                    WeatherConditionView(
                        timeZone: TimeZone.current,
                        size: 64,
                        useMaterialBackground: false
                    )
                    .environmentObject(weatherManager)
                }
            }
        }
    }
    
    // MARK: - Complication Option View
    private func complicationOption<Content: View>(
        type: ComplicationType,
        isSelected: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button {
            if hapticEnabled {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
            if isSelected {
                selectComplication(nil)
            } else {
                selectComplication(type)
            }
        } label: {
            VStack(spacing: 10) {
                content()
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.25))
                            .glassEffect(.clear)
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected ? Color.white : Color.clear,
                                lineWidth: isSelected ? 2 : 0
                            )
                    )
                
                Text(type.localizedName)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .animation(.spring(), value: isSelected)
    }
}
