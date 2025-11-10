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
    @State private var selectionOrder: [UUID] = [] // Track order of selection
    @State private var includeLocalTime = false
    @State private var localTimeOrder: Int? = nil // Track when local time was selected (1 or 2)
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showLocalTime") private var showLocalTimeInHome = true
    @AppStorage("customLocalName") private var customLocalName = ""
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    let currentDate: Date
    var onSelectionConfirm: ((WorldClock?, WorldClock?) -> Void)?
    
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
    
    // Get selected clocks for confirm button (in order: departure first, then arrival)
    var selectedClocks: [WorldClock] {
        var clocks: [WorldClock] = []
        
        // Determine which is departure and which is arrival
        if showLocalTimeInHome && includeLocalTime {
            if localTimeOrder == 1 {
                // Local time is departure
                clocks.append(localTimeAsClock)
                // Add the selected world clock as arrival
                if let firstSelectedId = selectionOrder.first,
                   let clock = worldClocks.first(where: { $0.id == firstSelectedId }) {
                    clocks.append(clock)
                }
            } else if localTimeOrder == 2 {
                // Local time is arrival
                // Add the selected world clock as departure
                if let firstSelectedId = selectionOrder.first,
                   let clock = worldClocks.first(where: { $0.id == firstSelectedId }) {
                    clocks.append(clock)
                }
                clocks.append(localTimeAsClock)
            }
        } else {
            // No local time, just use the selection order
            for clockId in selectionOrder {
                if let clock = worldClocks.first(where: { $0.id == clockId }) {
                    clocks.append(clock)
                }
            }
        }
        
        return clocks
    }
    
    // Check if a world clock is the same as local time
    func isClockSameAsLocal(_ clock: WorldClock) -> Bool {
        return clock.timeZoneIdentifier == TimeZone.current.identifier
    }
    
    // Get selection label for a clock
    func getSelectionLabel(for clockId: UUID) -> String? {
        guard selectedCities.contains(clockId) else { return nil }
        
        // Determine position based on selection order
        if let localOrder = localTimeOrder {
            if localOrder == 1 {
                // Local time is departure, this city is arrival
                return "Arrive"
            } else {
                // Local time is arrival
                if let index = selectionOrder.firstIndex(of: clockId), index == 0 {
                    return "Departure"
                }
                return nil
            }
        } else {
            // No local time selected
            if let index = selectionOrder.firstIndex(of: clockId) {
                return index == 0 ? "Departure" : "Arrive"
            }
        }
        return nil
    }
    
    // Get selection label for local time
    func getLocalTimeSelectionLabel() -> String? {
        guard includeLocalTime, let order = localTimeOrder else { return nil }
        return order == 1 ? "Departure" : "Arrive"
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
                // Remove from both set and order tracking
                selectedCities.remove(clockId)
                selectionOrder.removeAll { $0 == clockId }
                
                // If we removed the first selection and there's a second one, update local time order
                if localTimeOrder == 2 {
                    localTimeOrder = 1
                }
            } else {
                // Check if we already have 2 cities selected
                let totalSelected = selectedCities.count + (includeLocalTime ? 1 : 0)
                if totalSelected >= 2 {
                    // Need to deselect one
                    if includeLocalTime && selectedCities.count == 1 {
                        // Remove local time
                        includeLocalTime = false
                        localTimeOrder = nil
                        // The remaining city becomes departure
                    } else if !selectionOrder.isEmpty {
                        // Remove the first selected city
                        let firstSelected = selectionOrder.removeFirst()
                        selectedCities.remove(firstSelected)
                        // Update local time order if it was second
                        if localTimeOrder == 2 {
                            localTimeOrder = 1
                        }
                    }
                }
                selectedCities.insert(clockId)
                selectionOrder.append(clockId)
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
                // Store the order before clearing
                _ = localTimeOrder == 1
                includeLocalTime = false
                localTimeOrder = nil
                
                // If local time was first and there are other selections, they don't need updating
                // The first item in selectionOrder automatically becomes "Departure"
            } else {
                // Check if we already have 2 cities selected
                if selectedCities.count >= 2 {
                    // Need to deselect the first selected city
                    if !selectionOrder.isEmpty {
                        let firstSelected = selectionOrder.removeFirst()
                        selectedCities.remove(firstSelected)
                    }
                }
                includeLocalTime = true
                // Determine the order for local time
                localTimeOrder = selectedCities.isEmpty ? 1 : 2
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
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
                                // City name with label
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(customLocalName.isEmpty ? localCityName : customLocalName)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    
                                    if let label = getLocalTimeSelectionLabel() {
                                        Text(label)
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .transition(.blurReplace()) // Departure & Arrive Text
                                    }
                                }
                                
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
                                // City name with label
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(clock.cityName)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    
                                    
                                    if let label = getSelectionLabel(for: clock.id) {
                                        Text(label)
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .transition(.blurReplace()) // Departure & Arrive Text
                                    }
                                }
                                
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
                            // Set the selected cities for the flight line and center map if callback is provided
                            if let onSelectionConfirm = onSelectionConfirm {
                                onSelectionConfirm(selectedClocks[0], selectedClocks[1])
                            } else {
                                // Fallback to just setting the binding
                                selectedFlightCities = (from: selectedClocks[0], to: selectedClocks[1])
                            }
                            showSheet = false
                        }) {
                            Image(systemName: "checkmark")
                            //                                .font(.headline)
                            //                                .foregroundStyle(.black)
                        }
                        //                        .buttonStyle(.borderedProminent)
                        //                        .tint(.yellow)
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
