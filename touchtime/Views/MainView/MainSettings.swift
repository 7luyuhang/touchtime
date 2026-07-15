//
//  SettingsView.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import SwiftUI
import Combine
import EventKit
import StoreKit
import WeatherKit

struct SettingsView: View {
    @Binding var worldClocks: [WorldClock]
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("additionalTimeDisplay") private var additionalTimeDisplay = "None"
    @AppStorage("showLocalTime") private var showLocalTime = true
    @AppStorage("showSkyDot") private var showSkyDot = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("availableTimeEnabled") private var availableTimeEnabled = false
    @AppStorage("availableStartTime") private var availableStartTime = "09:00"
    @AppStorage("availableEndTime") private var availableEndTime = "17:00"
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("showWeather") private var showWeather = false
    @AppStorage("useCelsius") private var useCelsius = true
    @AppStorage("showAnalogClock") private var showAnalogClock = false
    @AppStorage("analogClockShowScale") private var analogClockShowScale = false
    @AppStorage("showSunPosition") private var showSunPosition = false
    @AppStorage("showWeatherCondition") private var showWeatherCondition = false
    @AppStorage("showTemperatureIndicator") private var showTemperatureIndicator = false
    @AppStorage("showUVIndex") private var showUVIndex = false
    @AppStorage("showWindDirection") private var showWindDirection = false
    @AppStorage("showSunAzimuth") private var showSunAzimuth = false
    @AppStorage("showMoonAzimuth") private var showMoonAzimuth = false
    @AppStorage("showMoonSunAzimuth") private var showMoonSunAzimuth = false
    @AppStorage("showSunriseSunset") private var showSunriseSunset = false
    @AppStorage("showDaylight") private var showDaylight = false
    @AppStorage("showTimeOverlay") private var showTimeOverlay = false
    @AppStorage("showSolarCurve") private var showSolarCurve = false
    @AppStorage("showArcIndicator") private var showArcIndicator = true // Default turn on
    @AppStorage("showSunriseSunsetLines") private var showSunriseSunsetLines = false
    @AppStorage("showGoldenHour") private var showGoldenHour = false
    @AppStorage("showMinuteHand") private var showMinuteHand = true
    @AppStorage("showUTCHand") private var showUTCHand = true
    @AppStorage("hasLifetimeAccess") private var hasLifetimeAccess = false
    @AppStorage("hasSeenWidgetIntro") private var hasSeenWidgetIntro = false
    @AppStorage("hourlyNotificationEnabled") private var hourlyNotificationEnabled = false
    @AppStorage(HourlyNotificationManager.timeWindowEnabledKey) private var chimeTimeWindowEnabled = false
    @AppStorage(HourlyNotificationManager.startTimeKey) private var chimeStartTime = HourlyNotificationManager.defaultStartTime
    @AppStorage(HourlyNotificationManager.endTimeKey) private var chimeEndTime = HourlyNotificationManager.defaultEndTime
    @State private var hourlyNotificationCityIds: [UUID] = HourlyNotificationManager.loadSelectedCityIds()
    @State private var showNotificationPermissionAlert = false
    @State private var currentDate = Date()
    @State private var showLifetimeStore = false
    @State private var showSupportLove = false
    @State private var showComplicationsSheet = false
    @State private var showWidgetSheet = false
    @State private var touchTimeIconShakes = 0
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var weatherManager: WeatherManager
    
    // Timer for updating the preview
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let relativeDateStyle = "Relative"
    private static let withWeekdayDateStyle = "With Weekday"
    private static let dateOnlyDateStyle = "Date Only"
    private static let legacyAbsoluteDateStyle = "Absolute"

    private static let preview24HourFormatter: DateFormatter = makeFormatter("HH:mm")
    private static let preview12HourFormatter: DateFormatter = makeFormatter("h:mm")
    private static let settingInputTimeFormatter: DateFormatter = makeFormatter("HH:mm")
    private static let settingDisplayTimeFormatter: DateFormatter = {
        let formatter = makeFormatter("h:mm a")
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter
    }()

