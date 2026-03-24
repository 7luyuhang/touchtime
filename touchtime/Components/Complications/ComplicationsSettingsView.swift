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
    @Binding var showPhotoComplication: Bool
    @Binding var showSunAzimuth: Bool
    @Binding var showMoonAzimuth: Bool
    @Binding var showMoonSunAzimuth: Bool
    @Binding var showSunriseSunset: Bool
    @Binding var showWeatherCondition: Bool
    @Binding var showTemperatureIndicator: Bool
    @Binding var showUVIndex: Bool
    @Binding var showWindDirection: Bool
    @Binding var showDaylight: Bool
    @Binding var showSolarCurve: Bool
    var showWeather: Bool
    @ObservedObject var weatherManager: WeatherManager
    
    @State private var currentDate = Date()
    @State private var showLifetimeStore = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("hasLifetimeAccess") private var hasLifetimeAccess = false
    @AppStorage("analogClockShowScale") private var analogClockShowScale = false
    @AppStorage("analogClockShowUTCHand") private var analogClockShowUTCHand = false
    @AppStorage("weatherConditionUseColoredIcon") private var weatherConditionUseColoredIcon = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Currently selected complication type
    private enum ComplicationType: CaseIterable {
        case analogClock
        case sunElevation
        case photo
        case sunAzimuth
        case moonAzimuth
        case moonSunAzimuth
        case sunriseSunset
        case weatherCondition
        case temperatureIndicator
        case uvIndex
        case windDirection
        case daylight
        case solarCurve
        
        var localizedName: String {
            switch self {
            case .analogClock: return String(localized: "Analog Clock")
            case .sunElevation: return String(localized: "Sun Elevation")
            case .photo: return String(localized: "Photo")
            case .sunAzimuth: return String(localized: "Sun Azimuth")
            case .moonAzimuth: return String(localized: "Moon Azimuth")
            case .moonSunAzimuth: return String(localized: "Moon & Sun Azimuth")
            case .sunriseSunset: return String(localized: "Sunrise & Sunset")
            case .weatherCondition: return String(localized: "Weather Condition")
            case .temperatureIndicator: return String(localized: "Temperature Indicator")
            case .uvIndex: return String(localized: "UV Index")
            case .windDirection: return String(localized: "Wind Direction")
            case .daylight: return String(localized: "Daylight Curve")
            case .solarCurve: return String(localized: "Solar Curve")
            }
        }
        
    }
    
    private func selectComplication(_ type: ComplicationType?) {
        withAnimation(.spring()) {
            showAnalogClock = type == .analogClock
            showSunPosition = type == .sunElevation
            showPhotoComplication = type == .photo
            showSunAzimuth = type == .sunAzimuth
            showMoonAzimuth = type == .moonAzimuth
            showMoonSunAzimuth = type == .moonSunAzimuth
            showSunriseSunset = type == .sunriseSunset
            showWeatherCondition = type == .weatherCondition
            showTemperatureIndicator = type == .temperatureIndicator
            showUVIndex = type == .uvIndex
            showWindDirection = type == .windDirection
            showDaylight = type == .daylight
            showSolarCurve = type == .solarCurve
        }
    }

    private func isLocked(_ type: ComplicationType) -> Bool {
        switch type {
        case .moonAzimuth, .moonSunAzimuth, .weatherCondition, .temperatureIndicator, .uvIndex, .windDirection, .daylight:
            return !hasLifetimeAccess
        default:
            return false
        }
    }

    private func enforceLifetimeAccess() {
        guard !hasLifetimeAccess else { return }

        if showMoonAzimuth || showMoonSunAzimuth || showWeatherCondition || showTemperatureIndicator || showUVIndex || showWindDirection || showDaylight {
            selectComplication(nil)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            complicationSelector
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal)
        .scrollIndicators(.hidden)
        .navigationTitle("Complications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if showAnalogClock || (showWeather && showWeatherCondition) {
                    Menu {
                        Section(String(localized: "Customisation")) {
                            if showAnalogClock {
                                Button {
                                    analogClockShowScale.toggle()
                                    if hapticEnabled {
                                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                    }
                                } label: {
                                    if analogClockShowScale {
                                        Label(String(localized: "Dial Marker"), systemImage: "checkmark.circle")
                                    } else {
                                        Text(String(localized: "Dial Marker"))
                                    }
                                }

                                Button {
                                    analogClockShowUTCHand.toggle()
                                    if hapticEnabled {
                                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                    }
                                } label: {
                                    if analogClockShowUTCHand {
                                        Label(String(localized: "UTC Hand"), systemImage: "checkmark.circle")
                                    } else {
                                        Text(String(localized: "UTC Hand"))
                                    }
                                }
                            }

                            if showWeather && showWeatherCondition {
                                Button {
                                    weatherConditionUseColoredIcon.toggle()
                                    if hapticEnabled {
                                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                    }
                                } label: {
                                    if weatherConditionUseColoredIcon {
                                        Label(String(localized: "Multicolor Icon"), systemImage: "checkmark.circle")
                                    } else {
                                        Text(String(localized: "Multicolor Icon"))
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            currentDate = Date()
        }
        .onAppear {
            enforceLifetimeAccess()
        }
        .onChange(of: hasLifetimeAccess) { _, _ in
            enforceLifetimeAccess()
        }
        .sheet(isPresented: $showLifetimeStore) {
            NavigationStack {
                LifetimeStoreView()
            }
        }
    }
    
    // MARK: - Complication Selector
    private var complicationSelector: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ],
                    spacing: 8
                ) {
                    // Analog Clock
                    complicationOption(
                        type: .analogClock,
                        isSelected: showAnalogClock
                    ) {
                        AnalogClockView(
                            date: currentDate,
                            size: 64,
                            timeZone: TimeZone.current,
                            useMaterialBackground: false,
                            showScale: analogClockShowScale
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

                    // Photo
                    complicationOption(
                        type: .photo,
                        isSelected: showPhotoComplication
                    ) {
                        PhotoComplicationView(
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
                    
                    // Solar Curve
                    complicationOption(
                        type: .solarCurve,
                        isSelected: showSolarCurve
                    ) {
                        SolarCurve(
                            date: currentDate,
                            timeZone: TimeZone.current,
                            size: 64,
                            useMaterialBackground: false
                        )
                    }

                    // Daylight
                    complicationOption(
                        type: .daylight,
                        isSelected: showDaylight
                    ) {
                        DaylightIndicator(
                            date: currentDate,
                            timeZone: TimeZone.current,
                            size: 64,
                            useMaterialBackground: false
                        )
                    }

                    // Moon Azimuth
                    complicationOption(
                        type: .moonAzimuth,
                        isSelected: showMoonAzimuth
                    ) {
                        MoonAzimuthIndicator(
                            date: currentDate,
                            timeZone: TimeZone.current,
                            size: 64,
                            useMaterialBackground: false
                        )
                    }

                    // Moon & Sun Azimuth
                    complicationOption(
                        type: .moonSunAzimuth,
                        isSelected: showMoonSunAzimuth
                    ) {
                        MoonSunAzimuthIndicator(
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

                        complicationOption(
                            type: .temperatureIndicator,
                            isSelected: showTemperatureIndicator
                        ) {
                            TemperatureIndicator(
                                timeZone: TimeZone.current,
                                size: 64,
                                useMaterialBackground: false
                            )
                            .environmentObject(weatherManager)
                        }

                        complicationOption(
                            type: .uvIndex,
                            isSelected: showUVIndex
                        ) {
                            UVIndexIndicator(
                                timeZone: TimeZone.current,
                                size: 64,
                                useMaterialBackground: false
                            )
                            .environmentObject(weatherManager)
                        }

                        complicationOption(
                            type: .windDirection,
                            isSelected: showWindDirection
                        ) {
                            WindDirectionIndicator(
                                timeZone: TimeZone.current,
                                size: 64,
                                useMaterialBackground: false
                            )
                            .environmentObject(weatherManager)
                        }
                    }

                    if !showWeather {
                        weatherReminderCard
                            .gridCellColumns(2)
                    }
                }

                locationHint
            }
            .padding(.vertical, 4)
        }
    }

    private var locationHint: some View {
        HStack {
            Image(systemName: "location.fill")
                .font(.footnote.weight(.semibold))
            Text(String(localized: "Use your current location"))
                .font(.footnote.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .blendMode(.plusLighter)
        .padding(.top, 16)
    }

    private var weatherReminderCard: some View {
        Text(String(localized: "Enable Weather to discover more"))
            .font(.caption.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .frame(
                maxWidth: .infinity,
                minHeight: standardComplicationCellHeight,
                maxHeight: standardComplicationCellHeight
            )
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.25))
            )
    }

    private var standardComplicationCellHeight: CGFloat {
        let iconHeight: CGFloat = 64
        let iconTextSpacing: CGFloat = 10
        let verticalPadding: CGFloat = 24
        let captionLineHeight = UIFont.preferredFont(forTextStyle: .caption1).lineHeight
        return max(100, ceil(iconHeight + iconTextSpacing + captionLineHeight + verticalPadding))
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
            if isLocked(type) {
                showLifetimeStore = true
                return
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
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                            .blendMode(.plusLighter)
                    )
                
                Text(type.localizedName)
                    .font(.caption.weight(isSelected ? .semibold : .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.25))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? Color.white : .clear, lineWidth: 2)
            )
            .overlay(alignment: .topLeading) {
                if type == .photo {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .blendMode(.plusLighter)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .padding(8)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isLocked(type) {
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .blendMode(.plusLighter)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(), value: isSelected)
    }
}
