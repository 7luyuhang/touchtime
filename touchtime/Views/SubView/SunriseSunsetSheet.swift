//
//  SunriseSunsetSheet.swift
//  touchtime
//
//  Created on 19/10/2025.
//

import SwiftUI
import SunKit
import MoonKit
import CoreLocation
import Combine
import WeatherKit

struct SunriseSunsetSheet: View {
    let cityName: String
    let timeZoneIdentifier: String
    let initialDate: Date
    let timeOffset: TimeInterval
    
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showSkyDot") private var showSkyDot = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("useCelsius") private var useCelsius = true
    @AppStorage("showWeather") private var showWeather = false
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @Environment(\.dismiss) private var dismiss
    @State private var currentDate: Date = Date()
    @StateObject private var weatherManager = WeatherManager()
    @State private var currentWeather: CurrentWeather?
    @State private var dailyWeather: DayWeather?
    @State private var weeklyWeather: [DayWeather] = []
    @State private var weatherLoadAttempted = false // No Weather Data
    @State private var isWeatherExpanded = false // Track weather section expansion
    
    // Timer to update the current date
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Calculate sunrise and sunset times
    private var sunTimes: (sunrise: Date?, sunset: Date?)? {
        // Get coordinates for the timezone
        guard let coordinates = getCoordinatesForTimeZone(timeZoneIdentifier) else {
            return nil
        }
        
        let adjustedDate = currentDate.addingTimeInterval(timeOffset)
        
        // Create Sun object with coordinates and timezone
        var sun = Sun(location: CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude), timeZone: TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current)
        
        // Set the date for calculations
        sun.setDate(adjustedDate)
        
        // Get sunrise and sunset times as properties
        let sunrise = sun.sunrise
        let sunset = sun.sunset
        