    private static func makeFormatter(_ dateFormat: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = dateFormat
        return formatter
    }

    private enum PreviewComplication: String {
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
            case .analogClock:
                return String(localized: "Analog Clock")
            case .sunElevation:
                return String(localized: "Sun Elevation")
            case .sunAzimuth:
                return String(localized: "Sun Azimuth")
            case .moonAzimuth:
                return String(localized: "Moon Azimuth")
            case .moonSunAzimuth:
                return String(localized: "Moon & Sun Azimuth")
            case .sunriseSunset:
                return String(localized: "Sunrise & Sunset")
            case .weatherCondition:
                return String(localized: "Weather Condition")
            case .temperatureIndicator:
                return String(localized: "Temperature Indicator")
            case .uvIndex:
                return String(localized: "UV Index")
            case .windDirection:
                return String(localized: "Wind Direction")
            case .daylight:
                return String(localized: "Daylight Curve")
            case .timeOverlay:
                return String(localized: "Time Overlay")
            case .solarCurve:
                return String(localized: "Solar Curve")
            }
        }
    }
    
    // Format time for preview (time part only)
    func formatTime(use24Hour: Bool) -> String {
        let formatter = use24Hour ? Self.preview24HourFormatter : Self.preview12HourFormatter
        formatter.timeZone = TimeZone.current
        return formatter.string(from: currentDate)
    }
    
    // Format date for preview
    func formatDate() -> String {
        return currentDate.formattedDate(style: dateStyle, timeZone: TimeZone.current)
    }
    
    // Calculate additional time display
    func additionalTimeText() -> String {
        switch additionalTimeDisplay {
        case "Time Difference":
            // Since we're showing local time, there's no time difference
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
    
    private var selectedPreviewComplication: PreviewComplication? {
        if showAnalogClock {
            return .analogClock
        } else if showSunPosition {
            return .sunElevation
        } else if showSunAzimuth {
            return .sunAzimuth
        } else if effectiveShowMoonAzimuth {
            return .moonAzimuth
        } else if effectiveShowMoonSunAzimuth {
            return .moonSunAzimuth
        } else if showSunriseSunset {
            return .sunriseSunset
        } else if effectiveShowWeatherCondition {
            return .weatherCondition
        } else if effectiveShowTemperatureIndicator {
            return .temperatureIndicator
        } else if effectiveShowUVIndex {
            return .uvIndex
        } else if effectiveShowWindDirection {
            return .windDirection
        } else if effectiveShowDaylight {
            return .daylight
        } else if effectiveShowTimeOverlay {
            return .timeOverlay
        } else if showSolarCurve {
            return .solarCurve
        }
        return nil
    }

    private var weatherConditionForSky: WeatherCondition? {
        guard showWeather else { return nil }
        return weatherManager.weatherData[TimeZone.current.identifier]?.condition
    }

    private var effectiveShowWeatherCondition: Bool {
        showWeather && showWeatherCondition
    }

    private var effectiveShowTemperatureIndicator: Bool {
        hasLifetimeAccess && showWeather && showTemperatureIndicator
    }

    private var effectiveShowUVIndex: Bool {
        hasLifetimeAccess && showWeather && showUVIndex
    }

    private var effectiveShowWindDirection: Bool {
        hasLifetimeAccess && showWeather && showWindDirection
    }

    private var effectiveShowMoonAzimuth: Bool {
        hasLifetimeAccess && showMoonAzimuth
    }

    private var effectiveShowMoonSunAzimuth: Bool {
        hasLifetimeAccess && showMoonSunAzimuth
    }

    private var effectiveShowDaylight: Bool {
        hasLifetimeAccess && showDaylight
    }

    private var effectiveShowTimeOverlay: Bool {
        hasLifetimeAccess && showTimeOverlay && availableTimeEnabled
    }

    private func normalizeLegacyDateStyle() {
        if dateStyle == Self.legacyAbsoluteDateStyle {
            dateStyle = Self.withWeekdayDateStyle
        }
    }

    private func normalizeDateStyleForWeather() {
        if showWeather && dateStyle == Self.withWeekdayDateStyle {
            dateStyle = Self.relativeDateStyle
        }
    }

    private var goldenHourBinding: Binding<Bool> {
        Binding(
            get: { hasLifetimeAccess && showGoldenHour },
            set: { newValue in
                if newValue {
                    if hasLifetimeAccess {
                        showGoldenHour = true
                    } else {
                        showLifetimeStore = true
                    }
                } else {
                    showGoldenHour = false
                }
            }
        )
    }

    private var sunriseSunsetLinesBinding: Binding<Bool> {
        Binding(
            get: { hasLifetimeAccess && showSunriseSunsetLines },
            set: { newValue in
                if newValue {
                    if hasLifetimeAccess {
                        showSunriseSunsetLines = true
                    } else {
                        showLifetimeStore = true
                    }
                } else {
                    showSunriseSunsetLines = false
                }
            }
        )
    }

    private var hourlyNotificationBinding: Binding<Bool> {
        Binding(
            get: { hourlyNotificationEnabled },
            set: { newValue in
                if newValue {
                    Task {
                        let granted = await HourlyNotificationManager.shared.requestAuthorization()
                        await MainActor.run {
                            if granted {
                                hourlyNotificationEnabled = true
                                HourlyNotificationManager.shared.reschedule()
                            } else {
                                hourlyNotificationEnabled = false
                                showNotificationPermissionAlert = true
                            }
                        }
                    }
                } else {
                    hourlyNotificationEnabled = false
                    HourlyNotificationManager.shared.cancelAll()
                }
            }
        )
    }

    private var hourlyNotificationCitySummary: String {
        let selected = worldClocks.filter { hourlyNotificationCityIds.contains($0.id) }
        switch selected.count {
        case 0:
            return String(localized: "None")
        case 1:
            return selected[0].localizedCityName
        default:
            return String(format: String(localized: "%d Cities"), selected.count)
        }
    }

    private var minuteHandBinding: Binding<Bool> {
        Binding(
            get: { hasLifetimeAccess && showMinuteHand },
            set: { newValue in
                if newValue {
                    if hasLifetimeAccess {
                        showMinuteHand = true
                    } else {
                        showLifetimeStore = true
                    }
                } else {
                    showMinuteHand = false
                }
            }
        )
    }

    @ViewBuilder
    private func previewComplication<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                    .blendMode(.plusLighter)
            )
            .transition(.identity)
    }

    @ViewBuilder
    private func previewComplicationContent(for complication: PreviewComplication) -> some View {
        switch complication {
        case .analogClock:
            AnalogClockView(
                date: currentDate,
                size: 64,
                timeZone: TimeZone.current,
                useMaterialBackground: true,
                showScale: analogClockShowScale
            )
        case .sunElevation:
            SunPositionIndicator(
                date: currentDate,
                timeZone: TimeZone.current,
                size: 64,
                useMaterialBackground: true
            )
        case .sunAzimuth:
            SunAzimuthIndicator(
                date: currentDate,
                timeZone: TimeZone.current,
                size: 64,
                useMaterialBackground: true
            )
        case .moonAzimuth:
            MoonAzimuthIndicator(
                date: currentDate,
                timeZone: TimeZone.current,
                size: 64,
                useMaterialBackground: true
            )
        case .moonSunAzimuth:
            MoonSunAzimuthIndicator(
                date: currentDate,
                timeZone: TimeZone.current,
                size: 64,
                useMaterialBackground: true
            )
        case .sunriseSunset:
            SunriseSunsetIndicator(
                date: currentDate,
                timeZone: TimeZone.current,
                size: 64,
                useMaterialBackground: true
            )
        case .weatherCondition:
            WeatherConditionView(
                timeZone: TimeZone.current,
                size: 64,
                useMaterialBackground: true
            )
            .environmentObject(weatherManager)
        case .temperatureIndicator:
            TemperatureIndicator(
                timeZone: TimeZone.current,
                size: 64,
                useMaterialBackground: true
            )
            .environmentObject(weatherManager)
        case .uvIndex:
            UVIndexIndicator(
                timeZone: TimeZone.current,
                size: 64,
                useMaterialBackground: true
            )
            .environmentObject(weatherManager)
        case .windDirection:
            WindDirectionIndicator(
                timeZone: TimeZone.current,
                size: 64,
                useMaterialBackground: true
            )
            .environmentObject(weatherManager)
        case .daylight:
            DaylightIndicator(
                date: currentDate,
                timeZone: TimeZone.current,
                size: 64,
                useMaterialBackground: true
            )
        case .timeOverlay:
            TimeOverlayIndicator(
                date: currentDate,
                timeZone: TimeZone.current,
                size: 64,
                useMaterialBackground: true
            )
        case .solarCurve:
            SolarCurve(
                date: currentDate,
                timeZone: TimeZone.current,
                size: 64,
                useMaterialBackground: true
            )
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Support & Love
                Section {
                    Button(action: {
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
                        showSupportLove = true
                    }) {
                        HStack(spacing: 12) {
                            SupportLoveIcon()
                            
                            VStack (alignment: .leading) {
                                Text("Support & Love")
                                    .font(.headline)
                                Text("Your support means the world")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .blendMode(.plusLighter)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .glassEffect(.regular.interactive().tint(.pink), in: .capsule(style: .continuous))
                        }
                    }
                    .foregroundStyle(.primary)
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        ZStack {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                            //                          .fill(Color.black.opacity(0.25))
                                .fill(LinearGradient(
                                    colors: [
                                        .pink,
                                        .red
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ).opacity(0.15))
                            //                            .fill(
                            //                                SkyColorGradient(
                            //                                    date: currentDate,
                            //                                    timeZoneIdentifier: TimeZone.current.identifier
                            //                                ).linearGradient(opacity: 0.50)
                            //                            )
                                .glassEffect(.clear.interactive(),
                                             in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                        }
                    )
                }
                
                // General Section
                Section(header: Text("General"), footer:
                    HStack(spacing: 4) {
                        Text("Explore more widgets on")
                            .foregroundColor(.secondary)

                        Button(action: {
                            if hapticEnabled {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                            // Open Hands Time if installed, otherwise its App Store page
                            if let handsTimeURL = URL(string: "handstime://"),
                               UIApplication.shared.canOpenURL(handsTimeURL) {
                                UIApplication.shared.open(handsTimeURL)
                            } else if let appStoreURL = URL(string: "https://apps.apple.com/us/app/hands-time-minimalist-widget/id6462440720") {
                                UIApplication.shared.open(appStoreURL)
                            }
                        }) {
                            Text(verbatim: "Hands Time")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.plain)

                        Text(".")
                            .foregroundColor(.secondary)
                            .padding(.leading, -4)
                    }
                    .font(.footnote)
                    .foregroundStyle(.primary)
                ) {
                    
                    Button(action: {
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
                        hasSeenWidgetIntro = true
                        showWidgetSheet = true
                    }) {
                        HStack {
                            HStack(spacing: 12) {
                                SystemIconImage(systemName: "widget.small",  topColor: .gray, bottomColor: .gray, style: .plain)
                                Text("Widgets")
                            }
                            .layoutPriority(1)
                            Spacer(minLength: 8)
                            if !hasSeenWidgetIntro {
                                Circle()
                                    .fill(.red)
                                    .glassEffect(.regular.interactive())
                                    .frame(width: 8, height: 8)
                                    .padding(.trailing, 4)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    
                }
                
                // Temperature/Weather Section
                Section {
                    TouchTimeToggle(isOn: Binding(
                        get: { showWeather },
                        set: { newValue in
                            showWeather = newValue
                            if newValue {
                                if dateStyle == Self.withWeekdayDateStyle {
                                    dateStyle = Self.relativeDateStyle
                                }
                            } else {
                                showWeatherCondition = false
                                showTemperatureIndicator = false
                                showUVIndex = false
                                showWindDirection = false
                            }
                        }
                    )) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "sun.max.fill", topColor: .gray, bottomColor: .gray, style: .plain)
                            Text("Weather")
                        }
                    }
                    
                    // Temperature Unit Picker - only show when weather is enabled
                    if showWeather {
                        Picker(selection: $useCelsius) {
                            Text("Celsius").tag(true)
                            Text("Fahrenheit").tag(false)
                        } label: {
                            Text("Temperature Units")
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                    }} footer: {
                        Text("Data provided by  Weather.")
                    }
                
                
                // Digital Time Section
                Section(header: Text("Display")) {
                    // Preview Section
                    VStack(alignment: .center, spacing: 10) {
                        
                        TimePreviewCard(
                            date: currentDate,
                            timeZoneIdentifier: TimeZone.current.identifier,
                            weatherCondition: weatherConditionForSky,
                            showSkyDot: showSkyDot,
                            showSkyDotBadge: false,
                            additionalTimeDisplay: additionalTimeDisplay,
                            additionalTimeText: additionalTimeText(),
                            showWeather: showWeather,
                            weather: weatherManager.currentWeather,
                            useCelsius: useCelsius,
                            dateText: formatDate(),
                            cityText: String(localized: "City"),
                            timeText: formatTime(use24Hour: use24HourFormat)
                        ) {
                            if let complication = selectedPreviewComplication {
                                previewComplication {
                                    previewComplicationContent(for: complication)
                                }
                            }
                        }
                        .animation(.spring(), value: showSkyDot)
                        .animation(.spring(), value: selectedPreviewComplication?.rawValue)
                        .id("\(showSkyDot)-\(dateStyle)-\(selectedPreviewComplication?.rawValue ?? "none")")
                        .onTapGesture {
                            if hapticEnabled {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                        }
                        
                        // Preview Text
                        Text("Preview")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, -16)
                    }
                    .listRowSeparator(.hidden)
                    
                    
                    // Options in Settings
                    TouchTimeToggle(isOn: $showSkyDot) {
                        HStack(spacing: 12) {
                            // When enabled, tint the icon with the live SkyColorGradient;
                            // when off, fall back to gray so it matches the other Settings icons.
                            let gradient = SkyColorGradient(
                                date: currentDate,
                                timeZoneIdentifier: TimeZone.current.identifier,
                                weatherCondition: weatherConditionForSky
                            )
                            let colors = gradient.colors
                            SystemIconImage(
                                systemName: "cloud.fill",
                                topColor: showSkyDot ? (colors.first ?? .blue) : .gray,
                                bottomColor: showSkyDot ? (colors.last ?? .white) : .gray,
                                style: .plain
                            )
                            Text("Sky Colour")
                        }
                    }
                    
                    // 24 Hours Format
                    TouchTimeToggle(isOn: $use24HourFormat) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "24.circle.fill", topColor: .gray, bottomColor: .gray, style: .plain)
                            Text("24-Hour Format")
                        }
                    }
                    
                    
                    // Additional Time
                    Picker(selection: $additionalTimeDisplay) {
                        Text("Time Shift")
                            .tag("Time Difference")
                        Text("UTC")
                            .tag("UTC")
                        Text("Weekday")
                            .tag("Weekday")
                        Divider()
                        Text("None")
                            .tag("None")
                    } label: {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "plusminus", topColor: .gray, bottomColor: .gray, style: .plain)
                            Text("Additional Time")
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    
                    
                    // Date PickeDr
                    Picker(selection: $dateStyle) {
                        Text("Relative")
                            .tag(Self.relativeDateStyle)
                        
                        // The weekday-laden date competes with Weather for trailing space, so hide it when Weather is on
                        if !showWeather {
                            Text("With Weekday")
                                .tag(Self.withWeekdayDateStyle)
                        }

                        Text("Date Only")
                            .tag(Self.dateOnlyDateStyle)
                    } label: {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "hourglass.bottomhalf.filled", topColor: .gray, bottomColor: .gray, style: .plain)
                            Text("Date Style")
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    
                    
                    // Complications
                    Button(action: {
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        showComplicationsSheet = true
                    }) {
                        HStack {
                            HStack(spacing: 12) {
                                SystemIconImage(systemName: "watch.analog", topColor: .gray, bottomColor: .gray, style: .plain)
                                Text("Complications")
                            }
                            .layoutPriority(1)
                            Spacer(minLength: 8)
                            Text(selectedPreviewComplication?.localizedName ?? String(localized: "None"))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    
                }
                
                // Analog Time Section
                Section(header: Text("Clock")) {
                    TouchTimeToggle(isOn: goldenHourBinding) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "angle", topColor: .gray, bottomColor: .gray, style: .plain)
                            Text(String(localized: "Golden Hour Lines"))
                            Spacer()
                            if !hasLifetimeAccess {
                                Image(systemName: "lock.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    
                    TouchTimeToggle(isOn: sunriseSunsetLinesBinding) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "circle.and.line.horizontal", topColor: .gray, bottomColor: .gray, style: .plain)
                            Text(String(localized: "Sunrise & Sunset Lines"))
                            Spacer()
                            if !hasLifetimeAccess {
                                Image(systemName: "lock.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    TouchTimeToggle(isOn: minuteHandBinding) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "hand.raised.fill", topColor: .gray, bottomColor: .gray, style: .plain)
                            Text(String(localized: "Minute Hand"))
                            Spacer()
                            if !hasLifetimeAccess {
                                Image(systemName: "lock.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    if additionalTimeDisplay == "UTC" {
                        TouchTimeToggle(isOn: $showUTCHand) {
                            HStack(spacing: 12) {
                                SystemIconImage(systemName: "line.diagonal", topColor: .gray, bottomColor: .gray, style: .plain)
                                Text(String(localized: "UTC Hand"))
                            }
                        }
                    }
                    
                    TouchTimeToggle(isOn: $showArcIndicator) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "circle", topColor: .gray, bottomColor: .gray, style: .plain)
                            Text("Arc Indicator")
                        }
                    }
                }
                
                // Hourly Notification
                Section {
                    TouchTimeToggle(isOn: hourlyNotificationBinding) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "bell.badge", topColor: .gray, bottomColor: .gray, style: .plain)
                            Text("Hourly Chime")
                        }
                    }
                    
                    if hourlyNotificationEnabled {
                        NavigationLink(destination: HourlyNotificationCityPicker(
                            worldClocks: worldClocks,
                            selectedCityIds: $hourlyNotificationCityIds,
                            weatherCondition: weatherConditionForSky
                        )) {
                            HStack {
                                Text("City Selection")
                                Spacer(minLength: 8)
                                Text(hourlyNotificationCitySummary)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                } header: {
                    Text("Notification")
                } footer: {
                    if hourlyNotificationEnabled && chimeTimeWindowEnabled {
                        Text("Get a notification at the top of every hour at \(formatTimeForSetting(chimeStartTime))-\(formatTimeForSetting(chimeEndTime)).")
                    } else {
                        Text("Get a notification at the top of every hour.")
                    }
                }
                .animation(.spring(), value: hourlyNotificationEnabled)
                
                // Others
                Section {
                    
                    // Available Time Section - only show when System Time is enabled
                    if showLocalTime {
                        if hasLifetimeAccess {
                            NavigationLink(destination: AvailableTimePicker(worldClocks: worldClocks)) {
                                HStack(spacing: 12) {
                                    SystemIconImage(systemName: "checkmark.circle.fill", topColor: .gray, bottomColor: .gray, style: .plain)
                                    Text("Available Time")
                                }
                            }
                        } else {
                            Button(action: {
                                if hapticEnabled {
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                }
                                showLifetimeStore = true
                            }) {
                                HStack(spacing: 12) {
                                    SystemIconImage(systemName: "checkmark.circle.fill", topColor: .gray, bottomColor: .gray, style: .plain)
                                    Text("Available Time")
                                    
                                    Spacer()
                                    
                                    Image(systemName: "lock.fill")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    
                    // Calendar Section
                    NavigationLink(destination: CalendarView(worldClocks: worldClocks)) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "calendar", topColor: .gray, bottomColor: .gray, style: .plain)
                            Text("Calendar")
                        }
                    }
                }
                
                
                // Contact Sections
                Section{
                    
                    Button(action: {
                        // Prefer Gmail if installed, otherwise fall back to the default mail app
                        if let gmailURL = URL(string: "googlegmail://co?to=7luyuhang@gmail.com&subject=Touch%20Time%20Feedback"),
                           UIApplication.shared.canOpenURL(gmailURL) {
                            UIApplication.shared.open(gmailURL)
                        } else if let url = URL(string: "mailto:7luyuhang@gmail.com?subject=Touch%20Time%20Feedback") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Send Feedback")
                            
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    
                    Link(destination: URL(string: "https://apps.apple.com/app/touchtime/id6753721487?action=write-review")!) {
                        HStack {
                            Text("Review on App Store")
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    ShareLink(
                        item: URL(string: "https://apps.apple.com/us/app/touch-time-world-clock/id6753721487")!,
                        message: Text("Download Touch Time.")
                    ) {
                        HStack {
                            Text("Share with Friends")
                        }
                    }
                    .foregroundStyle(.primary)
                }
                
                
                Section(footer:
                            HStack(spacing: 4) {
                    Text("Designed & built by")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                    
                    Menu {
                        Section("Contact") {
                            Link(destination: URL(string: "https://luyuhang.net")!) {
                                Text("Website")
                            }
                            
                            Link(destination: URL(string: "https://www.instagram.com/7ahang/")!) {
                                Text("Instagram")
                            }
                            
                            Link(destination: URL(string: "https://x.com/yuhanglu")!) {
                                Text("X")
                            }
                            
                            Link(destination: URL(string: "mailto:7luyuhang@gmail.com")!) {
                                Text("Email")
                            }}
                        
                    } label: {
                        Text("yuhang")
                            .font(.footnote)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.plain)
                    
                    Text("in London.")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
                    .foregroundStyle(.primary)
                ) {
                    NavigationLink(destination: AboutView(worldClocks: $worldClocks, weatherManager: weatherManager)) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "info.circle.fill", topColor: .gray, bottomColor: .gray, style: .plain)
                            Text("About")
                        }
                    }

                    HStack {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "plus.app", topColor: .gray, bottomColor: .gray, style: .plain)
                            Text("More Apps")
                        }
                        Spacer()
                        HStack(spacing: 10) {
                            Image("TouchTimeAppIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .modifier(ShakeEffect(shakes: CGFloat(touchTimeIconShakes)))
                                .onTapGesture {
                                    if hapticEnabled {
                                        let feedback = UINotificationFeedbackGenerator()
                                        feedback.prepare()
                                        feedback.notificationOccurred(.error)
                                    }
                                    withAnimation(.linear(duration: 0.4)) {
                                        touchTimeIconShakes += 1
                                    }
                                }

                            Menu {
                                Button(action: {
                                    // Open Hands Time app if installed, otherwise App Store
                                    if let handsTimeURL = URL(string: "handstime://"),
                                       UIApplication.shared.canOpenURL(handsTimeURL) {
                                        UIApplication.shared.open(handsTimeURL)
                                    } else if let appStoreURL = URL(string: "https://apps.apple.com/us/app/hands-time-minimalist-widget/id6462440720") {
                                        UIApplication.shared.open(appStoreURL)
                                    }
                                }) {
                                    Text(verbatim: "Hands Time")
                                    Text("Minimalist Widget")
                                }

                                Section("Teams") {
                                    Link(destination: URL(string: "https://x.com/hwwaanng")!) {
                                        Text(verbatim: "@Hwang")
                                    }
                                    
                                    Link(destination: URL(string: "https://x.com/NSShuhari")!) {
                                        Text(verbatim: "@Shuhari")
                                    }
                                }
                            } label: {
                                Image("HandsTimeAppIcon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(HapticPressButtonStyle(hapticEnabled: hapticEnabled))
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: URL(string: "https://apps.apple.com/us/app/touch-time-world-clock/id6753721487")!,
                        message: Text("Download Touch Time.")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onReceive(timer) { _ in
                let now = Date()
                if !Calendar.current.isDate(now, equalTo: currentDate, toGranularity: .minute) {
                    currentDate = now
                }
            }
            .onAppear {
                normalizeLegacyDateStyle()
                normalizeDateStyleForWeather()

                // Fetch weather for local timezone
                Task {
                    guard showWeather else { return }
                    await weatherManager.getWeather(for: TimeZone.current.identifier)
                }
            }
            .task {
                await refreshLifetimeStatus()
            }
            .task {
                for await _ in Transaction.updates {
                    await refreshLifetimeStatus()
                }
            }
            .onChange(of: use24HourFormat) {
                HourlyNotificationManager.shared.reschedule()
            }
            .alert("Notifications Disabled", isPresented: $showNotificationPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Allow notifications in Settings to get on-the-hour notifications.")
            }
            .sheet(isPresented: $showLifetimeStore) {
                NavigationStack {
                    LifetimeStoreView()
                }
            }
            
            // Support & Love
            .fullScreenCover(isPresented: $showSupportLove) {
                NavigationStack {
                    TipJarView()
                }
            }
            // Complications Sheet
            .sheet(isPresented: $showComplicationsSheet) {
                NavigationStack {
                    ComplicationsSettingsView(
                        showAnalogClock: $showAnalogClock,
                        showSunPosition: $showSunPosition,
                        showSunAzimuth: $showSunAzimuth,
                        showMoonAzimuth: $showMoonAzimuth,
                        showMoonSunAzimuth: $showMoonSunAzimuth,
                        showSunriseSunset: $showSunriseSunset,
                        showWeatherCondition: $showWeatherCondition,
                        showTemperatureIndicator: $showTemperatureIndicator,
                        showUVIndex: $showUVIndex,
                        showWindDirection: $showWindDirection,
                        showDaylight: $showDaylight,
                        showTimeOverlay: $showTimeOverlay,
                        showSolarCurve: $showSolarCurve,
                        showWeather: showWeather,
                        weatherManager: weatherManager
                    )
                }
                .presentationDetents([.medium]) // Complication Sheet Height
                .presentationDragIndicator(.visible)
            }
            // Widget Sheet
            .sheet(isPresented: $showWidgetSheet) {
                WidgetIntroSheet()
            }
        }
    }

    @MainActor
    private func refreshLifetimeStatus() async {
        var isUnlocked = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                guard transaction.revocationDate == nil else { continue }

                if transaction.productID == "com.time.lifetime" {
                    isUnlocked = true
                    break
                }
            } catch {
                print("Failed to verify lifetime entitlement: \(error)")
            }
        }

        hasLifetimeAccess = isUnlocked

        if !isUnlocked {
            showGoldenHour = false
            showSunriseSunsetLines = false
            showMinuteHand = false
            availableTimeEnabled = false
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    // Format time for settings display
    func formatTimeForSetting(_ timeString: String) -> String {
        Self.settingInputTimeFormatter.timeZone = TimeZone.current
        Self.settingDisplayTimeFormatter.timeZone = TimeZone.current

        guard let date = Self.settingInputTimeFormatter.date(from: timeString) else {
            return timeString
        }
        
        if use24HourFormat {
            return timeString
        } else {
            return Self.settingDisplayTimeFormatter.string(from: date).lowercased()
        }
    }
    
}

// Fires a light haptic on press-down; used on the Hands Time menu label
// where tap gestures never fire because Menu intercepts the touch.
private struct HapticPressButtonStyle: ButtonStyle {
    let hapticEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && hapticEnabled {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}

// Horizontal shake, like the passcode "wrong code" animation
private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: 2.0 * sin(shakes * 3 * .pi * 2), y: 0)
        )
    }
}

private struct SupportLoveIcon: View {
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 22))
            .fontWeight(.medium)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        .pink,.red
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .shadow(.inner(color: .white.opacity(0.50), radius: 0, x: 0, y: 0.50))
            )
    }
}
