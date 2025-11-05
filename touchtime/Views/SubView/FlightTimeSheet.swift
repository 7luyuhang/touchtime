//
//  FlightTimeSheet.swift
//  touchtime
//
//  Created on 03/11/2025.
//

import SwiftUI
import CoreLocation

struct FlightTimeSheet: View {
    @Binding var worldClocks: [WorldClock]
    @Binding var showSheet: Bool
    @Binding var selectedFlightCities: (from: WorldClock?, to: WorldClock?)
    @State private var selectedCities: Set<UUID> = []
    @State private var includeLocalTime = false
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showLocalTime") private var showLocalTimeInHome = true
    @AppStorage("customLocalName") private var customLocalName = ""
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    let currentDate: Date
    
    // Get local city name from timezone
    var localCityName: String {
        let identifier = TimeZone.current.identifier
        let components = identifier.split(separator: "/")
        if components.count >= 2 {
            return components.last!.replacingOccurrences(of: "_", with: " ")
        } else {
            return identifier
        }
    }
    
    // Create a virtual WorldClock for local time
    var localTimeAsClock: WorldClock {
        WorldClock(
            cityName: customLocalName.isEmpty ? localCityName : customLocalName,
            timeZoneIdentifier: TimeZone.current.identifier
        )
    }
    
    // Format time for display
    func formatTime(for timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        if use24HourFormat {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm a"
            formatter.amSymbol = "am"
            formatter.pmSymbol = "pm"
        }
        
        return formatter.string(from: currentDate).lowercased()
    }
    
    // Calculate flight time between two timezones
    func calculateFlightTime(from fromTimeZone: TimeZone, to toTimeZone: TimeZone) -> String {
        // Get coordinates for both timezones
        guard let fromCoords = TimeZoneCoordinates.getCoordinate(for: fromTimeZone.identifier),
              let toCoords = TimeZoneCoordinates.getCoordinate(for: toTimeZone.identifier) else {
            return "Unable to calculate"
        }
        
        // Calculate distance using Haversine formula
        let fromLocation = CLLocation(latitude: fromCoords.latitude, longitude: fromCoords.longitude)
        let toLocation = CLLocation(latitude: toCoords.latitude, longitude: toCoords.longitude)
        let distanceInMeters = fromLocation.distance(from: toLocation)
        let distanceInKm = distanceInMeters / 1000
        
        // Rough estimate: average flight speed 900 km/h + 30 min taxi/takeoff/landing
        let flightHours = distanceInKm / 900
        let totalHours = flightHours + 0.5
        
        let hours = Int(totalHours)
        let minutes = Int((totalHours - Double(hours)) * 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // Get selected clocks for confirm button
    var selectedClocks: [WorldClock] {
        var clocks: [WorldClock] = []
        
        // Add local time if selected
        if showLocalTimeInHome && includeLocalTime {
            clocks.append(localTimeAsClock)
        }
        
        // Add selected world clocks
        for clock in worldClocks {
            if selectedCities.contains(clock.id) {
                clocks.append(clock)
            }
        }
        
        return clocks
    }
    
    // Check if a world clock is the same as local time
    func isClockSameAsLocal(_ clock: WorldClock) -> Bool {
        return clock.timeZoneIdentifier == TimeZone.current.identifier
    }
    
    // Toggle city selection
    func toggleCitySelection(_ clockId: UUID) {
        // Provide haptic feedback if enabled
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
        withAnimation(.spring()) {
            if selectedCities.contains(clockId) {
                selectedCities.remove(clockId)
            } else {
                // Check if we already have 2 cities selected
                let totalSelected = selectedCities.count + (includeLocalTime ? 1 : 0)
                if totalSelected >= 2 {
                    // Need to deselect one
                    if includeLocalTime && selectedCities.count == 1 {
                        includeLocalTime = false
                    } else if !selectedCities.isEmpty {
                        selectedCities.removeFirst()
                    }
                }
                selectedCities.insert(clockId)
            }
        }
    }
    
    // Toggle local time selection
    func toggleLocalTime() {
        // Provide haptic feedback if enabled
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
        withAnimation(.spring()) {
            if includeLocalTime {
                includeLocalTime = false
            } else {
                // Check if we already have 2 cities selected
                if selectedCities.count >= 2 {
                    // Need to deselect one
                    selectedCities.removeFirst()
                }
                includeLocalTime = true
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    
                    // Information
                    HStack (spacing: 16) {
                        Image(systemName: "airplane.path.dotted")
                            .font(.headline)
                            .frame(width: 24)
                        
                        Text("Select 2 cities to estimate the flight time between them.")
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .blendMode(.plusLighter)
                    
                    // Time List
                    VStack(spacing: 0) {
                        // Local time card
                        if showLocalTimeInHome {
                            HStack(spacing: 16) {
                                // Selection indicator
                                ZStack {
                                    if includeLocalTime {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.primary)
                                            .transition(.blurReplace.combined(with: .scale))
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.primary.opacity(0.25))
                                            .transition(.blurReplace.combined(with: .scale))
                                    }
                                }
                                
                                // City name
                                Text(customLocalName.isEmpty ? localCityName : customLocalName)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                
                                Spacer()
                                
                                // Time
                                HStack(spacing: 6) {
                                    Image(systemName: "location.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(formatTime(for: TimeZone.current))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleLocalTime()
                            }
                        }
                        
                        // World clocks cards
                        ForEach(worldClocks) { clock in
                            let isDisabled = isClockSameAsLocal(clock)
                            
                            HStack(spacing: 16) {
                                // Selection indicator
                                ZStack {
                                    if isDisabled {
                                        Image(systemName: "circle")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.primary.opacity(0.25))
                                        
                                    } else if selectedCities.contains(clock.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.primary)
                                            .transition(.blurReplace.combined(with: .scale))
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.primary.opacity(0.25))
                                            .transition(.blurReplace.combined(with: .scale))
                                    }
                                }
                                // City name
                                Text(clock.cityName)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .foregroundStyle(Color.primary)
                                
                                Spacer()
                                
                                // Time on the right
                                if let timeZone = TimeZone(identifier: clock.timeZoneIdentifier) {
                                    Text(formatTime(for: timeZone))
                                        .monospacedDigit()
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .allowsHitTesting(!isDisabled) // Disable interaction for same-as-local cities
                            .onTapGesture {
                                if !isDisabled {
                                    toggleCitySelection(clock.id)
                                }
                            }
                            .opacity(isDisabled ? 0.5 : 1.0)
                        }
                    }
                    // Overall List
                    .padding(.horizontal)
                }
            }
            
            // Navigation Title
            .navigationTitle("Flight Time")
            .navigationBarTitleDisplayMode(.inline)
            
            .scrollIndicators(.hidden)
            
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Only show confirm button if exactly 2 cities are selected
                    if selectedClocks.count == 2 {
                        Button(action: {
                            if hapticEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.prepare()
                                impactFeedback.impactOccurred()
                            }
                            // Set the selected cities for the flight line
                            selectedFlightCities = (from: selectedClocks[0], to: selectedClocks[1])
                            showSheet = false
                        }) {
                            Image(systemName: "checkmark")
                                .font(.headline)
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.yellow)
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        showSheet = false
                    }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
