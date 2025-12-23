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
    @AppStorage("showSunPosition") private var showSunPosition = false
    @AppStorage("showWeatherCondition") private var showWeatherCondition = false
    @AppStorage("showSunAzimuth") private var showSunAzimuth = false
    @AppStorage("showArcIndicator") private var showArcIndicator = true // Default turn on
    @State private var currentDate = Date()
    @State private var showResetConfirmation = false
    @State private var showSupportLove = false
    @State private var showOnboarding = false
    @State private var showComplicationsSheet = false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var weatherManager = WeatherManager()
    
    // Timer for updating the preview
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Format time for preview (time part only)
    func formatTime(use24Hour: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        if use24Hour {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm"
        }
        
        return formatter.string(from: currentDate)
    }
    
    // Format AM/PM for preview
    func formatAMPM() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
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
    
    // Get current language display name
    var currentLanguageName: String {
        let preferredLanguage = Bundle.main.preferredLocalizations.first ?? "en"
        switch preferredLanguage {
        case "zh-Hans":
            return "简体中文"
        case "zh-Hant":
            return "繁體中文"
        case "en":
            return "English"
        default:
            return "English"
        }
    }
    
    // Get current complication name
    var currentComplicationName: String? {
        if showAnalogClock {
            return String(localized: "Analog Clock")
        } else if showSunPosition {
            return String(localized: "Sun Elevation")
        } else if showSunAzimuth {
            return String(localized: "Sun Azimuth")
        } else if showWeatherCondition {
            return String(localized: "Weather Condition")
        }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            List {
                
                // Support & Love
                Button(action: {
                    if hapticEnabled {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    showSupportLove = true
                }) {
                    HStack(spacing: 12) {
                        SystemIconImage(systemName: "heart.fill", topColor: .pink, bottomColor: .red)
                        
                        VStack (alignment: .leading) {
                            Text("Support & Love")
                                .font(.headline)
                            Text("Your support means the world")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .blendMode(.plusLighter)
                        }
                    }
                }
                .foregroundStyle(.primary)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                    //                        .fill(
                    //                            LinearGradient(
                    //                                colors: [
                    //                                    .pink,.red
                    //                                ],
                    //                                startPoint: .topLeading,
                    //                                endPoint: .bottomTrailing
                    //                            ).opacity(0.25)
                    //                        )
                        .fill(Color.black.opacity(0.55))
                        .glassEffect(.clear.interactive(),
                                     in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                )
                
                
                // General Section
                Section(header: Text("General"), footer: Text("Enable showing system time at the top of the list with ambient background.")) {
                    
                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            HStack(spacing: 12) {
                                SystemIconImage(systemName: "character", topColor: .yellow, bottomColor: .yellow, foregroundColor: .black)
                                Text("Language")
                            }
                            .layoutPriority(1)
                            Spacer(minLength: 8)
                            Text(currentLanguageName)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Toggle(isOn: $hapticEnabled) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "water.waves", topColor: .blue, bottomColor: .cyan)
                            Text("Haptics")
                        }
                    }
                    .tint(.blue)
                    
                    Toggle(isOn: $showLocalTime) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "location.fill", topColor: .gray, bottomColor: Color(UIColor.systemGray3))
                            Text("System Time")
                        }
                    }
                    .tint(.blue)
                }
                
                // Available Time Section - only show when System Time is enabled
                if showLocalTime {
                    NavigationLink(destination: AvailableTimePicker(worldClocks: worldClocks)) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "checkmark.circle.fill", topColor: .green, bottomColor: .green)
                            Text("Available Time")
                        }
                    }
                }
                
                // Temperature/Weather Section
                Section {
                    Toggle(isOn: Binding(
                        get: { showWeather },
                        set: { newValue in
                            showWeather = newValue
                            if !newValue {
                                showWeatherCondition = false
                            }
                        }
                    )) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "sun.max.fill", topColor: .red, bottomColor: .orange)
                            Text("Weather")
                        }
                    }
                    .tint(.blue)
                    
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
                                    
                                    // Weather for local time (left of date)
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
                                        .animation(.spring(), value: dateStyle)
                                    
                                }
                                .animation(.spring(), value: showSkyDot)
                                .animation(.spring(), value: showWeather)
                                .animation(.spring(), value: weatherManager.currentWeather)
                                
                                // Bottom row: City name and Time
                                HStack(alignment: .lastTextBaseline) {
                                    Text("City")
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Text(formatTime(use24Hour: use24HourFormat))
                                        .font(.system(size: 36))
                                        .fontWeight(.light)
                                        .fontDesign(.rounded)
                                        .monospacedDigit()
                                        .contentTransition(.numericText())
                                        .animation(.spring(), value: currentDate)
                                        .animation(.spring(), value: use24HourFormat)
                                }
                            }
                            .padding()
                            .padding(.bottom, -4)
                            
                            // Analog Clock Overlay - Centered
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
                            
                            // Sun Position Overlay - Centered
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
                            
                            // Weather Condition Overlay - Centered
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
                            
                            // Sun Azimuth Overlay - Centered
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
                        .clipShape(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                        )
                        .glassEffect(.clear.interactive(), in:
                                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                        )
                        .animation(.spring(), value: showSkyDot)
                        .animation(.spring(), value: showAnalogClock)
                        .animation(.spring(), value: showSunPosition)
                        .animation(.spring(), value: showWeatherCondition)
                        .animation(.spring(), value: showSunAzimuth)
                        .id("\(showSkyDot)-\(dateStyle)")
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
                    Toggle(isOn: $showSkyDot) {
                        HStack(spacing: 12) {
                            // Use SkyColorGradient colors for the background
                            let gradient = SkyColorGradient(date: currentDate, timeZoneIdentifier: TimeZone.current.identifier)
                            let colors = gradient.colors
                            SystemIconImage(
                                systemName: "cloud.fill",
                                topColor: colors.first ?? .blue,
                                bottomColor: colors.last ?? .white
                            )
                            Text("Sky Colour")
                        }
                    }
                    .tint(.blue)
                    
                    // 24 Hours Format
                    Toggle(isOn: $use24HourFormat) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "24.circle.fill", topColor: .gray, bottomColor: Color(UIColor.systemGray3))
                            Text("24-Hour Format")
                        }
                    }
                    .tint(.blue)
                    
                    
                    // Additional Time
                    Picker(selection: $additionalTimeDisplay) {
                        Text("Time Shift")
                            .tag("Time Difference")
                        Text("UTC")
                            .tag("UTC")
                        Divider()
                        Text("None")
                            .tag("None")
                    } label: {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "plusminus", topColor: .indigo, bottomColor: .pink)
                            Text("Additional Time")
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    
                    
                    // Date Picker
                    Picker(selection: $dateStyle) {
                        Text("Relative")
                            .tag("Relative")
                        
                        if !showAnalogClock && !showSunPosition && !showWeatherCondition && !showSunAzimuth {
                            Text("Absolute")
                                .tag("Absolute")
                        }
                    } label: {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "hourglass.bottomhalf.filled", topColor: .orange, bottomColor: .blue)
                            Text("Date Style")
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    .disabled(showAnalogClock || showSunPosition || showWeatherCondition || showSunAzimuth)
                    .onChange(of: showAnalogClock) { oldValue, newValue in
                        if newValue {
                            dateStyle = "Relative"
                        }
                    }
                    .onChange(of: showSunPosition) { oldValue, newValue in
                        if newValue {
                            dateStyle = "Relative"
                        }
                    }
                    .onChange(of: showWeatherCondition) { oldValue, newValue in
                        if newValue {
                            dateStyle = "Relative"
                        }
                    }
                    .onChange(of: showSunAzimuth) { oldValue, newValue in
                        if newValue {
                            dateStyle = "Relative"
                        }
                    }
                    
                    // Complications
                    Button(action: {
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        showComplicationsSheet = true
                    }) {
                        HStack {
                            HStack(spacing: 12) {
                                SystemIconImage(systemName: "watch.analog", topColor: .white, bottomColor: .white, foregroundColor: .black)
                                Text("Complications")
                            }
                            .layoutPriority(1)
                            Spacer(minLength: 8)
                            Text(currentComplicationName ?? String(localized: "None"))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                }
                
                // Analog Time Section
                Section {
                    Toggle(isOn: $showArcIndicator) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "circle", topColor: .black, bottomColor: .black)
                            Text("Arc Indicator")
                        }
                    }
                    .tint(.blue)
                } footer: {
                    Text("Enable showing arc indicator for time offset.")
                }
                
                
                
                // Others
                Section{
                    // Calendar Section
                    NavigationLink(destination: CalendarView(worldClocks: worldClocks)) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "calendar", topColor: .gray, bottomColor: Color(UIColor.systemGray3))
                            Text("Calendar")
                        }
                    }
                    
                    // Onboarding Section
                    Button(action: {
                        showOnboarding = true
                    }) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "sparkle.magnifyingglass", topColor: .blue, bottomColor: .pink)
                            Text("Show Onboarding")
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    // Reset Section
                    Button(action: {
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        }
                        showResetConfirmation = true
                    }) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "arrowshape.backward.fill", topColor: .indigo, bottomColor: .orange)
                            Text("Reset Cities")
                        }
                        
                    }
                    .foregroundStyle(.primary)
                    .alert("Reset Cities", isPresented: $showResetConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Reset", role: .destructive) {
                            resetToDefault()
                        }
                    } message: {
                        Text("This will reset all cities to the default list, clear any custom city names, and reset your collections.")
                    }
                } footer: {
                    Text("This will reset all cities to the default list, clear any custom city names, and reset your collections.")
                }
                
                
                // Contact Sections
                Section{
                    
                    Button(action: {
                        if let url = URL(string: "mailto:7luyuhang@gmail.com?subject=Touch%20Time%20Feedback") {
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
                
                
                Section {
                    Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                        HStack {
                            Text("Terms of Use")
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Link(destination: URL(string: "https://www.handstime.app/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
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
                            }}
                        
                        Section("More apps from team") {
                            Link(destination: URL(string: "https://apps.apple.com/us/app/hands-time-minimalist-widget/id6462440720")!) {
                                Text("Hands Time - Minimalist Widget")
                            }
                        }
                        
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
                    
                    
                    // Credits
                    NavigationLink(destination: CreditsView()) {
                        Text("Acknowledgements")
                    }
                    // Version
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(getVersionString())
                            .foregroundColor(.secondary)
                    }
                    // App Info Section
                    Text(String(format: String(localized: "Copyright © %d Negative Time Limited. \nAll rights reserved."), Calendar.current.component(.year, from: Date())))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                
                
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                    }
                }
            }
            .onReceive(timer) { _ in
                currentDate = Date()
            }
            .onAppear {
                // Fetch weather for local timezone
                Task {
                    await weatherManager.getWeather(for: TimeZone.current.identifier)
                }
            }
            
            // Support & Love
            .fullScreenCover(isPresented: $showSupportLove) {
                NavigationStack {
                    TipJarView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(action: {
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                    }
                                    showSupportLove = false
                                }) {
                                    Image(systemName: "xmark")
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                }
            }
            // Onboarding
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(hasCompletedOnboarding: Binding(
                    get: { !showOnboarding },
                    set: { newValue in
                        if newValue {
                            showOnboarding = false
                        }
                    }
                ))
                .overlay(alignment: .topTrailing) {
                    Button(action: {
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        showOnboarding = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .glassEffect(.clear.interactive())
                    }
                    .padding(.horizontal)
                }
            }
            // Complications Sheet
            .sheet(isPresented: $showComplicationsSheet) {
                NavigationStack {
                    ComplicationsSettingsView(
                        showAnalogClock: $showAnalogClock,
                        showSunPosition: $showSunPosition,
                        showSunAzimuth: $showSunAzimuth,
                        showWeatherCondition: $showWeatherCondition,
                        showWeather: showWeather,
                        weatherManager: weatherManager
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: {
                                if hapticEnabled {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                showComplicationsSheet = false
                            }) {
                                Image(systemName: "xmark")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                .presentationDetents([.height(220)])
            }
        }
    }
    
    // UserDefaults key for storing world clocks
    private let worldClocksKey = "savedWorldClocks"
    private let collectionsKey = "savedCityCollections"
    
    // Reset to default clocks
    func resetToDefault() {
        // Set to default clocks
        worldClocks = WorldClockData.defaultClocks
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(worldClocks) {
            UserDefaults.standard.set(encoded, forKey: worldClocksKey)
        }
        
        // Clear all collections
        UserDefaults.standard.removeObject(forKey: collectionsKey)
        
        // Clear selected collection
        UserDefaults.standard.removeObject(forKey: "selectedCollectionId")
        
        // Post notification to reset scroll time
        NotificationCenter.default.post(name: NSNotification.Name("ResetScrollTime"), object: nil)
        
        // Provide haptic feedback if enabled
        if hapticEnabled {
            let impactFeedback = UINotificationFeedbackGenerator()
            impactFeedback.prepare()
            impactFeedback.notificationOccurred(.success)
        }
    }
    
    // Format time for settings display
    func formatTimeForSetting(_ timeString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        guard let date = formatter.date(from: timeString) else {
            return timeString
        }
        
        if use24HourFormat {
            return timeString
        } else {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date).lowercased()
        }
    }
    
    // Get version and build number string
    func getVersionString() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
