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

struct SunriseSunsetSheet: View {
    let cityName: String
    let timeZoneIdentifier: String
    let initialDate: Date
    let timeOffset: TimeInterval
    
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showSkyDot") private var showSkyDot = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @Environment(\.dismiss) private var dismiss
    @State private var currentDate: Date = Date()
    
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
    private func formatMoonPhase(_ phase: MoonPhase) -> String {
        let phaseString = String(describing: phase)
        // Convert from camelCase or other format to Title Case
        let formatted = phaseString
            .replacingOccurrences(of: "MoonPhase.", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
        
        // Handle common moon phase names
        switch formatted.lowercased() {
        case "newmoon", "new moon":
            return "New Moon"
        case "waxingcrescent", "waxing crescent":
            return "Waxing Crescent"
        case "firstquarter", "first quarter":
            return "First Quarter"
        case "waxinggibbous", "waxing gibbous":
            return "Waxing Gibbous"
        case "fullmoon", "full moon":
            return "Full Moon"
        case "waninggibbous", "waning gibbous":
            return "Waning Gibbous"
        case "lastquarter", "last quarter", "thirdquarter", "third quarter":
            return "Last Quarter"
        case "waningcrescent", "waning crescent":
            return "Waning Crescent"
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
    private func getMoonPhaseIcon(_ phase: MoonPhase) -> String {
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
    
    // Map timezone identifiers to coordinates using shared utility
    private func getCoordinatesForTimeZone(_ identifier: String) -> (latitude: Double, longitude: Double)? {
        return TimeZoneCoordinates.getCoordinate(for: identifier)
    }
    
    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        
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
        guard let start = startDate, let end = endDate else { return "--" }
        
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        return "\(hours)hrs \(minutes)min"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if let times = sunTimes {
                        // Main sun times
                        VStack(alignment: .leading){
                            
                            Text("Solar Time")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .blendMode(.plusLighter)
                                .padding(.horizontal, 32)
                                .padding(.bottom, 4)
                                .padding(.top, 8)
                            
                            
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
                        
                    } else {
                        // Error or no data state
                        ContentUnavailableView {
                            Label("No Data Available", systemImage: "sun.max.trianglebadge.exclamationmark")
                        } description: {
                            Text("Unable to calculate sunrise and sunset times for this location.")
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .navigationTitle(cityName)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                currentDate = initialDate
            }
            .onReceive(timer) { _ in
                currentDate = Date()
            }
            .toolbar {
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
            }
        }
    }
}
