//
//  EarthView.swift
//  touchtime
//
//  Created on 02/10/2025.
//

import SwiftUI
import MapKit
import Combine
import UIKit
import EventKit
import EventKitUI
import CoreLocation
import WeatherKit

struct EarthView: View {
    @Binding var worldClocks: [WorldClock]
    @State private var position = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
    ))
    @State private var currentDate = Date()
    @State private var timerCancellable: AnyCancellable?
    @State private var showShareSheet = false
    @State private var showingRenameAlert = false
    @State private var renamingClockId: UUID? = nil
    @State private var newClockName = ""
    @State private var originalClockName = ""
    @State private var eventStore = EKEventStore()
    @State private var showEventEditor = false
    @State private var eventToEdit: EKEvent?
    @State private var showMapMenu = false
    @State private var showFlightTimeSheet = false
    @State private var selectedFlightCities: (from: WorldClock?, to: WorldClock?) = (nil, nil)
    @State private var showSunriseSunsetSheet = false
    @State private var selectedCityName: String = ""
    @State private var selectedTimeZoneIdentifier: String = ""
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("isUsingExploreMode") private var isUsingExploreMode = false
    @AppStorage("showSkyDot") private var showSkyDot = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("defaultEventDuration") private var defaultEventDuration: Double = 3600
    @AppStorage("selectedCalendarIdentifier") private var selectedCalendarIdentifier: String = ""
    @AppStorage("showLocalTime") private var showLocalTime = true
    @AppStorage("customLocalName") private var customLocalName = ""
    @AppStorage("showMapLabels") private var showMapLabels = true // 默认显示地图标签
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    
    @StateObject private var weatherManager = WeatherManager()
    @Environment(\.dismiss) private var dismiss
    
    // Namespace for Glass Effect morphing
    @Namespace private var glassEffectNamespace
    
    // 設置地圖縮放限制
    private let cameraBounds = MapCameraBounds(
        minimumDistance: 5000000,     // 最小高度 1,000km（最大放大）
        maximumDistance: nil
    )
    
    // Get local city name from timezone
    var localCityName: String {
        let identifier = TimeZone.current.identifier
        let components = identifier.split(separator: "/")
        let cityName: String
        if components.count >= 2 {
            cityName = components.last!.replacingOccurrences(of: "_", with: " ")
        } else {
            cityName = identifier
        }
        // Return localized city name
        return String(localized: String.LocalizationValue(cityName))
    }
    
    // Convert timezone identifier to coordinate using shared utility
    func getCoordinate(for timeZoneIdentifier: String) -> CLLocationCoordinate2D? {
        if let coords = TimeZoneCoordinates.getCoordinate(for: timeZoneIdentifier) {
            return CLLocationCoordinate2D(latitude: coords.latitude, longitude: coords.longitude)
        }
        return nil
    }
    
    // Get formatted date for menu section header
    func getMenuDateHeader(for timeZoneIdentifier: String) -> String {
        guard let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return ""
        }
        
        return currentDate.formattedDate(style: dateStyle, timeZone: targetTimeZone)
    }
    
    // Add to Calendar
    func addToCalendar(timeZoneIdentifier: String, cityName: String) {
        eventStore.requestFullAccessToEvents { granted, error in
            if granted && error == nil {
                DispatchQueue.main.async {
                    let event = EKEvent(eventStore: self.eventStore)
                    
                    let currentDate = Date()
                    let formatter = DateFormatter()
                    formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    
                    let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
                    
                    event.startDate = currentDate
                    event.endDate = currentDate.addingTimeInterval(self.defaultEventDuration)
                    
                    if !self.selectedCalendarIdentifier.isEmpty,
                       let selectedCalendar = self.eventStore.calendars(for: .event).first(where: { $0.calendarIdentifier == self.selectedCalendarIdentifier }) {
                        event.calendar = selectedCalendar
                    } else {
                        event.calendar = self.eventStore.defaultCalendarForNewEvents
                    }
                    
                    formatter.timeZone = targetTimeZone
                    if self.use24HourFormat {
                        formatter.dateFormat = "HH:mm"
                    } else {
                        formatter.dateFormat = "h:mm a"
                    }
                    let timeString = formatter.string(from: currentDate)
                    
                    // Format date - use different format for Chinese locale
                    formatter.locale = Locale.current
                    if Locale.current.language.languageCode?.identifier == "zh" {
                        formatter.dateFormat = "MMMd日 E"
                    } else {
                        formatter.dateFormat = "E, d MMM"
                    }
                    let dateString = formatter.string(from: currentDate)
                    
                    // Reset locale for next iteration
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    
                    event.notes = String(format: String(localized: "Time in %@: %@ · %@"), cityName, timeString, dateString)
                    
                    self.eventToEdit = event
                    self.showEventEditor = true
                }
            } else {
                print("Calendar access denied or error: \(String(describing: error))")
                if self.hapticEnabled {
                    DispatchQueue.main.async {
                        let impactFeedback = UINotificationFeedbackGenerator()
                        impactFeedback.prepare()
                        impactFeedback.notificationOccurred(.warning)
                    }
                }
            }
        }
    }
    
    // Save world clocks to UserDefaults
    func saveWorldClocks() {
        if let encoded = try? JSONEncoder().encode(worldClocks) {
            UserDefaults.standard.set(encoded, forKey: "savedWorldClocks")
        }
    }
    
    // Calculate flight time between two timezones
    func calculateFlightTime(from fromTimeZone: TimeZone, to toTimeZone: TimeZone) -> String {
        // Get coordinates for both timezones
        guard let fromCoords = TimeZoneCoordinates.getCoordinate(for: fromTimeZone.identifier),
              let toCoords = TimeZoneCoordinates.getCoordinate(for: toTimeZone.identifier) else {
            return "N/A"
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
    
    // Start the timer
    func startTimer() {
        // Immediately update the current date
        currentDate = Date()
        
        // Cancel any existing timer
        timerCancellable?.cancel()
        
        // Create a new timer
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                currentDate = Date()
            }
    }
    
    // Stop the timer
    func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    // Calculate geodesic midpoint between two coordinates
    func calculateGeodesicMidpoint(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let midLat = (from.latitude + to.latitude) / 2
        
        // Handle longitude wrapping for International Date Line
        var lon1 = from.longitude
        var lon2 = to.longitude
        
        // If the difference is greater than 180, we're crossing the date line
        if abs(lon2 - lon1) > 180 {
            // Adjust the western longitude to be on the same "side" for averaging
            if lon1 < 0 {
                lon1 += 360
            } else {
                lon2 += 360
            }
        }
        
        var midLon = (lon1 + lon2) / 2
        
        // Normalize back to -180 to 180 range
        if midLon > 180 {
            midLon -= 360
        } else if midLon < -180 {
            midLon += 360
        }
        
        return CLLocationCoordinate2D(latitude: midLat, longitude: midLon)
    }
    
    // Set flight cities and center map on flight path
    func setFlightCitiesAndCenter(from: WorldClock?, to: WorldClock?) {
        selectedFlightCities = (from, to)
        
        // Center map on flight path midpoint if both cities are selected
        if let fromClock = from,
           let toClock = to,
           let fromCoord = getCoordinate(for: fromClock.timeZoneIdentifier),
           let toCoord = getCoordinate(for: toClock.timeZoneIdentifier) {
            
            // Calculate the midpoint of the great circle route
            let flightPath = calculateGreatCircleRoute(from: fromCoord, to: toCoord, segments: 50)
            let midpointIndex = flightPath.count / 2
            let midCoord = flightPath[midpointIndex]
            
            // Animate camera to center on the flight path midpoint
            withAnimation(.spring()) {
                position = MapCameraPosition.region(MKCoordinateRegion(
                    center: midCoord,
                    span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
                ))
            }
        }
    }
    
    // Calculate great circle route between two coordinates
    func calculateGreatCircleRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, segments: Int = 100) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        
        // Convert degrees to radians
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        
        // Calculate the great circle distance
        let dLon = lon2 - lon1
        let a = sin((lat2 - lat1) / 2) * sin((lat2 - lat1) / 2) +
                cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        // Generate intermediate points along the great circle
        for i in 0...segments {
            let fraction = Double(i) / Double(segments)
            
            // Calculate intermediate point using spherical interpolation
            let A = sin((1 - fraction) * c) / sin(c)
            let B = sin(fraction * c) / sin(c)
            
            let x = A * cos(lat1) * cos(lon1) + B * cos(lat2) * cos(lon2)
            let y = A * cos(lat1) * sin(lon1) + B * cos(lat2) * sin(lon2)
            let z = A * sin(lat1) + B * sin(lat2)
            
            let lat = atan2(z, sqrt(x * x + y * y))
            let lon = atan2(y, x)
            
            // Convert back to degrees
            let latDeg = lat * 180 / .pi
            let lonDeg = lon * 180 / .pi
            
            coordinates.append(CLLocationCoordinate2D(latitude: latDeg, longitude: lonDeg))
        }
        
        return coordinates
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
            
                Map(position: $position, bounds: cameraBounds) {
                // Show flight path if two cities are selected
                if let fromClock = selectedFlightCities.from,
                   let toClock = selectedFlightCities.to,
                   let fromCoord = getCoordinate(for: fromClock.timeZoneIdentifier),
                   let toCoord = getCoordinate(for: toClock.timeZoneIdentifier) {
                    
                    // Calculate great circle route for realistic flight path
                    let flightPath = calculateGreatCircleRoute(from: fromCoord, to: toCoord, segments: 50)
                    
                    // Create curved flight path
                    MapPolyline(coordinates: flightPath)
                        .stroke(Color.yellow, lineWidth: 2.5)
                        .strokeStyle(style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        
                        
                    // Show flight time at midpoint of the great circle route
                    let midpointIndex = flightPath.count / 2
                    let midCoord = flightPath[midpointIndex]
                    
                    // Determine if airplane should face left or right
                    let shouldFaceLeft: Bool = {
                        // Handle longitude wrapping for International Date Line
                        var lon1 = fromCoord.longitude
                        var lon2 = toCoord.longitude
                        
                        // If the difference is greater than 180, we're crossing the date line
                        if abs(lon2 - lon1) > 180 {
                            // Adjust the western longitude to be on the same "side"
                            if lon1 < 0 {
                                lon1 += 360
                            } else {
                                lon2 += 360
                            }
                        }
                        
                        // If destination is west of origin (smaller longitude), face left
                        return lon2 < lon1
                    }()
                    
                    Annotation("", coordinate: midCoord) {
                        if let fromTimeZone = TimeZone(identifier: fromClock.timeZoneIdentifier),
                           let toTimeZone = TimeZone(identifier: toClock.timeZoneIdentifier) {
                            
                                HStack(spacing: 6) {
                                    
                                    Image(systemName: "airplane")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.yellow)
                                        .scaleEffect(x: shouldFaceLeft ? -1 : 1, y: 1)
                                    
                                    Text(calculateFlightTime(from: fromTimeZone, to: toTimeZone))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .fontDesign(.rounded)
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.25))
                                        .glassEffect(.clear)
                                )
                        }
                    }
                }
                // Show local time marker
                if showLocalTime {
                    // Check if we should show local time based on flight selection
                    let shouldShowLocalTime = selectedFlightCities.from == nil || selectedFlightCities.to == nil ||
                        (selectedFlightCities.from?.timeZoneIdentifier == TimeZone.current.identifier ||
                         selectedFlightCities.to?.timeZoneIdentifier == TimeZone.current.identifier)
                    
                    if shouldShowLocalTime,
                       let coordinate = getCoordinate(for: TimeZone.current.identifier) {
                        Annotation(String(localized: "Local"), coordinate: coordinate) {
                            VStack(spacing: 6) {
                                // Time bubble with SkyDot - wrapped in contextMenu
                                HStack(spacing: 8) {
                                    
                                    if showSkyDot {
                                        SkyDotView(
                                            date: currentDate,
                                            timeZoneIdentifier: TimeZone.current.identifier,
                                            weatherCondition: weatherManager.weatherData[TimeZone.current.identifier]?.condition
                                        )
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                .blendMode(.plusLighter)
                                        )
                                        .transition(.blurReplace)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Text({
                                            let formatter = DateFormatter()
                                            formatter.timeZone = TimeZone.current
                                            formatter.locale = Locale(identifier: "en_US_POSIX")
                                            if use24HourFormat {
                                                formatter.dateFormat = "HH:mm"
                                            } else {
                                                formatter.dateFormat = "h:mma"
                                            }
                                            return formatter.string(from: currentDate).lowercased()
                                        }())
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .fontDesign(.rounded)
                                        .foregroundStyle(.white)
                                        .monospacedDigit()
                                        .contentTransition(.numericText())
                                        .animation(.spring(), value: currentDate)
                                        
                                        Image(systemName: "location.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.white)
                                    }

                                }
                                .animation(.spring(), value: showSkyDot)
                                
                                // Overall Paddings
                                .padding(.leading, showSkyDot ? 4 : 8)
                                .padding(.trailing, 8)
                                .padding(.vertical, 4)
                                .clipShape(Capsule())
//                                    .glassEffect(.clear.interactive())
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.25))
                                        .glassEffect(.clear.interactive())
                                )
                                .onTapGesture {
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                        impactFeedback.prepare()
                                        impactFeedback.impactOccurred()
                                    }
                                    selectedCityName = String(localized: "Local")
                                    selectedTimeZoneIdentifier = TimeZone.current.identifier
                                    showSunriseSunsetSheet = true
                                }
                                .contextMenu {
                                    Section(getMenuDateHeader(for: TimeZone.current.identifier)) {
                                        Button(action: {
                                            let cityName = String(localized: "Local")
                                            addToCalendar(timeZoneIdentifier: TimeZone.current.identifier, cityName: cityName)
                                        }) {
                                            Label(String(localized: "Schedule Event"), systemImage: "calendar.badge.plus")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Show world clock markers
                ForEach(worldClocks) { clock in
                    // Check if we should show this clock based on flight selection
                    let shouldShowClock = selectedFlightCities.from == nil || selectedFlightCities.to == nil ||
                        (clock.id == selectedFlightCities.from?.id || clock.id == selectedFlightCities.to?.id)
                    
                    // Skip if this clock has the same timezone as local time and local time is shown
                    if showLocalTime && clock.timeZoneIdentifier == TimeZone.current.identifier {
                        // Don't show duplicate of local time
                    } else if shouldShowClock, let coordinate = getCoordinate(for: clock.timeZoneIdentifier) {
                        Annotation(clock.localizedCityName, coordinate: coordinate) {
                            
                            VStack(spacing: 6) {
                                // Time bubble with SkyDot - wrapped in contextMenu
                                HStack(spacing: 8) {
                                    if showSkyDot {
                                        SkyDotView(
                                            date: currentDate,
                                            timeZoneIdentifier: clock.timeZoneIdentifier,
                                            weatherCondition: weatherManager.weatherData[clock.timeZoneIdentifier]?.condition
                                        )
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                .blendMode(.plusLighter)
                                        )
                                        .transition(.blurReplace)
                                    }
                                    
                                    Text({
                                        let formatter = DateFormatter()
                                        formatter.timeZone = TimeZone(identifier: clock.timeZoneIdentifier)
                                        formatter.locale = Locale(identifier: "en_US_POSIX")
                                        if use24HourFormat {
                                            formatter.dateFormat = "HH:mm"
                                        } else {
                                            formatter.dateFormat = "h:mma"
                                        }
                                        return formatter.string(from: currentDate).lowercased()
                                    }())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .fontDesign(.rounded)
                                    .foregroundColor(.white)
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                    .animation(.spring(), value: currentDate)
                                }
                                .animation(.spring(), value: showSkyDot)
                                .padding(.leading, showSkyDot ? 4 : 8)
                                .padding(.trailing, 8)
                                .padding(.vertical, 4)
                                .clipShape(Capsule())
//                                    .glassEffect(.clear.interactive())
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.25))
                                        .glassEffect(.clear.interactive())
                                )
                                .onTapGesture {
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                        impactFeedback.prepare()
                                        impactFeedback.impactOccurred()
                                    }
                                    selectedCityName = clock.localizedCityName
                                    selectedTimeZoneIdentifier = clock.timeZoneIdentifier
                                    showSunriseSunsetSheet = true
                                }
                                .contextMenu {
                                    Section(getMenuDateHeader(for: clock.timeZoneIdentifier)) {
                                        Button(action: {
                                            addToCalendar(timeZoneIdentifier: clock.timeZoneIdentifier, cityName: clock.localizedCityName)
                                        }) {
                                            Label(String(localized: "Schedule Event"), systemImage: "calendar.badge.plus")
                                        }
           
                                        Button(action: {
                                            renamingClockId = clock.id
                                            let identifier = clock.timeZoneIdentifier
                                            let components = identifier.split(separator: "/")
                                            let rawName = components.count >= 2
                                                ? String(components.last!).replacingOccurrences(of: "_", with: " ")
                                                : String(identifier)
                                            originalClockName = String(localized: String.LocalizationValue(rawName))
                                            newClockName = clock.localizedCityName
                                            showingRenameAlert = true
                                        }) {
                                            Label(String(localized: "Rename"), systemImage: "pencil.tip.crop.circle")
                                        }
                                        
                                        Divider()
                                        
                                        Button(role: .destructive, action: {
                                            if let index = worldClocks.firstIndex(where: { $0.id == clock.id }) {
                                                withAnimation {
                                                    worldClocks.remove(at: index)
                                                    saveWorldClocks()
                                                }
                                            }
                                        }) {
                                            Label("Delete", systemImage: "xmark.circle")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .mapStyle(isUsingExploreMode ? 
                (showMapLabels ? .standard(elevation: .realistic, pointsOfInterest: .all, showsTraffic: false) : .standard(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: false)) :
                (showMapLabels ? .hybrid(elevation: .realistic, pointsOfInterest: .all, showsTraffic: false) : .imagery(elevation: .realistic))
            )
            .mapControls {
                MapCompass()
            }
            // Bottom Control Bar - Hide when renaming
            if !showingRenameAlert {
                GlassEffectContainer(spacing: 8.0) {
                    HStack(spacing: 8) {
                        // Group of main buttons
                        HStack(spacing: 0) {
                            // Back to Local Time Button - Only show when local time is enabled and flight time is not active
                            if showLocalTime && !(selectedFlightCities.from != nil && selectedFlightCities.to != nil) {
                                Button(action: {
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                        impactFeedback.prepare()
                                        impactFeedback.impactOccurred()
                                    }
                                    
                                    // Navigate to local time location
                                    if let localCoordinate = getCoordinate(for: TimeZone.current.identifier) {
                                        withAnimation(.smooth()) {
                                            position = MapCameraPosition.region(MKCoordinateRegion(
                                                center: localCoordinate,
                                                span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
                                            ))
                                        }
                                    }
                                }) {
                                    Image(systemName: "location.fill")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .frame(width: 52, height: 52)
                                }
                            }
                            
                            // Map Mode Toggle Button
                            Button(action: {
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                    impactFeedback.prepare()
                                    impactFeedback.impactOccurred()
                                }
                                
                                withAnimation(.spring()) {
                                    isUsingExploreMode.toggle()
                                }
                            }) {
                                Image(systemName: isUsingExploreMode ? "view.2d" : "view.3d")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 52, height: 52)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            
                            // Map Labels Toggle Button - Only show in 2D mode (standard map)
                            if !isUsingExploreMode {
                                Button(action: {
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                        impactFeedback.prepare()
                                        impactFeedback.impactOccurred()
                                    }
                                    
                                    withAnimation(.spring()) {
                                        showMapLabels.toggle()
                                    }
                                }) {
                                    Image(systemName: showMapLabels ? "square.2.layers.3d.fill" : "square.2.layers.3d")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .frame(width: 52, height: 52)
                                        .contentTransition(.symbolEffect(.replace))
                                }
                                .transition(.blurReplace().combined(with: .scale).combined(with: .opacity))
                            }
                        }
                        .glassEffect(.regular)
                        .glassEffectID("mapButtonGroup", in: glassEffectNamespace)
                        .glassEffectTransition(.matchedGeometry)
                        
                        
                        // Clear Flight Path Button - Show when flight path is active (placed on the right)
                        if selectedFlightCities.from != nil && selectedFlightCities.to != nil {
                            Button(action: {
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                    impactFeedback.prepare()
                                    impactFeedback.impactOccurred()
                                }
                                
                                withAnimation(.spring()) {
                                    setFlightCitiesAndCenter(from: nil, to: nil)
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.headline)
                                    .foregroundStyle(.yellow)
                                    .frame(width: 52, height: 52)
                            }
                            .glassEffect(.regular.tint(.yellow.opacity(0.15)).interactive())
                            .glassEffectID("clearFlightButton", in: glassEffectNamespace)
                            .glassEffectTransition(.matchedGeometry)
                        }
                    }
                }
                .padding(.bottom, 8)
                .transition(.blurReplace())
            }
                
                // Empty state - on top of map
                if worldClocks.isEmpty && !showLocalTime {
                    HStack {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.subheadline.weight(.medium))
                        Text(String(localized: "Nothing here"))
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .glassEffect(.regular.interactive())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                }
        }
//            // Title
//            .navigationTitle("Touch Time")
//            .navigationBarTitleDisplayMode(.inline)
            
        .animation(.spring(), value: worldClocks)
        .animation(.spring(), value: isUsingExploreMode)
        .animation(.spring(), value: showMapLabels)
        .animation(.spring(), value: showingRenameAlert)
        .animation(.spring(), value: selectedFlightCities.from)
        .animation(.spring(), value: selectedFlightCities.to)
            
        .task {
            currentDate = Date()
            startTimer()
        }
        // Fetch weather for sky gradient (rain-aware)
        .task(id: showSkyDot) {
            if showSkyDot {
                await weatherManager.getWeather(for: TimeZone.current.identifier)
                for clock in worldClocks {
                    await weatherManager.getWeather(for: clock.timeZoneIdentifier)
                }
            }
        }
        .onDisappear {
            stopTimer()
        }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.prepare()
                            impactFeedback.impactOccurred()
                        }
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    // Flight Time button - Only show when no flight path is active and there are cities
                    if (selectedFlightCities.from == nil || selectedFlightCities.to == nil) && !worldClocks.isEmpty {
                        Button(action: {
                            if hapticEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.prepare()
                                impactFeedback.impactOccurred()
                            }
                            showFlightTimeSheet = true
                        }) {
                            Image(systemName: "airplane.up.right")
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareCitiesSheet(
                    worldClocks: $worldClocks,
                    showSheet: $showShareSheet,
                    currentDate: currentDate,
                    timeOffset: 0
                )
            }
            .sheet(isPresented: $showFlightTimeSheet) {
                FlightTimeSheet(
                    worldClocks: $worldClocks,
                    showSheet: $showFlightTimeSheet,
                    selectedFlightCities: $selectedFlightCities,
                    currentDate: currentDate,
                    onSelectionConfirm: setFlightCitiesAndCenter
                )
            }
            
            // Rename Alert
            .alert(String(localized: "Rename"), isPresented: $showingRenameAlert) {
                TextField(originalClockName, text: $newClockName)
                Button(String(localized: "Cancel"), role: .cancel) {
                    newClockName = ""
                    originalClockName = ""
                    renamingClockId = nil
                }
                Button(String(localized: "Save")) {
                    let nameToSave = newClockName.isEmpty ? originalClockName : newClockName
                    
                    if let clockId = renamingClockId,
                       let index = worldClocks.firstIndex(where: { $0.id == clockId }) {
                        // Renaming a world clock
                        worldClocks[index].cityName = nameToSave
                        saveWorldClocks()
                    }
                    newClockName = ""
                    originalClockName = ""
                    renamingClockId = nil
                }
            } message: {
                Text("Customize the name of this city")
            }
            
            // Event Editor Sheet
            .sheet(isPresented: $showEventEditor) {
                EventEditView(
                    event: $eventToEdit,
                    isPresented: $showEventEditor,
                    eventStore: eventStore
                )
                .ignoresSafeArea()
            }
            
            // Sunrise/Sunset Sheet
            .sheet(isPresented: $showSunriseSunsetSheet) {
                SunriseSunsetSheet(
                    cityName: selectedCityName,
                    timeZoneIdentifier: selectedTimeZoneIdentifier,
                    initialDate: currentDate,
                    timeOffset: 0
                )
                .environmentObject(weatherManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
            }
        }
    }  
}
