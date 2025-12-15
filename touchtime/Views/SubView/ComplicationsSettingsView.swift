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
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showSkyDot") private var showSkyDot = true
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("additionalTimeDisplay") private var additionalTimeDisplay = "None"
    @AppStorage("useCelsius") private var useCelsius = true
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
        
        var iconName: String {
            switch self {
            case .analogClock: return "watchface.applewatch.case"
            case .sunElevation: return "sun.horizon.fill"
            case .sunAzimuth: return "compass.drawing"
            case .weatherCondition: return "snowflake"
            }
        }
    }
    
    private var selectedComplication: ComplicationType? {
        if showAnalogClock { return .analogClock }
        if showSunPosition { return .sunElevation }
        if showSunAzimuth { return .sunAzimuth }
        if showWeatherCondition { return .weatherCondition }
        return nil
    }
    
    private func selectComplication(_ type: ComplicationType?) {
        withAnimation(.spring()) {
            showAnalogClock = type == .analogClock
            showSunPosition = type == .sunElevation
            showSunAzimuth = type == .sunAzimuth
            showWeatherCondition = type == .weatherCondition
        }
    }
    
    // Format time for preview
    private func formatTime() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = use24HourFormat ? "HH:mm" : "h:mm"
        return formatter.string(from: currentDate)
    }
    
    // Format date for preview
    private func formatDate() -> String {
        return currentDate.formattedDate(style: dateStyle, timeZone: TimeZone.current)
    }
    
    // Calculate additional time display
    private func additionalTimeText() -> String {
        switch additionalTimeDisplay {
        case "Time Difference":
            return String(format: String(localized: "%d hours"), 0)
        case "UTC":
            let offsetSeconds = TimeZone.current.secondsFromGMT()
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Preview
                VStack(spacing: 8) {
                    previewCard
                    Text("Preview")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                .padding(.top, 24)
                
                // Complications
                complicationSelector
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Complications")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            currentDate = Date()
        }
    }
    
    // MARK: - Preview Card
    private var previewCard: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 4) {
                // Top row: Time difference and Date with Weather
                HStack {
                    if showSkyDot {
                        SkyDotView(
                            date: currentDate,
                            timeZoneIdentifier: TimeZone.current.identifier
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                                .blendMode(.plusLighter)
                        )
                        .transition(.blurReplace)
                    }
                    
                    if additionalTimeDisplay != "None" {
                        Text(additionalTimeText())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .blendMode(.plusLighter)
                    }
                    
                    Spacer()
                    
                    // Weather for local time
                    if showWeather {
                        WeatherView(
                            weather: weatherManager.currentWeather,
                            useCelsius: useCelsius
                        )
                        .transition(.blurReplace)
                    }
                    
                    // Date
                    Text(formatDate())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .contentTransition(.numericText())
                        .animation(.spring(), value: currentDate)
                }
                .animation(.spring(), value: showSkyDot)
                .animation(.spring(), value: showWeather)
                
                // Bottom row: City name and Time
                HStack(alignment: .lastTextBaseline) {
                    Text("City")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(formatTime())
                        .font(.system(size: 36))
                        .fontWeight(.light)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(), value: currentDate)
                }
            }
            .padding()
            .padding(.bottom, -4)
            
            // Complication Overlays
            if showAnalogClock {
                AnalogClockView(
                    date: currentDate,
                    size: 64,
                    timeZone: TimeZone.current,
                    useMaterialBackground: true
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                        .blendMode(.plusLighter)
                )
                .transition(.blurReplace.combined(with: .scale))
            }
            
            if showSunPosition {
                SunPositionIndicator(
                    date: currentDate,
                    timeZone: TimeZone.current,
                    size: 64,
                    useMaterialBackground: true
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                        .blendMode(.plusLighter)
                )
                .transition(.blurReplace.combined(with: .scale))
            }
            
            if showSunAzimuth {
                SunAzimuthIndicator(
                    date: currentDate,
                    timeZone: TimeZone.current,
                    size: 64,
                    useMaterialBackground: true
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                        .blendMode(.plusLighter)
                )
                .transition(.blurReplace.combined(with: .scale))
            }
            
            if showWeatherCondition {
                WeatherConditionView(
                    timeZone: TimeZone.current,
                    size: 64,
                    useMaterialBackground: true
                )
                .environmentObject(weatherManager)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                        .blendMode(.plusLighter)
                )
                .transition(.blurReplace.combined(with: .scale))
            }
        }
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
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .animation(.spring(), value: showAnalogClock)
        .animation(.spring(), value: showSunPosition)
        .animation(.spring(), value: showSunAzimuth)
        .animation(.spring(), value: showWeatherCondition)
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
