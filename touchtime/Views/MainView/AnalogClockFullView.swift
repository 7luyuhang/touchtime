//
//  AnalogClockFullView.swift
//  touchtime
//
//  Created on 28/11/2025.
//

import SwiftUI
import Combine
import UIKit
import WeatherKit
import MoonKit
import CoreLocation

struct AnalogClockFullView: View {
    @Binding var worldClocks: [WorldClock]
    @Binding var timeOffset: TimeInterval
    @Binding var showScrollTimeButtons: Bool
    @State private var currentDate = Date()
    @State private var selectedCityId: UUID? = nil // nil means Local is selected
    @State private var showDetailsSheet = false
    @State private var showShareSheet = false
    @State private var showSettingsSheet = false
    @State private var showEarthView = false
    
    @AppStorage("use24HourFormat") private var use24HourFormat = true
    @AppStorage("showLocalTime") private var showLocalTime = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("showWeather") private var showWeather = false
    @AppStorage("useCelsius") private var useCelsius = true
    @AppStorage("showSkyDot") private var showSkyDot = true
    
    @StateObject private var weatherManager = WeatherManager()
    
    // Namespace for zoom transition
    @Namespace private var earthViewNamespace
    
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Get selected city name
    private var selectedCityName: String {
        // Return empty when no local time and no cities
        if worldClocks.isEmpty && !showLocalTime {
            return ""
        }
        if let cityId = selectedCityId,
           let city = worldClocks.first(where: { $0.id == cityId }) {
            return city.localizedCityName
        }
        return String(localized: "Local")
    }
    