        return (sunrise, sunset)
    }
    
    // Calculate moon information
    private var moonInfo: (moonrise: Date?, moonset: Date?, phase: String, phaseIcon: String)? {
        // Get coordinates for the timezone
        guard let coordinates = getCoordinatesForTimeZone(timeZoneIdentifier) else {
            return nil
        }
        
        let adjustedDate = currentDate.addingTimeInterval(timeOffset)
        
        // Create Moon object with coordinates and timezone
        let moon = Moon(location: CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude), timeZone: TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current)
        
        // Set the date for calculations
        moon.setDate(adjustedDate)
        
        // Get moon information
        let moonrise = moon.moonRise
        let moonset = moon.moonSet
        let moonPhase = moon.currentMoonPhase
        let phase = formatMoonPhase(moonPhase)
        let phaseIcon = getMoonPhaseIcon(moonPhase)
        
        return (moonrise, moonset, phase, phaseIcon)
    }
    
    // Format moon phase to readable string
    private func formatMoonPhase(_ phase: MoonKit.MoonPhase) -> String {
        let phaseString = String(describing: phase)
        // Convert from camelCase or other format to Title Case
        let formatted = phaseString
            .replacingOccurrences(of: "MoonPhase.", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
        
        // Handle common moon phase names with localization
        switch formatted.lowercased() {
        case "newmoon", "new moon":
            return String(localized: "New Moon")
        case "waxingcrescent", "waxing crescent":
            return String(localized: "Waxing Crescent")
        case "firstquarter", "first quarter":
            return String(localized: "First Quarter")
        case "waxinggibbous", "waxing gibbous":
            return String(localized: "Waxing Gibbous")
        case "fullmoon", "full moon":
            return String(localized: "Full Moon")
        case "waninggibbous", "waning gibbous":
            return String(localized: "Waning Gibbous")
        case "lastquarter", "last quarter", "thirdquarter", "third quarter":
            return String(localized: "Last Quarter")
        case "waningcrescent", "waning crescent":
            return String(localized: "Waning Crescent")
        default:
            // If none match, try to make it readable by inserting spaces before capitals
            let result = phaseString.replacingOccurrences(of: "MoonPhase.", with: "")
            return result.enumerated().map { index, char in
                if index > 0 && char.isUppercase {
                    return " \(char)"
                }
                return String(char)
            }.joined().capitalized
        }
    }
    
    // Get SF Symbol for moon phase
    private func getMoonPhaseIcon(_ phase: MoonKit.MoonPhase) -> String {
        let phaseString = String(describing: phase)
        let formatted = phaseString
            .replacingOccurrences(of: "MoonPhase.", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
        
        // Return appropriate SF Symbol based on moon phase
        switch formatted {
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
            return "moon.stars.fill" // fallback icon
        }
    }
    
    // Get SF Symbol for weather condition
    
    // Map timezone identifiers to coordinates using shared utility
    private func getCoordinatesForTimeZone(_ identifier: String) -> (latitude: Double, longitude: Double)? {
        return TimeZoneCoordinates.getCoordinate(for: identifier)
    }
    
    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        if use24HourFormat {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm a"
            formatter.amSymbol = "am"
            formatter.pmSymbol = "pm"
        }
        
        return formatter.string(from: date)
    }
    
    private func formatDuration(from startDate: Date?, to endDate: Date?) -> String {
        guard let start = startDate, let end = endDate else { return "-" }
        
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        return String(format: String(localized: "%d hours %d minutes"), hours, minutes)
    }
    
    private func formatDayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale.current
        
        // Use very short weekday format (M, T, W, etc.)
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }
    
    // Calculate DST information
    private var dstInfo: (transitionDate: Date?, isStart: Bool, offsetHours: Int)? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }
        
        let adjustedDate = currentDate.addingTimeInterval(timeOffset)
        
        // Check if timezone supports DST by checking if there's a next transition
        guard let nextTransition = timeZone.nextDaylightSavingTimeTransition(after: adjustedDate) else {
            return nil
        }
        
        // Check if currently in DST
        let isCurrentlyDST = timeZone.isDaylightSavingTime(for: adjustedDate)
        
        // Check if the next transition will start or end DST
        // If currently in DST, next transition will end it (isStart = false)
        // If currently not in DST, next transition will start it (isStart = true)
        let isStart = !isCurrentlyDST
        
        // Calculate DST offset
        // For DST start: time moves forward (+1 hour)
        // For DST end: time moves backward (-1 hour)
        // Get the offset after the transition
        let offsetAfterTransition = timeZone.daylightSavingTimeOffset(for: nextTransition)
        let offsetBeforeTransition = timeZone.daylightSavingTimeOffset(for: adjustedDate)
        
        // The change in offset is what we want to display
        let offsetChange = offsetAfterTransition - offsetBeforeTransition
        let offsetHours = Int(offsetChange / 3600)
        
        return (nextTransition, isStart, offsetHours)
    }
    
    private func formatDSTDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale.current
        
        // Use short date format
        if Locale.current.language.languageCode?.identifier == "zh" {
            formatter.dateFormat = "MMMd日"
        } else {
            formatter.dateFormat = "MMM d"
        }
        
        return formatter.string(from: date)
    }
    
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Weather section - only show if weather is enabled in settings
                    if showWeather {
                        if let weather = currentWeather {
                            VStack(alignment: .leading, spacing: 8){
                                // Weather info section
                                HStack {
                                    HStack(spacing: 16){
                                        Image(systemName: weather.condition.icon)
                                            .symbolRenderingMode(.multicolor)
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .blendMode(.plusLighter)
                                            .frame(width: 24, height: 24)
                                        
                                        Text(weather.condition.displayName)
                                            .font(.headline)
                                            .foregroundStyle(.secondary)
                                            .blendMode(.plusLighter)
                                    }
                                    
                                    Spacer()
                                    
                                    // Temperature
                                    let temp = useCelsius ?
                                    weather.temperature.converted(to: .celsius) :
                                    weather.temperature.converted(to: .fahrenheit)
                                    let tempValue = Int(temp.value)
                                    
                                    HStack(spacing: 10) {
                                        // Temps
                                        HStack(spacing: 6){
                                            Text("\(tempValue)°")
                                                .monospacedDigit()
                                                .contentTransition(.numericText())
                                                .animation(.spring(), value: tempValue)
                                            
                                            // Minimum temperature
                                            if let daily = dailyWeather {
                                                let minTemp = useCelsius ?
                                                daily.lowTemperature.converted(to: .celsius) :
                                                daily.lowTemperature.converted(to: .fahrenheit)
                                                let minTempValue = Int(minTemp.value)
                                                
                                                Text("\(minTempValue)°")
                                                    .monospacedDigit()
                                                    .contentTransition(.numericText())
                                                    .animation(.spring(), value: minTempValue)
                                                    .foregroundStyle(.tertiary)
                                                    .blendMode(.plusLighter)
                                            }}
                                        // Chevron icon
                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(isWeatherExpanded ? .primary : .tertiary)
                                            .blendMode(.plusLighter)
                                            .rotationEffect(.degrees(isWeatherExpanded ? 90 : 0))
                                            .animation(.spring(), value: isWeatherExpanded)
                                    }
                                }
                                .padding(16)
                                .background(.white.opacity(0.05))
                                .blendMode(.plusLighter)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if hapticEnabled {
                                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                    }
                                    withAnimation(.snappy(duration: 0.50)) { // weekly weather animation
                                        isWeatherExpanded.toggle()
                                    }
                                }
                                .padding(.horizontal, 16)
                                
                                // Weekly weather section (expandable)
                                if isWeatherExpanded && !weeklyWeather.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(Array(weeklyWeather.enumerated()), id: \.offset) { index, day in
                                                VStack(spacing: 5) {
                                                    // High temperature
                                                    let highTemp = useCelsius ?
                                                    day.highTemperature.converted(to: .celsius) :
                                                    day.highTemperature.converted(to: .fahrenheit)
                                                    Text("\(Int(highTemp.value))°")
                                                        .font(.subheadline.weight(.medium))
                                                        .monospacedDigit()
                                                    
                                                    // Low temperature
                                                    let lowTemp = useCelsius ?
                                                    day.lowTemperature.converted(to: .celsius) :
                                                    day.lowTemperature.converted(to: .fahrenheit)
                                                    Text("\(Int(lowTemp.value))°")
                                                        .font(.subheadline.weight(.medium))
                                                        .foregroundStyle(.tertiary)
                                                        .blendMode(.plusLighter)
                                                        .monospacedDigit()
                                                    
                                                    // Weather icon
                                                    Image(systemName: day.condition.icon)
                                                        .symbolRenderingMode(.multicolor)
                                                        .font(.title3)
                                                        .foregroundStyle(.secondary)
                                                        .blendMode(.plusLighter)
                                                        .frame(height: 28)
                                                    
                                                    // Day of week
                                                    Text(formatDayOfWeek(day.date))
                                                        .font(.caption.weight(.semibold))
                                                        .foregroundStyle(.secondary)
                                                        .blendMode(.plusLighter)
                                                        .padding(.top, 5)
                                                }
                                                .frame(width: 64)
                                                .padding(.vertical, 12)
                                                .background(.white.opacity(0.05))
                                                .blendMode(.plusLighter)
                                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                    .transition(.blurReplace())
                                }
                            }
                            .padding(.top, 16) // Row top padding
                            
                        } else if weatherLoadAttempted {
                            // Show "No Internet" message when weather is enabled but couldn't be loaded
                            HStack {
                                Spacer()
                                Text("No Weather Data")
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .blendMode(.plusLighter)
                                Spacer()
                            }
                            .padding(16)
                            .background(.white.opacity(0.05))
                            .blendMode(.plusLighter)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .padding(.horizontal, 16)
                            .padding(.top, 16) // Row top padding
                        }
                    }
                    
                    if let times = sunTimes {
                        // Sun times section
                        VStack(alignment: .leading){
                            
                            Text("Solar Time")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .blendMode(.plusLighter)
                                .padding(.horizontal, 32)
                                .padding(.bottom, 4)
                                .padding(.top, showWeather ? 24 : 8)
                            
                            
                            
                            HStack(spacing: 8) {
                                // Sunrise Section
                                HStack {
                                    Image(systemName: "sunrise.fill")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .blendMode(.plusLighter)
                                        .frame(width: 24)
                                    
                                    Spacer()
                                    
                                    Text(formatTime(times.sunrise))
                                        .monospacedDigit()
                                        .contentTransition(.numericText(countsDown: false))
                                        .animation(.spring(), value: times.sunrise)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(.white.opacity(0.05))
                                .blendMode(.plusLighter)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                
                                // Sunset Section
                                HStack{
                                    Image(systemName: "sunset.fill")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .blendMode(.plusLighter)
                                        .frame(width: 24)
                                    
                                    Spacer()
                                    
                                    Text(formatTime(times.sunset))
                                        .monospacedDigit()
                                        .contentTransition(.numericText(countsDown: false))
                                        .animation(.spring(), value: times.sunset)
                                    
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(.white.opacity(0.05))
                                .blendMode(.plusLighter)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                            .padding(.horizontal, 16)
                            
                            // Daylight Duration Section
                            HStack {
                                HStack(spacing: 16){
                                    Image(systemName: "rays")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .blendMode(.plusLighter)
                                        .frame(width: 24)
                                    
                                    Text("Daylight")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .blendMode(.plusLighter)
                                }
                                Spacer()
                                
                                Text(formatDuration(from: times.sunrise, to: times.sunset))
                                    .monospacedDigit()
                                    .contentTransition(.numericText(countsDown: false))
                                    .animation(.spring(), value: "\(times.sunrise?.description ?? "")\(times.sunset?.description ?? "")")
                            }
                            .padding(16)
                            .background(.white.opacity(0.05))
                            .blendMode(.plusLighter)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .padding(.horizontal, 16)
                            
                            
                        }
                        
                        // Moon Time section
                        if let moon = moonInfo {
                            VStack(alignment: .leading){
                                
                                Text("Moon Time")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .blendMode(.plusLighter)
                                    .padding(.horizontal, 32)
                                    .padding(.bottom, 4)
                                    .padding(.top, 24)
                                
                                HStack(spacing: 8) {
                                    // Moonrise Section
                                    HStack {
                                        Image(systemName: "moonrise.fill")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .blendMode(.plusLighter)
                                            .frame(width: 24)
                                        
                                        Spacer()
                                        
                                        Text(formatTime(moon.moonrise))
                                            .monospacedDigit()
                                            .contentTransition(.numericText(countsDown: false))
                                            .animation(.spring(), value: moon.moonrise)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(16)
                                    .background(.white.opacity(0.05))
                                    .blendMode(.plusLighter)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    
                                    // Moonset Section
                                    HStack{
                                        Image(systemName: "moonset.fill")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .blendMode(.plusLighter)
                                            .frame(width: 24)
                                        
                                        Spacer()
                                        
                                        Text(formatTime(moon.moonset))
                                            .monospacedDigit()
                                            .contentTransition(.numericText(countsDown: false))
                                            .animation(.spring(), value: moon.moonset)
                                        
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(16)
                                    .background(.white.opacity(0.05))
                                    .blendMode(.plusLighter)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                }
                                .padding(.horizontal, 16)
                                
                                // Moon Phase Section
                                HStack {
                                    HStack(spacing: 16){
                                        Image(systemName: moon.phaseIcon)
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .blendMode(.plusLighter)
                                            .frame(width: 24)
                                            .contentTransition(.symbolEffect(.replace))
                                            .animation(.spring(), value: moon.phaseIcon)
                                        
                                        Text("Moon Phase")
                                            .font(.headline)
                                            .foregroundStyle(.secondary)
                                            .blendMode(.plusLighter)
                                    }
                                    Spacer()
                                    
                                    Text(moon.phase)
                                        .foregroundStyle(.primary)
                                }
                                .padding(16)
                                .background(.white.opacity(0.05))
                                .blendMode(.plusLighter)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                currentDate = initialDate
                
                // Fetch weather data only if weather is enabled
                if showWeather {
                    Task {
                        await weatherManager.getWeather(for: timeZoneIdentifier)
                        weatherLoadAttempted = true
                        if let weather = weatherManager.weatherData[timeZoneIdentifier] {
                            currentWeather = weather
                        }
                        if let daily = weatherManager.dailyWeatherData[timeZoneIdentifier] {
                            dailyWeather = daily
                        }
                        if let weekly = weatherManager.weeklyWeatherData[timeZoneIdentifier] {
                            weeklyWeather = weekly
                        }
                    }
                }
            }
            .onReceive(timer) { _ in
                currentDate = Date()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(cityName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        let adjustedDate = currentDate.addingTimeInterval(timeOffset)
                        Text(adjustedDate.formattedDate(
                            style: dateStyle,
                            timeZone: TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
                        ))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
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
                if showSkyDot {
                    ToolbarItem(placement: .topBarTrailing) {
                        SkyDotView(date: currentDate.addingTimeInterval(timeOffset), timeZoneIdentifier: timeZoneIdentifier)
                    }
                }
                
                // DST information in bottom bar
                if let dst = dstInfo, let transitionDate = dst.transitionDate {
                    ToolbarItem(placement: .bottomBar) {
                        HStack(spacing: 5) {
                            Text("DST")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            Text(dst.isStart ? String(localized: "Starts") : String(localized: "Ends"))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            Text(formatDSTDate(transitionDate))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.primary)
                            
                            if dst.offsetHours != 0 {
                                Text(dst.offsetHours > 0 ? String(format: String(localized: "+%d hours"), dst.offsetHours) : String(format: String(localized: "%d hours"), dst.offsetHours))
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }
}
