//
//  SunriseSunsetSheet.swift
//  touchtime
//
//  Created on 19/10/2025.
//

import SwiftUI
import SunKit
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
    private var sunTimes: (sunrise: Date?, sunset: Date?, solarNoon: Date?)? {
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
        let solarNoon = sun.solarNoon
        
        return (sunrise, sunset, solarNoon)
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
                            
                            
                            // Solar Noon Section
                            HStack {
                                HStack(spacing: 16){
                                    Image(systemName: "sun.max.fill")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .blendMode(.plusLighter)
                                        .frame(width: 24)
                                    
                                    Text("Solar Noon")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .blendMode(.plusLighter)
                                }
                                Spacer()
                                
                                Text(formatTime(times.solarNoon))
                                    .monospacedDigit()
                                    .contentTransition(.numericText(countsDown: false))
                                    .animation(.spring(), value: times.solarNoon)
                            }
                            .padding(16)
                            .background(.white.opacity(0.05))
                            .blendMode(.plusLighter)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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