    // Get selected timezone
    private var selectedTimeZone: TimeZone {
        if let cityId = selectedCityId,
           let city = worldClocks.first(where: { $0.id == cityId }),
           let timeZone = TimeZone(identifier: city.timeZoneIdentifier) {
            return timeZone
        }
        return TimeZone.current
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let displayDate = currentDate.addingTimeInterval(timeOffset)
                let skyGradient = SkyColorGradient(
                    date: displayDate,
                    timeZoneIdentifier: selectedTimeZone.identifier
                )
                
                ZStack {
                    // Background
                    Group {
                        if showSkyDot {
                            ZStack {
                                skyGradient.linearGradient()
                                    .ignoresSafeArea()
                                    .opacity(0.65)
                                    .animation(.spring(), value: selectedTimeZone.identifier)
                                
                                // Stars overlay for nighttime
                                if skyGradient.starOpacity > 0 {
                                    StarsView(starCount: 150)
                                        .ignoresSafeArea()
                                        .opacity(skyGradient.starOpacity)
                                        .blendMode(.plusLighter)
                                        .animation(.spring(), value: skyGradient.starOpacity)
                                        .allowsHitTesting(false)
                                }
                            }
                        } else {
                            Color(UIColor.systemBackground)
                                .ignoresSafeArea()
                        }
                    }
                    .animation(.spring(), value: showSkyDot)
                    
                    // Empty state when no local time and no cities
                    if worldClocks.isEmpty && !showLocalTime {
                        ContentUnavailableView {
                            Label("Nothing here", systemImage: "location.magnifyingglass")
                                .blendMode(.plusLighter)
                        } description: {
                            Text("Add cities to track time.")
                                .blendMode(.plusLighter)
                        }
                    } else {
                        // Analog Clock - always centered
                        AnalogClockFaceView(
                            date: currentDate.addingTimeInterval(timeOffset),
                            timeOffset: timeOffset,
                            selectedTimeZone: selectedTimeZone,
                            size: size,
                            worldClocks: worldClocks,
                            showLocalTime: showLocalTime,
                            selectedCityId: $selectedCityId,
                            hapticEnabled: hapticEnabled,
                            showDetailsSheet: $showDetailsSheet,
                            weather: weatherManager.weatherData[selectedTimeZone.identifier],
                            showWeather: showWeather
                        )
                        
                        // Digital time and scroll controls overlay
                        VStack(spacing: 0) {
                            // Top section - Digital time centered between nav bar and clock
                            VStack {
                                Spacer()
                                DigitalTimeDisplayView(
                                    currentDate: currentDate,
                                    timeOffset: timeOffset,
                                    selectedTimeZone: selectedTimeZone,
                                    use24HourFormat: use24HourFormat,
                                    weather: weatherManager.weatherData[selectedTimeZone.identifier],
                                    showWeather: showWeather,
                                    useCelsius: useCelsius
                                )
                                .id(currentDate) // Force update when currentDate changes
                                .animation(.spring(), value: selectedTimeZone.identifier)
                                .task(id: showWeather) {
                                    if showWeather {
                                        await weatherManager.getWeather(for: selectedTimeZone.identifier)
                                    }
                                }
                                .task(id: selectedTimeZone.identifier) {
                                    if showWeather {
                                        await weatherManager.getWeather(for: selectedTimeZone.identifier)
                                    }
                                }
                                Spacer()
                            }
                            .frame(height: (geometry.size.height - size) / 2)
                            
                            // Middle - clock area (transparent placeholder)
                            Color.clear
                                .frame(height: size)
                            
                            // Bottom section - Scroll controls
                            VStack {
                                Spacer()
                                // Local time display
                                if selectedCityId != nil {
                                    HStack(spacing: 4) {
                                        Image(systemName: "location.fill")
                                            .font(.footnote.weight(.medium))
                                        Text({
                                            let formatter = DateFormatter()
                                            formatter.locale = Locale(identifier: "en_US_POSIX")
                                            formatter.timeZone = TimeZone.current
                                            if use24HourFormat {
                                                formatter.dateFormat = "HH:mm"
                                            } else {
                                                formatter.dateFormat = "h:mm"
                                            }
                                            return formatter.string(from: displayDate)
                                        }())
                                        .font(.subheadline.weight(.medium))
                                    }
                                    .foregroundStyle(.secondary)
                                    .blendMode(.plusLighter)
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                    .padding(.bottom, 16)
                                }
                                Spacer()
                                ScrollTimeView(
                                    timeOffset: $timeOffset,
                                    showButtons: $showScrollTimeButtons,
                                    worldClocks: $worldClocks
                                )
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                            }
                            .frame(height: (geometry.size.height - size) / 2)
                        }
                    }
                }
            }
            .navigationTitle(selectedCityName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        // Share Section - only show if there are world clocks
                        if !worldClocks.isEmpty {
                            Button(action: {
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.prepare()
                                    impactFeedback.impactOccurred()
                                }
                                showShareSheet = true
                            }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            
                            Divider()
                        }
                        
                        // Settings Section
                        Button(action: {
                            if hapticEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.prepare()
                                impactFeedback.impactOccurred()
                            }
                            showSettingsSheet = true
                        }) {
                            Label("Settings", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    // Earth View Button
                    Button(action: {
                        if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.prepare()
                            impactFeedback.impactOccurred()
                        }
                        showEarthView = true
                    }) {
                        Image(systemName: "globe.americas.fill")
                    }
                    .matchedTransitionSource(id: "earthView", in: earthViewNamespace)
                }
            }
            .onReceive(timer) { _ in
                currentDate = Date()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetScrollTime"))) { _ in
                withAnimation(.smooth()) { // Hands Animation
                    timeOffset = 0
                    showScrollTimeButtons = false
                }
            }
            .sheet(isPresented: $showDetailsSheet) {
                if let cityId = selectedCityId,
                   let city = worldClocks.first(where: { $0.id == cityId }) {
                    SunriseSunsetSheet(
                        cityName: city.localizedCityName,
                        timeZoneIdentifier: city.timeZoneIdentifier,
                        initialDate: currentDate,
                        timeOffset: timeOffset
                    )
                } else {
                    SunriseSunsetSheet(
                        cityName: String(localized: "Local"),
                        timeZoneIdentifier: TimeZone.current.identifier,
                        initialDate: currentDate,
                        timeOffset: timeOffset
                    )
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareCitiesSheet(
                    worldClocks: $worldClocks,
                    showSheet: $showShareSheet,
                    currentDate: currentDate,
                    timeOffset: timeOffset
                )
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView(worldClocks: $worldClocks)
            }
            .sheet(isPresented: $showEarthView) {
                EarthView(worldClocks: $worldClocks)
                    .navigationTransition(.zoom(sourceID: "earthView", in: earthViewNamespace))
            }
            .onAppear {
                // If showLocalTime is disabled, default to first city instead of Local
                if !showLocalTime && selectedCityId == nil {
                    selectedCityId = worldClocks.first?.id
                }
            }
            .onChange(of: showLocalTime) { oldValue, newValue in
                // When showLocalTime is turned off and Local is selected, switch to first city
                if !newValue && selectedCityId == nil {
                    selectedCityId = worldClocks.first?.id
                }
            }
            .onChange(of: worldClocks) { oldValue, newValue in
                // When worldClocks changes and showLocalTime is disabled
                if !showLocalTime {
                    // Always select the first city when showLocalTime is off
                    let firstCityId = newValue.first?.id
                    if selectedCityId != firstCityId {
                        selectedCityId = firstCityId
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Time Offset Arc View
struct TimeOffsetArcView: View {
    let timeOffset: TimeInterval
    let currentDate: Date  // 原始时间（未加偏移）
    let timeZone: TimeZone
    let size: CGFloat
    
    // 计算指定日期在给定时区的角度（弧度，从顶部顺时针）
    private func angleRadians(for date: Date) -> Double {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        // 24小时制：0时在顶部，每小时15度
        // -90 度调整使 0 时在顶部（标准坐标系中0度在右边）
        let degrees = (hour + minute / 60 + second / 3600) * 15 - 90
        return degrees * .pi / 180
    }
    
    var body: some View {
        let adjustedDate = currentDate.addingTimeInterval(timeOffset)
        let startAngle = angleRadians(for: currentDate)
        let endAngle = angleRadians(for: adjustedDate)
        
        Path { path in
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = (size - 24) / 2
            
            path.addArc(
                center: center,
                radius: radius,
                startAngle: Angle(radians: startAngle),
                endAngle: Angle(radians: endAngle),
                clockwise: timeOffset < 0
            )
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .drawingGroup()
    }
}

// MARK: - Analog Clock Face View
struct AnalogClockFaceView: View {
    let date: Date
    let timeOffset: TimeInterval
    let selectedTimeZone: TimeZone
    let size: CGFloat
    let worldClocks: [WorldClock]
    let showLocalTime: Bool
    @Binding var selectedCityId: UUID?
    let hapticEnabled: Bool
    @Binding var showDetailsSheet: Bool
    let weather: CurrentWeather?
    let showWeather: Bool
    
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showArcIndicator") private var showArcIndicator = true
    @AppStorage("availableTimeEnabled") private var availableTimeEnabled = false
    @AppStorage("availableStartTime") private var availableStartTime = "09:00"
    @AppStorage("availableEndTime") private var availableEndTime = "17:00"
    
    // Parse time string like "09:00" to (hour, minute)
    private func parseTimeString(_ timeString: String) -> (hour: Int, minute: Int) {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return (9, 0)
        }
        return (hour, minute)
    }
    
    // Calculate position for available time indicator
    private func positionForTime(hour: Int, minute: Int, radius: CGFloat, center: CGFloat) -> CGPoint {
        let angleDegrees = Double(hour) * 15.0 + Double(minute) * 0.25 - 90
        let angleRadians = angleDegrees * .pi / 180
        let x = center + radius * CGFloat(cos(angleRadians))
        let y = center + radius * CGFloat(sin(angleRadians))
        return CGPoint(x: x, y: y)
    }
    
    // Get local time components
    private var localTime: (hour: Int, minute: Int) {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0, components.minute ?? 0)
    }
    
    // Get time for a specific timezone
    private func getTime(for timeZoneIdentifier: String) -> (hour: Int, minute: Int) {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return (0, 0)
        }
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0, components.minute ?? 0)
    }
    
    // Calculate angle for a given hour and minute
    private func angleForTime(hour: Int, minute: Int) -> Double {
        // 24-hour clock: full rotation = 24 hours
        // 12 o'clock = 0 degrees (top)
        // Each hour = 15 degrees (360/24)
        let hourAngle = Double(hour) * 15.0
        let minuteAngle = Double(minute) * 0.25 // 15 degrees per hour / 60 minutes
        return hourAngle + minuteAngle - 90 // Adjust so 0 hours is at top
    }
    
    // Group non-selected world clocks by time - show only one city per unique time
    // Also excludes times that match the selected city's time
    private var groupedNonSelectedClocks: [WorldClock] {
        // Get selected city's time if any
        var selectedTime: (hour: Int, minute: Int)? = nil
        if let cityId = selectedCityId,
           let selectedClock = worldClocks.first(where: { $0.id == cityId }) {
            selectedTime = getTime(for: selectedClock.timeZoneIdentifier)
        }
        
        var seenTimes: Set<String> = []
        var result: [WorldClock] = []
        
        for clock in worldClocks where clock.id != selectedCityId {
            let time = getTime(for: clock.timeZoneIdentifier)
            let key = "\(time.hour):\(time.minute)"
            
            // Skip if we already have a clock at this time
            if seenTimes.contains(key) {
                continue
            }
            
            // Skip if this time matches local time (when showLocalTime is enabled)
            if showLocalTime && time.hour == localTime.hour && time.minute == localTime.minute {
                continue
            }
            
            // Skip if this time matches the selected city's time
            if let selectedTime = selectedTime,
               time.hour == selectedTime.hour && time.minute == selectedTime.minute {
                continue
            }
            
            seenTimes.insert(key)
            result.append(clock)
        }
        
        return result
    }
    
    // 计算原始日期（不带偏移）
    private var originalDate: Date {
        date.addingTimeInterval(-timeOffset)
    }
    
    // Get SF Symbol for current moon phase
    private var moonPhaseIcon: String {
        // Get coordinates for the timezone
        guard let coordinates = TimeZoneCoordinates.getCoordinate(for: selectedTimeZone.identifier) else {
            return "moon.fill"
        }
        
        let moon = Moon(
            location: CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude),
            timeZone: selectedTimeZone
        )
        moon.setDate(date)
        
        let phaseString = String(describing: moon.currentMoonPhase)
            .replacingOccurrences(of: "MoonPhase.", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
        
        switch phaseString {
        case "newmoon", "new moon":
            return "moonphase.new.moon"
        case "waxingcrescent", "waxing crescent":
            return "moonphase.waxing.crescent"
        case "firstquarter", "first quarter":
            return "moonphase.first.quarter"
        case "waxinggibbous", "waxing gibbous":
            return "moonphase.waxing.gibbous"
        case "fullmoon", "full moon":
            return "moonphase.full.moon"
        case "waninggibbous", "waning gibbous":
            return "moonphase.waning.gibbous"
        case "lastquarter", "last quarter", "thirdquarter", "third quarter":
            return "moonphase.last.quarter"
        case "waningcrescent", "waning crescent":
            return "moonphase.waning.crescent"
        default:
            return "moon.fill"
        }
    }
    
    var body: some View {
        ZStack {
            // Clock face background
            Circle()
                .fill(Color.black.opacity(0.25))
                .glassEffect(.clear)
                .frame(width: max(size - 24, 0), height: max(size - 24, 0))
            
            // Time offset arc (显示滚动时间的起点到终点)
            if showArcIndicator && timeOffset != 0 {
                TimeOffsetArcView(
                    timeOffset: timeOffset,
                    currentDate: originalDate,
                    timeZone: selectedTimeZone,
                    size: size
                )
                .transition(.identity)
            }
            
            // Hour numbers
            HourNumbersView(size: size)
            
            // Available time indicators
            if availableTimeEnabled {
                let startTime = parseTimeString(availableStartTime)
                let endTime = parseTimeString(availableEndTime)
                let indicatorRadius = (size - 24) / 2 - 10
                let center = size / 2
                
                // Start time indicator
                Circle()
                    .fill(.white.opacity(0.50))
                    .frame(width: 6, height: 6)
                    .blendMode(.plusLighter)
                    .position(positionForTime(hour: startTime.hour, minute: startTime.minute, radius: indicatorRadius, center: center))
                
                // End time indicator
                Circle()
                    .fill(.white.opacity(0.50))
                    .frame(width: 6, height: 6)
                    .blendMode(.plusLighter)
                    .position(positionForTime(hour: endTime.hour, minute: endTime.minute, radius: indicatorRadius, center: center))
            }
            
            // Sun/Weather icon
            Image(systemName: showWeather && weather != nil ? weather!.condition.icon : "sun.max.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
                .blendMode(.plusLighter)
                .frame(height: 24)
                .position(x: size / 2,  y: size / 2 + (size / 2 - 64))
                .contentTransition(.symbolEffect(.replace))
                .animation(.spring(), value: weather?.condition)
            
            // Moon phase icon
            Image(systemName: moonPhaseIcon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
                .blendMode(.plusLighter)
                .frame(height: 24)
                .position(x: size / 2, y: size / 2 - (size / 2 - 62))
                .contentTransition(.symbolEffect(.replace))
                .animation(.spring(), value: moonPhaseIcon)
            
            // World clock hands with city labels (non-selected first)
            // Grouped by time to avoid overlapping labels - only one city shown per unique time
            ForEach(groupedNonSelectedClocks) { clock in
                let time = getTime(for: clock.timeZoneIdentifier)
                ClockHandWithLabel(
                    cityId: clock.id,
                    cityName: clock.localizedCityName,
                    hour: time.hour,
                    minute: time.minute,
                    size: size,
                    color: .white.opacity(0.25), // Hand colour
                    isSelected: false,
                    isLocal: false,
                    selectedCityId: $selectedCityId,
                    hapticEnabled: hapticEnabled,
                    showDetailsSheet: $showDetailsSheet
                )
            }
            
            // Local time hand (non-selected)
            if showLocalTime && selectedCityId != nil {
                ClockHandWithLabel(
                    cityId: nil,
                    cityName: String(localized: "Local"),
                    hour: localTime.hour,
                    minute: localTime.minute,
                    size: size,
                    color: .blue,
                    isSelected: false,
                    isLocal: true,
                    selectedCityId: $selectedCityId,
                    hapticEnabled: hapticEnabled,
                    showDetailsSheet: $showDetailsSheet
                )
            }
            
            // Selected city hand (rendered last to be on top)
            if let cityId = selectedCityId,
               let clock = worldClocks.first(where: { $0.id == cityId }) {
                let time = getTime(for: clock.timeZoneIdentifier)
                if !showLocalTime || time.hour != localTime.hour || time.minute != localTime.minute {
                    ClockHandWithLabel(
                        cityId: clock.id,
                        cityName: clock.localizedCityName,
                        hour: time.hour,
                        minute: time.minute,
                        size: size,
                        color: .white.opacity(0.25),
                        isSelected: true,
                        isLocal: false,
                        selectedCityId: $selectedCityId,
                        hapticEnabled: hapticEnabled,
                        showDetailsSheet: $showDetailsSheet
                    )
                }
            } else if showLocalTime && selectedCityId == nil {
                // Local is selected - render on top
                ClockHandWithLabel(
                    cityId: nil,
                    cityName: String(localized: "Local"),
                    hour: localTime.hour,
                    minute: localTime.minute,
                    size: size,
                    color: .blue,
                    isSelected: true,
                    isLocal: true,
                    selectedCityId: $selectedCityId,
                    hapticEnabled: hapticEnabled,
                    showDetailsSheet: $showDetailsSheet
                )
            }
            
            Circle()
                .frame(width: 8, height: 8)
                .glassEffect(.clear.tint(.white.opacity(0.25)))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Clock Hand with Label
struct ClockHandWithLabel: View {
    let cityId: UUID?
    let cityName: String
    let hour: Int
    let minute: Int
    let size: CGFloat
    let color: Color
    let isSelected: Bool
    let isLocal: Bool
    @Binding var selectedCityId: UUID?
    let hapticEnabled: Bool
    @Binding var showDetailsSheet: Bool
    
    private var angle: Double {
        // 24-hour clock: full rotation = 24 hours
        let hourAngle = Double(hour) * 15.0 // 15 degrees per hour
        let minuteAngle = Double(minute) * 0.25 // 15/60 degrees per minute
        return hourAngle + minuteAngle
    }
    
    // Counter-rotation: flip text 180° when pointing down/left to keep it readable
    private var textCounterRotation: Double {
        // When angle is greater than 180° (bottom half), flip the text
        angle > 180 ? 180 : 0
    }
    
    // Hand color: white when selected, blue for Local when not selected
    private var handColor: Color {
        if isSelected {
            return .white
        }
        if isLocal {
            return .blue
        }
        return color
    }
    
    var body: some View {
        // Rotate the entire group together so hand and label animate in sync
        ZStack {
            // Hand line - positioned straight up
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(handColor)
                .frame(width: (isSelected || isLocal) ? 2.5 : 1.25, height: max(size / 2 - 95, 0))
                .offset(y: -(size / 4 - 47.5))
                .blendMode((isSelected || isLocal) ? .normal : .plusLighter)
            
            // City label - positioned straight up, at outer end, parallel to hand
            Group {
                if isSelected {
                    // Selected (either Local or city) - white background
                    if isLocal {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.black)
                            Text(cityName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.black)
                        }
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: 95)
                        .background(Color.white, in: Capsule(style: .continuous))
                    } else {
                        Text(cityName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: 95)
                            .background(Color.white, in: Capsule(style: .continuous))
                    }
                } else if isLocal {
                    // Local not selected - blue style
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2.weight(.semibold))
                        Text(cityName)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: 95)
                    .background(Color.blue, in: Capsule(style: .continuous))
                } else {
                    // Non-local not selected
                    Text(cityName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: 95)
                        .blendMode(.plusLighter)
                        .background(.thinMaterial, in: Capsule(style: .continuous))
                }
            }
            .contentShape(Capsule())
            .onTapGesture { // Tap hand
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
                // Open details sheet when tapping selected city
                if isSelected {
                    showDetailsSheet = true
                } else {
                    selectedCityId = cityId
                }
            }
            // Rotate 90° to align parallel with hand, then flip if needed for readability
            .rotationEffect(.degrees(-90 + textCounterRotation))
            // Position closer to center
            .offset(y: -(size / 2 - 95))
        }
        .animation(.none, value: angle)
        .rotationEffect(.degrees(angle))
    }
}

// MARK: - Digital Time Display
struct DigitalTimeDisplayView: View {
    let currentDate: Date
    let timeOffset: TimeInterval
    let selectedTimeZone: TimeZone
    let use24HourFormat: Bool
    let weather: CurrentWeather?
    let showWeather: Bool
    let useCelsius: Bool
    
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("additionalTimeDisplay") private var additionalTimeDisplay = "None"
    
    // Calculate additional time display text (follows WorldClock model pattern)
    private func additionalTimeText() -> String {
        switch additionalTimeDisplay {
        case "Time Difference":
            let selectedOffset = selectedTimeZone.secondsFromGMT()
            let localOffset = TimeZone.current.secondsFromGMT()
            let differenceSeconds = selectedOffset - localOffset
            let differenceHours = differenceSeconds / 3600
            if differenceHours == 0 {
                return ""
            } else if differenceHours > 0 {
                return String(format: String(localized: "+%d hours"), differenceHours)
            } else {
                return String(format: String(localized: "%d hours"), differenceHours)
            }
        case "UTC":
            let offsetSeconds = selectedTimeZone.secondsFromGMT()
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
        VStack(spacing: 0) {
            // Additional time display
            let additionalText = additionalTimeText()
            if !additionalText.isEmpty || additionalTimeDisplay == "UTC" {
                Text(additionalText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .transition(.blurReplace.combined(with: .move(edge: .bottom)))
                    .blendMode(.plusLighter)
            }
            
            Text({
                let formatter = DateFormatter()
                formatter.timeZone = selectedTimeZone
                formatter.locale = Locale(identifier: "en_US_POSIX")
                if use24HourFormat {
                    formatter.dateFormat = "HH:mm"
                } else {
                    formatter.dateFormat = "h:mm"
                }
                let adjustedDate = currentDate.addingTimeInterval(timeOffset)
                return formatter.string(from: adjustedDate)
            }())
            .font(.system(size: 52))
            .fontWeight(.light)
            .fontDesign(.rounded)
            .monospacedDigit()
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            
            // Date display with weather - follows app's dateStyle setting
            HStack(spacing: 4) {
                if showWeather {
                    WeatherView(
                        weather: weather,
                        useCelsius: useCelsius
                    )
                }
                
                Text({
                    let adjustedDate = currentDate.addingTimeInterval(timeOffset)
                    return adjustedDate.formattedDate(style: dateStyle, timeZone: selectedTimeZone)
                }())
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
                .contentTransition(.numericText())
            }
        }
    }
}
