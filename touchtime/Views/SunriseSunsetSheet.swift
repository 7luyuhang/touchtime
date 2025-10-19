//
//  SunriseSunsetSheet.swift
//  touchtime
//
//  Created on 19/10/2025.
//

import SwiftUI
import SunKit
import CoreLocation

struct SunriseSunsetSheet: View {
    let cityName: String
    let timeZoneIdentifier: String
    let currentDate: Date
    let timeOffset: TimeInterval
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @Environment(\.dismiss) private var dismiss
    
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
                        VStack(alignment: .leading) {
                            // Subtitle
                            Text("Solar Time")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 4)
                            
                            // Main sun times
                            HStack(spacing: 8) {
                                // Sunrise
                                HStack {
                                    Image(systemName: "sunrise.fill")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    
                                    Spacer()
                                    
                                    Text(formatTime(times.sunrise))
                                        .monospacedDigit()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                
                                // Sunset
                                HStack{
                                    Image(systemName: "sunset.fill")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    
                                    Spacer()
                                    
                                    Text(formatTime(times.sunset))
                                        .monospacedDigit()
                                    
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .padding(.horizontal, 16)
                            
                            
                            // Daylight duration
                            HStack {
                                HStack(spacing: 16){
                                    Image(systemName: "sun.max.fill")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    
                                    Text("Daylight")
                                        .font(.headline)
                                }
                                Spacer()
                                
                                Text(formatDuration(from: times.sunrise, to: times.sunset))
                                    .monospacedDigit()
                            }
                            .padding(16)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal, 16)
                        }
                        
                        
                    } else {
                        // Error or no data state
                        ContentUnavailableView {
                            Label("No Data Available", systemImage: "sun.max.trianglebadge.exclamationmark")
                        } description: {
                            Text("Something wrong here.")
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}
