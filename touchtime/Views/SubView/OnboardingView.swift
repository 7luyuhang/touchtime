//
//  OnboardingView.swift
//  touchtime
//
//  Created on 2025.
//

import SwiftUI
import CoreHaptics
import VariableBlur
import Combine
import WeatherKit

struct DotMatrixOverlay: View {
    let rows = 30
    let columns = 20
    let dotSize: CGFloat = 2.5
    let spacing: CGFloat = 10
    
    @State private var animatedDots = Set<Int>()
    private let timer = Timer.publish(every: 0.75, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let horizontalSpacing = width / CGFloat(columns)
            let verticalSpacing = height / CGFloat(rows)
            
            ZStack {
                ForEach(0..<rows * columns, id: \.self) { index in
                    let row = index / columns
                    let column = index % columns
                    let x = CGFloat(column) * horizontalSpacing + horizontalSpacing / 2
                    let y = CGFloat(row) * verticalSpacing + verticalSpacing / 2
                    
                    Circle()
                        .fill(Color.white.opacity(animatedDots.contains(index) ? 0.25 : 0.05))
                        .frame(width: dotSize, height: dotSize)
                        .position(x: x, y: y)
                        .blendMode(.plusLighter)
                }
            }
            .onReceive(timer) { _ in
                animateRandomDotsStep()
            }
        }
    }
    
    private func animateRandomDotsStep() {
        withAnimation(.spring()) {
            // Remove some dots
            animatedDots = animatedDots.filter { _ in Bool.random() }
            // Add new random dots
            for _ in 0..<50 {
                animatedDots.insert(Int.random(in: 0..<(rows * columns)))
            }
        }
    }
}

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @ObservedObject var weatherManager: WeatherManager
    var isReviewing: Bool = false  // True when showing from Settings
    @State private var animateIcon = false
    @State private var animateText = false
    @State private var animateButton = false
    @State private var currentPage = 1  // 1 for intro, 2 for features, 3 for complication selection
    @State private var animateFeatures = false
    @State private var currentDate = Date()
    @State private var hapticEngine: CHHapticEngine?
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("additionalTimeDisplay") private var additionalTimeDisplay = "None"
    @AppStorage("showSkyDot") private var showSkyDot = true
    @AppStorage("showWeather") private var showWeather = false
    @AppStorage("useCelsius") private var useCelsius = true
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("showAnalogClock") private var showAnalogClock = false
    @AppStorage("showSunPosition") private var showSunPosition = false
    @AppStorage("showSunAzimuth") private var showSunAzimuth = false
    @AppStorage("showMoonAzimuth") private var showMoonAzimuth = false
    @AppStorage("showMoonSunAzimuth") private var showMoonSunAzimuth = false
    @AppStorage("showSunriseSunset") private var showSunriseSunset = false
    @AppStorage("showWeatherCondition") private var showWeatherCondition = false
    @AppStorage("showTemperatureIndicator") private var showTemperatureIndicator = false
    @AppStorage("showUVIndex") private var showUVIndex = false
    @AppStorage("showWindDirection") private var showWindDirection = false
    @AppStorage("showDaylight") private var showDaylight = false
    @AppStorage("showTimeOverlay") private var showTimeOverlay = false
    @AppStorage("showSolarCurve") private var showSolarCurve = false
    @AppStorage("analogClockShowScale") private var analogClockShowScale = false
    @AppStorage("hasLifetimeAccess") private var hasLifetimeAccess = false
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private enum OnboardingComplicationType: CaseIterable {
        case analogClock
        case sunElevation
        case sunAzimuth
        case moonAzimuth
        case moonSunAzimuth
        case sunriseSunset
        case weatherCondition
        case temperatureIndicator
        case uvIndex
        case windDirection
        case daylight
        case timeOverlay
        case solarCurve
        
        var localizedName: String {
            switch self {
            case .analogClock: return String(localized: "Analog Clock")
            case .sunElevation: return String(localized: "Sun Elevation")
            case .sunAzimuth: return String(localized: "Sun Azimuth")
            case .moonAzimuth: return String(localized: "Moon Azimuth")
            case .moonSunAzimuth: return String(localized: "Moon & Sun Azimuth")
            case .sunriseSunset: return String(localized: "Sunrise & Sunset")
            case .weatherCondition: return String(localized: "Weather Condition")
            case .temperatureIndicator: return String(localized: "Temperature Indicator")
            case .uvIndex: return String(localized: "UV Index")
            case .windDirection: return String(localized: "Wind Direction")
            case .daylight: return String(localized: "Daylight Curve")
            case .timeOverlay: return String(localized: "Time Overlay")
            case .solarCurve: return String(localized: "Solar Curve")
            }
        }
    }
    
    private var localCityName: String {
        guard let city = TimeZone.current.identifier.split(separator: "/").last else {
            return String(localized: "Local")
        }
        return city.replacingOccurrences(of: "_", with: " ")
    }

    private var weatherConditionForSky: WeatherCondition? {
        guard showWeather else { return nil }
        return weatherManager.weatherData[TimeZone.current.identifier]?.condition
    }

    private var canShowLifetimeWeatherComplications: Bool {
        showWeather && hasLifetimeAccess
    }

    private var canShowLifetimeComplications: Bool {
        hasLifetimeAccess
    }

    private var effectiveShowMoonAzimuth: Bool {
        canShowLifetimeComplications && showMoonAzimuth
    }

    private var effectiveShowMoonSunAzimuth: Bool {
        canShowLifetimeComplications && showMoonSunAzimuth
    }

    private var effectiveShowDaylight: Bool {
        canShowLifetimeComplications && showDaylight
    }

    private var effectiveShowTimeOverlay: Bool {
        canShowLifetimeComplications && showTimeOverlay
    }
    
    // Prepare haptic engine
    func prepareHaptics() {
        guard hapticEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Error creating haptic engine: \(error.localizedDescription)")
        }
    }
    
    // Play continuous subtle haptic pattern
    func playContinuousHaptic() {
        guard hapticEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        guard let engine = hapticEngine else { return }
        
        do {
            // Create a continuous subtle haptic pattern
            var events = [CHHapticEvent]()
            
            // Create multiple short, light taps in succession for a continuous feel
            for i in 0..<4 {
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                
                let event = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [intensity, sharpness],
                    relativeTime: TimeInterval(i) * 0.05 // Events 50ms apart
                )
                events.append(event)
            }
            
            // Create and play the pattern
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play haptic: \(error.localizedDescription)")
        }
    }
    
    private func completeOnboarding() {
        withAnimation(.spring()) {
            hasCompletedOnboarding = true
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
    }
    
    private func selectComplication(_ type: OnboardingComplicationType?) {
        withAnimation(.spring()) {
            showAnalogClock = type == .analogClock
            showSunPosition = type == .sunElevation
            showSunAzimuth = type == .sunAzimuth
            showMoonAzimuth = type == .moonAzimuth
            showMoonSunAzimuth = type == .moonSunAzimuth
            showSunriseSunset = type == .sunriseSunset
            showWeatherCondition = type == .weatherCondition
            showTemperatureIndicator = type == .temperatureIndicator
            showUVIndex = type == .uvIndex
            showWindDirection = type == .windDirection
            showDaylight = type == .daylight
            showTimeOverlay = type == .timeOverlay
            showSolarCurve = type == .solarCurve
        }
    }

    private func enforceLifetimeAccess() {
        guard !hasLifetimeAccess else { return }

        if showMoonAzimuth || showMoonSunAzimuth || showWeatherCondition || showTemperatureIndicator || showUVIndex || showWindDirection || showDaylight || showTimeOverlay {
            selectComplication(nil)
        }
    }
    
    private func formatTime(use24Hour: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mm"
        return formatter.string(from: currentDate)
    }
    
    private func formatDate() -> String {
        currentDate.formattedDate(style: dateStyle, timeZone: TimeZone.current)
    }
    
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
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            SkyColorGradient(
                date: currentDate,
                timeZoneIdentifier: TimeZone.current.identifier,
                weatherCondition: weatherConditionForSky
            )
            .linearGradient()
            .blendMode(.plusLighter)
            .ignoresSafeArea()
            .blur(radius: 200)
            .opacity(0.35)
            
            // Dot Matrix Animation
            DotMatrixOverlay()
                .ignoresSafeArea()
                .blendMode(.plusLighter)
                .opacity(0.75)
                .opacity(animateIcon ? 1.0 : 0.0)
            
            // VariableBlur
            GeometryReader { geom in
                VariableBlurView(maxBlurRadius: 10, direction: .blurredBottomClearTop)
                    .frame(height: geom.safeAreaInsets.bottom + 100)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()
            }
            
            VStack {
                Spacer()
                
                // Main Content Area - switches between intro, features and complication selection
                if currentPage == 1 {
                    // Intro Page
                    VStack (spacing: 32) {
                        // App Icon
                        ZStack {
                            Image("TouchTimeAppIcon") // Background light
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .blur(radius: 100)
                                .blendMode(.plusLighter)
                                .scaleEffect(animateIcon ? 1.0 : 0.85)
                                .opacity(animateIcon ? 1.0 : 0.0)
                                .offset(y: animateText ? 0 : 50)
                                .animation(
                                    .bouncy(duration: 2.5), value: animateIcon
                                )
                            Image("TouchTimeAppIcon")
                                .resizable()
                                .scaledToFit()
                                .glassEffect(.clear.interactive(), in:
                                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                )
                                .frame(width: 100, height: 100)
                                .blur(radius: animateIcon ? 0 : 25)
                                .scaleEffect(animateIcon ? 1.0 : 0.5)
                                .opacity(animateIcon ? 1.0 : 0.0)
                                .offset(y: animateText ? 0 : 50)
                                .animation(
                                    .bouncy(duration: 1.0), value: animateIcon
                                )
                                .onTapGesture {
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                        impactFeedback.impactOccurred()
                                    }
                                }
                        }
                        
                        VStack(spacing: 8) {
                            // App Name
                            Text("Touch Time")
                                .font(.system(size: 24).weight(.semibold))
                                .blur(radius: animateText ? 0 : 10)
                                .opacity(animateText ? 1.0 : 0.0)
                                .offset(y: animateText ? 0 : 75)
                                .animation(
                                    .smooth(duration: 1.0),value: animateText
                                )
                            // Description
                            Text("The world time flows within the delicate sky")
                                .foregroundStyle(.secondary)
                                .blendMode(.plusLighter)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                .blur(radius: animateText ? 0 : 10)
                                .opacity(animateText ? 1.0 : 0.0)
                                .offset(y: animateText ? 0 : 75)
                                .animation(
                                    .smooth(duration: 1.0),value: animateText
                                )
                        }
                    }
                    .transition(.blurReplace())
                } else if currentPage == 2 {
                    // Features Page
                    VStack(spacing: 16) {
                        FeatureRow(
                            icon: "clock",
                            title: String(localized: "450+ cities worldwide"),
                            isAnimated: animateFeatures
                        )
                        
                        FeatureRow(
                            icon: "hand.draw.fill",
                            title: String(localized: "Swipe to shift time zones and see the world in sync"),
                            isAnimated: animateFeatures
                        )
                        
                        FeatureRow(
                            icon: "globe.americas.fill",
                            title: String(localized: "Explore time through an immersive globe view"),
                            isAnimated: animateFeatures
                        )
                        
                        FeatureRow(
                            icon: "calendar",
                            title: String(localized: "Event plan across zones, effortlessly"),
                            isAnimated: animateFeatures
                        )

                        FeatureRow(
                            icon: "alarm",
                            title: String(localized: "Smarter alarms and timers"),
                            isAnimated: animateFeatures
                        )
                        
                        Text("and much more...", comment: "Onboarding feature list ending")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .blendMode(.plusLighter)
                            .padding(.top, 8)
                        
                    }
                    .transition(.blurReplace())
                    .padding(.horizontal, 32)
                    
                } else {
                    
                    // Complication Selection
                        VStack(spacing: 24) {
                            
                            Text("Complications")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            
                            Spacer()
                            
                            Text("Choose a complication to display more")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .blendMode(.plusLighter)
                                .padding(.horizontal, 32)
                            
                            // City Card + Complications
                            ZStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        if showSkyDot && additionalTimeDisplay == "None" {
                                            SkyDotView(
                                                date: currentDate,
                                                timeZoneIdentifier: TimeZone.current.identifier,
                                                weatherCondition: weatherConditionForSky
                                            )
                                            .overlay(
                                                Capsule(style: .continuous)
                                                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                                                    .blendMode(.plusLighter)
                                            )
                                        }
                                        
                                        if additionalTimeDisplay != "None" {
                                            Text(additionalTimeText())
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .blendMode(.plusLighter)
                                        }
                                        
                                        Spacer()
                                        
                                        if showWeather {
                                            WeatherView(
                                                weather: weatherManager.currentWeather,
                                                useCelsius: useCelsius
                                            )
                                        }
                                        
                                        Text(formatDate())
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .blendMode(.plusLighter)
                                    }
                                    
                                    HStack(alignment: .lastTextBaseline) {
                                        Text(localCityName)
                                            .font(.headline)
                                        
                                        Spacer()
                                        
                                        Text(formatTime(use24Hour: use24HourFormat))
                                            .font(.system(size: 36))
                                            .fontWeight(.light)
                                            .fontDesign(.rounded)
                                            .monospacedDigit()
                                    }
                                }
                                .padding()
                                .padding(.bottom, -4)
                                
                                // Complications
                                if showAnalogClock {
                                    AnalogClockView(
                                        date: currentDate,
                                        size: 64,
                                        timeZone: TimeZone.current,
                                        useMaterialBackground: true,
                                        showScale: analogClockShowScale
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                                            .blendMode(.plusLighter)
                                    )
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
                                }

                                if showSunriseSunset {
                                    SunriseSunsetIndicator(
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
                                }
                                
                                if effectiveShowDaylight {
                                    DaylightIndicator(
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
                                }

                                if effectiveShowTimeOverlay {
                                    TimeOverlayIndicator(
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
                                }
                                
                                if showSolarCurve {
                                    SolarCurve(
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
                                }

                                if effectiveShowMoonAzimuth {
                                    MoonAzimuthIndicator(
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
                                }

                                if effectiveShowMoonSunAzimuth {
                                    MoonSunAzimuthIndicator(
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
                                }
                                
                                if canShowLifetimeWeatherComplications && showWeatherCondition {
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
                                }

                                if canShowLifetimeWeatherComplications && showTemperatureIndicator {
                                    TemperatureIndicator(
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
                                }

                                if canShowLifetimeWeatherComplications && showUVIndex {
                                    UVIndexIndicator(
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
                                }

                                if canShowLifetimeWeatherComplications && showWindDirection {
                                    WindDirectionIndicator(
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
                                }
                            }
                            .background(
                                showSkyDot ?
                                ZStack {
                                    Color.black
                                    SkyBackgroundView(
                                        date: currentDate,
                                        timeZoneIdentifier: TimeZone.current.identifier,
                                        weatherCondition: weatherConditionForSky
                                    )
                                } : nil
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .padding(.horizontal, 16)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 16) {
                                    complicationOption(type: .analogClock, isSelected: showAnalogClock) {
                                        AnalogClockView(
                                            date: currentDate,
                                            size: 64,
                                            timeZone: TimeZone.current,
                                            useMaterialBackground: false,
                                            showScale: analogClockShowScale
                                        )
                                    }
                                    
                                    complicationOption(type: .sunElevation, isSelected: showSunPosition) {
                                        SunPositionIndicator(
                                            date: currentDate,
                                            timeZone: TimeZone.current,
                                            size: 64,
                                            useMaterialBackground: false
                                        )
                                    }
                                    
                                    complicationOption(type: .sunAzimuth, isSelected: showSunAzimuth) {
                                        SunAzimuthIndicator(
                                            date: currentDate,
                                            timeZone: TimeZone.current,
                                            size: 64,
                                            useMaterialBackground: false
                                        )
                                    }

                                    complicationOption(type: .sunriseSunset, isSelected: showSunriseSunset) {
                                        SunriseSunsetIndicator(
                                            date: currentDate,
                                            timeZone: TimeZone.current,
                                            size: 64,
                                            useMaterialBackground: false
                                        )
                                    }
                                    
                                    complicationOption(type: .solarCurve, isSelected: showSolarCurve) {
                                        SolarCurve(
                                            date: currentDate,
                                            timeZone: TimeZone.current,
                                            size: 64,
                                            useMaterialBackground: false
                                        )
                                    }

                                    if canShowLifetimeComplications {
                                        complicationOption(type: .timeOverlay, isSelected: effectiveShowTimeOverlay) {
                                            TimeOverlayIndicator(
                                                date: currentDate,
                                                timeZone: TimeZone.current,
                                                size: 64,
                                                useMaterialBackground: false
                                            )
                                        }
                                    }

                                    if canShowLifetimeComplications {
                                        complicationOption(type: .daylight, isSelected: effectiveShowDaylight) {
                                            DaylightIndicator(
                                                date: currentDate,
                                                timeZone: TimeZone.current,
                                                size: 64,
                                                useMaterialBackground: false
                                            )
                                        }
                                    }

                                    if canShowLifetimeComplications {
                                        complicationOption(type: .moonAzimuth, isSelected: showMoonAzimuth) {
                                            MoonAzimuthIndicator(
                                                date: currentDate,
                                                timeZone: TimeZone.current,
                                                size: 64,
                                                useMaterialBackground: false
                                            )
                                        }
                                    }

                                    if canShowLifetimeComplications {
                                        complicationOption(type: .moonSunAzimuth, isSelected: showMoonSunAzimuth) {
                                            MoonSunAzimuthIndicator(
                                                date: currentDate,
                                                timeZone: TimeZone.current,
                                                size: 64,
                                                useMaterialBackground: false
                                            )
                                        }
                                    }
                                    
                                    if canShowLifetimeWeatherComplications {
                                        complicationOption(type: .weatherCondition, isSelected: showWeatherCondition) {
                                            WeatherConditionView(
                                                timeZone: TimeZone.current,
                                                size: 64,
                                                useMaterialBackground: false
                                            )
                                            .environmentObject(weatherManager)
                                        }

                                        complicationOption(type: .temperatureIndicator, isSelected: showTemperatureIndicator) {
                                            TemperatureIndicator(
                                                timeZone: TimeZone.current,
                                                size: 64,
                                                useMaterialBackground: false
                                            )
                                            .environmentObject(weatherManager)
                                        }

                                        complicationOption(type: .uvIndex, isSelected: showUVIndex) {
                                            UVIndexIndicator(
                                                timeZone: TimeZone.current,
                                                size: 64,
                                                useMaterialBackground: false
                                            )
                                            .environmentObject(weatherManager)
                                        }

                                        complicationOption(type: .windDirection, isSelected: showWindDirection) {
                                            WindDirectionIndicator(
                                                timeZone: TimeZone.current,
                                                size: 64,
                                                useMaterialBackground: false
                                            )
                                            .environmentObject(weatherManager)
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 8)
                            }
                            
                            Spacer()
                            
                            // Use your current location
                            HStack {
                                Image(systemName: "location.fill")
                                    .font(.footnote.weight(.semibold))
                                Text(String(localized: "Use your current location"))
                                    .font(.footnote.weight(.medium))
                            }
                            .foregroundStyle(.secondary)
                            .blendMode(.plusLighter)
                            .padding(.bottom, 16)
                            
                        }
                        .transition(.blurReplace())
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    // Continue / Get Started Button
                    Button(action: {
                        if currentPage == 1 {
                            playContinuousHaptic()
                        } else if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                            impactFeedback.impactOccurred()
                        }
                        
                        if currentPage == 1 {
                            withAnimation(.spring()) {
                                currentPage = 2
                                animateFeatures = true
                            }
                        } else if currentPage == 2 {
                            withAnimation(.spring()) {
                                currentPage = 3
                            }
                        } else {
                            completeOnboarding()
                        }
                    }) {
                        Text(currentPage == 3 ? "Get Started" : "Continue")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                Capsule()
                                    .fill(currentPage == 3 ? Color.blue.opacity(0.85) : Color.black.opacity(0.25))
                            )
                            .glassEffect(.clear.interactive())
                    }
                    
                    if currentPage == 2 {
                        VStack(spacing: 4) {
                            Text("By continuing, you agree to our")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 4) {
                                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .buttonStyle(.plain)
                                
                                Text("and")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Link("Privacy Policy", destination: URL(string: "https://www.handstime.app/privacy")!)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .buttonStyle(.plain)
                            }
                        }
                        .blendMode(.plusLighter)
                        .multilineTextAlignment(.center)
                        .transition(.blurReplace())
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, currentPage == 2 ? 0 : 16)
                .scaleEffect(animateButton ? 1.0 : 0.85)
                .opacity(animateButton ? 1.0 : 0.0)
                .animation(
                    .spring(duration: 1.0), value: animateButton
                )
  
            }
        }
        .onAppear {
            prepareHaptics()
            enforceLifetimeAccess()
            
            animateIcon = true
            animateText = true
            animateButton = true
            
            Task {
                guard showWeather else { return }
                await weatherManager.getWeather(for: TimeZone.current.identifier)
            }
        }
        .onReceive(timer) { _ in
            currentDate = Date()
        }
        .onChange(of: showWeather) { _, newValue in
            if !newValue {
                showWeatherCondition = false
                showTemperatureIndicator = false
                showUVIndex = false
                showWindDirection = false
            }
        }
        .onChange(of: hasLifetimeAccess) { _, _ in
            enforceLifetimeAccess()
        }
        .onDisappear {
            hapticEngine?.stop()
            hapticEngine = nil
        }
    }
    
    private func complicationOption<Content: View>(
        type: OnboardingComplicationType,
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
                                isSelected ? Color.white : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 0.5
                            )
                    )
                
                Text(type.localizedName)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
        .animation(.spring(), value: isSelected)
    }
}

// Feature Row Component
struct FeatureRow: View {
    let icon: String
    let title: String
    let isAnimated: Bool
    @State private var wiggleTrigger = 0
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 22).weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .blendMode(.plusLighter)
                .frame(width: 40, height: 40)
                .symbolEffect(
                    .wiggle.clockwise.byLayer,
                    options: .nonRepeating,
                    value: wiggleTrigger
                )
            
            // Title
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .glassEffect(.clear.interactive().tint(.black.opacity(0.25)), in: Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
        .onTapGesture {
            wiggleTrigger += 1
        }
    }
}

#Preview {
    OnboardingView(
        hasCompletedOnboarding: .constant(false),
        weatherManager: WeatherManager()
    )
        .preferredColorScheme(.dark)
}
