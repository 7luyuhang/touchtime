//
//  WhatsNewSheet.swift
//  touchtime
//
//  Created on 25/12/2025.
//

import SwiftUI
import Combine

struct WhatsNewSheet: View {
    @Binding var showAnalogClock: Bool
    @Binding var showSunPosition: Bool
    @Binding var showSunAzimuth: Bool
    @Binding var showSunriseSunset: Bool
    @Binding var showWeatherCondition: Bool
    var showWeather: Bool
    @ObservedObject var weatherManager: WeatherManager
    @Binding var isPresented: Bool
    
    @State private var currentDate = Date()
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Check if any complication is selected
    private var hasSelectedComplication: Bool {
        showAnalogClock || showSunPosition || showSunAzimuth || showSunriseSunset || showWeatherCondition
    }
    
    // Complication type enum
    private enum ComplicationType: CaseIterable {
        case analogClock
        case sunElevation
        case sunAzimuth
        case sunriseSunset
        case weatherCondition
        
        var localizedName: String {
            switch self {
            case .analogClock: return String(localized: "Analog Clock")
            case .sunElevation: return String(localized: "Sun Elevation")
            case .sunAzimuth: return String(localized: "Sun Azimuth")
            case .sunriseSunset: return String(localized: "Sunrise & Sunset")
            case .weatherCondition: return String(localized: "Weather Condition")
            }
        }
    }
    
    private func selectComplication(_ type: ComplicationType?) {
        withAnimation(.spring()) {
            showAnalogClock = type == .analogClock
            showSunPosition = type == .sunElevation
            showSunAzimuth = type == .sunAzimuth
            showSunriseSunset = type == .sunriseSunset
            showWeatherCondition = type == .weatherCondition
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 32) {
                    // Description
                        Text(String(localized: "Add complications for quick, at-a-glance insights."))
                            .multilineTextAlignment(.center)
                    
                    // Complications
                    complicationSelector
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                Button {
                    if hapticEnabled {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    isPresented = false
                } label: {
                    Text(hasSelectedComplication ? String(localized: "Done") : String(localized: "Tap to Select"))
                        .font(.headline)
                        .foregroundStyle(hasSelectedComplication ? .black : .white)
                        .contentTransition(.numericText())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                        .background(
                            Capsule()
                                .fill(hasSelectedComplication ? .white : .secondary)
                                .glassEffect(.clear.interactive())
                        )
                }
                .buttonStyle(.plain)
                .disabled(!hasSelectedComplication)
                .padding(.horizontal, 24)
                .animation(.spring(), value: hasSelectedComplication)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        isPresented = false
                    } label: {
                        Text(String(localized: "Skip"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onReceive(timer) { _ in
                currentDate = Date()
            }
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Fetch weather for local timezone
                if showWeather {
                    Task {
                        await weatherManager.getWeather(for: TimeZone.current.identifier)
                    }
                }
            }
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
            
            // Sunrise & Sunset
            complicationOption(
                type: .sunriseSunset,
                isSelected: showSunriseSunset
            ) {
                SunriseSunsetIndicator(
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

