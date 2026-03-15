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
import SunKit

struct EarthView: View {
    private static let timeFormatterCache: NSCache<NSString, DateFormatter> = {
        let cache = NSCache<NSString, DateFormatter>()
        cache.countLimit = 50
        return cache
    }()
    private static let defaultMapSpan = MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)

    private static func systemTimeCenteredRegion() -> MKCoordinateRegion {
        let offsetHours = Double(TimeZone.current.secondsFromGMT(for: Date())) / 3600
        var longitude = (offsetHours * 15).truncatingRemainder(dividingBy: 360)

        if longitude > 180 {
            longitude -= 360
        } else if longitude < -180 {
            longitude += 360
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: longitude),
            span: defaultMapSpan
        )
    }

    @Binding var timeOffset: TimeInterval
    @Binding var worldClocks: [WorldClock]
    @ObservedObject var weatherManager: WeatherManager
    @State private var position = MapCameraPosition.region(Self.systemTimeCenteredRegion())
    @State private var lastKnownRegion = Self.systemTimeCenteredRegion()
    @State private var mapCenterCoordinate = Self.systemTimeCenteredRegion().center
    @State private var mapCenterTimeZoneSecondsFromGMT = TimeZone.current.secondsFromGMT(for: Date())
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
    @State private var showScrollTimeButtons = false
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
    @AppStorage("showWeather") private var showWeather = false
    @AppStorage("showSunCompass") private var showSunCompass = true
    
    @Environment(\.dismiss) private var dismiss
    
    // Namespace for Glass Effect morphing
    @Namespace private var glassEffectNamespace
    
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
        
        return displayDate.formattedDate(style: dateStyle, timeZone: targetTimeZone, relativeTo: currentDate)
    }

    private func weatherConditionForSky(at timeZoneIdentifier: String) -> WeatherCondition? {
        guard showWeather else { return nil }
        return weatherManager.weatherData[timeZoneIdentifier]?.condition
    }

    private var displayDate: Date {
        currentDate.addingTimeInterval(timeOffset)
    }

    // In 2D (explore) mode, disable pitch gestures so two-finger drag won't tilt into 3D.
    private var mapInteractionModes: MapInteractionModes {
        isUsingExploreMode ? [.pan, .zoom, .rotate] : .all
    }

    // MARK: - Sun Times Cache
    private struct MapSunTimesData {
        let sunrise: Date?
        let sunset: Date?
        let sunriseAzimuth: Double?
        let sunsetAzimuth: Double?
    }

    private class MapSunTimesDataWrapper {
        let data: MapSunTimesData
        init(_ data: MapSunTimesData) { self.data = data }
    }

    private static let mapSunTimesCache: NSCache<NSString, MapSunTimesDataWrapper> = {
        let cache = NSCache<NSString, MapSunTimesDataWrapper>()
        cache.countLimit = 120
        return cache
    }()

    private class MapSunAzimuthDataWrapper {
        let azimuth: Double?
        init(_ azimuth: Double?) { self.azimuth = azimuth }
    }

    private static let mapSunAzimuthCache: NSCache<NSString, MapSunAzimuthDataWrapper> = {
        let cache = NSCache<NSString, MapSunAzimuthDataWrapper>()
        cache.countLimit = 1_440
        return cache
    }()

    private static func mapCenterTimeZoneSeconds(from longitude: Double) -> Int {
        var normalizedLongitude = longitude.truncatingRemainder(dividingBy: 360)
        if normalizedLongitude > 180 {
            normalizedLongitude -= 360
        } else if normalizedLongitude < -180 {
            normalizedLongitude += 360
        }

        // Use a longitude-derived offset to avoid abrupt jumps from nearest-city timezone switching.
        let seconds = Int((normalizedLongitude / 15.0 * 3600.0).rounded())
        return min(max(seconds, -18 * 3600), 18 * 3600)
    }

    private var mapCenterTimeZone: TimeZone {
        TimeZone(secondsFromGMT: mapCenterTimeZoneSecondsFromGMT) ?? .gmt
    }

    private var mapCenterSunTimes: MapSunTimesData? {
        var calendar = Calendar.current
        calendar.timeZone = mapCenterTimeZone
        let components = calendar.dateComponents([.year, .month, .day], from: displayDate)
        let roundedLatitude = (mapCenterCoordinate.latitude * 100).rounded() / 100
        let roundedLongitude = (mapCenterCoordinate.longitude * 100).rounded() / 100
        let cacheKey = "\(mapCenterTimeZoneSecondsFromGMT)_earth_sun_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)_\(roundedLatitude)_\(roundedLongitude)" as NSString

        if let cached = Self.mapSunTimesCache.object(forKey: cacheKey) {
            return cached.data
        }

        var sun = Sun(
            location: CLLocation(latitude: mapCenterCoordinate.latitude, longitude: mapCenterCoordinate.longitude),
            timeZone: mapCenterTimeZone
        )
        sun.setDate(displayDate)

        let sunrise = sun.sunrise
        let sunset = sun.sunset
        sun.setDate(sunrise)
        let sunriseAzimuth = sun.azimuth.degrees
        sun.setDate(sunset)
        let sunsetAzimuth = sun.azimuth.degrees

        let data = MapSunTimesData(
            sunrise: sunrise,
            sunset: sunset,
            sunriseAzimuth: sunriseAzimuth,
            sunsetAzimuth: sunsetAzimuth
        )
        Self.mapSunTimesCache.setObject(MapSunTimesDataWrapper(data), forKey: cacheKey)
        return data
    }

    private func dateAt(hour: Int, minute: Int, in timeZone: TimeZone) -> Date? {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        var components = calendar.dateComponents([.year, .month, .day], from: displayDate)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }

    private func normalizedAzimuth(_ azimuth: Double?) -> Double? {
        guard let azimuth, azimuth.isFinite else { return nil }
        var normalized = azimuth.truncatingRemainder(dividingBy: 360)
        if normalized < 0 {
            normalized += 360
        }
        return normalized
    }

    private func sunAzimuth(for date: Date?, in timeZone: TimeZone) -> Double? {
        guard let date else { return nil }
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let minuteComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let roundedLatitude = (mapCenterCoordinate.latitude * 100).rounded() / 100
        let roundedLongitude = (mapCenterCoordinate.longitude * 100).rounded() / 100
        let cacheKey =
            "\(timeZone.identifier)_\(timeZone.secondsFromGMT(for: date))_azimuth_\(minuteComponents.year ?? 0)_\(minuteComponents.month ?? 0)_\(minuteComponents.day ?? 0)_\(minuteComponents.hour ?? 0)_\(minuteComponents.minute ?? 0)_\(roundedLatitude)_\(roundedLongitude)" as NSString

        if let cached = Self.mapSunAzimuthCache.object(forKey: cacheKey) {
            return cached.azimuth
        }

        var sun = Sun(
            location: CLLocation(latitude: mapCenterCoordinate.latitude, longitude: mapCenterCoordinate.longitude),
            timeZone: timeZone
        )
        sun.setDate(date)
        let azimuth = normalizedAzimuth(sun.azimuth.degrees)
        Self.mapSunAzimuthCache.setObject(MapSunAzimuthDataWrapper(azimuth), forKey: cacheKey)
        return azimuth
    }

    private var mapSolarAngles: (sunrise: Double, sunset: Double, currentSun: Double) {
        let timeZone = mapCenterTimeZone
        let sunTimes = mapCenterSunTimes
        let sunriseFallbackDate = dateAt(hour: 6, minute: 0, in: timeZone)
        let sunsetFallbackDate = dateAt(hour: 18, minute: 0, in: timeZone)

        return (
            sunrise: normalizedAzimuth(sunTimes?.sunriseAzimuth)
                ?? sunAzimuth(for: sunriseFallbackDate, in: timeZone)
                ?? 90,
            sunset: normalizedAzimuth(sunTimes?.sunsetAzimuth)
                ?? sunAzimuth(for: sunsetFallbackDate, in: timeZone)
                ?? 270,
            currentSun: sunAzimuth(for: displayDate, in: timeZone) ?? 180
        )
    }

    private func updateMapSolarReference(center: CLLocationCoordinate2D) {
        mapCenterCoordinate = center
        mapCenterTimeZoneSecondsFromGMT = Self.mapCenterTimeZoneSeconds(from: center.longitude)
    }

    private func toggleSunCompass() {
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }

        withAnimation(.spring()) {
            showSunCompass.toggle()
        }
    }

    private static func timeFormatter(for timeZone: TimeZone, use24Hour: Bool) -> DateFormatter {
        let key = "\(timeZone.identifier)_\(use24Hour)" as NSString
        if let cached = timeFormatterCache.object(forKey: key) {
            return cached
        }

        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mma"
        timeFormatterCache.setObject(formatter, forKey: key)
        return formatter
    }

    private func formattedTime(for timeZoneIdentifier: String) -> String {
        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return Self.timeFormatter(for: timeZone, use24Hour: use24HourFormat)
            .string(from: displayDate)
            .lowercased()
    }
    
    // Add to Calendar
    func addToCalendar(timeZoneIdentifier: String, cityName: String) {
        eventStore.requestFullAccessToEvents { granted, error in
            if granted && error == nil {
                DispatchQueue.main.async {
                    let event = EKEvent(eventStore: self.eventStore)
                    
                    let currentDate = self.displayDate
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
            .sink { now in
                let calendar = Calendar.current
                // The map only renders minute-level time, so avoid re-rendering all annotations every second.
                if calendar.component(.minute, from: now) != calendar.component(.minute, from: currentDate) {
                    currentDate = now
                }
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
                let ringAndControlsOffsetY: CGFloat = -20
            
                Map(position: $position, interactionModes: mapInteractionModes) {
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
                                            date: displayDate,
                                            timeZoneIdentifier: TimeZone.current.identifier,
                                            weatherCondition: weatherConditionForSky(at: TimeZone.current.identifier)
                                        )
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                .blendMode(.plusLighter)
                                        )
                                        .transition(.blurReplace)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Text(formattedTime(for: TimeZone.current.identifier))
                                        .font(.caption)
                                        .fontWeight(.bold)
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
                                            date: displayDate,
                                            timeZoneIdentifier: clock.timeZoneIdentifier,
                                            weatherCondition: weatherConditionForSky(at: clock.timeZoneIdentifier)
                                        )
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                .blendMode(.plusLighter)
                                        )
                                        .transition(.blurReplace)
                                    }
                                    
                                    Text(formattedTime(for: clock.timeZoneIdentifier))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                    .animation(.spring(), value: currentDate)
                                }
                                .animation(.spring(), value: showSkyDot)
                                .padding(.leading, showSkyDot ? 4 : 8)
                                .padding(.trailing, 8)
                                .padding(.vertical, 4)
                                .clipShape(Capsule())
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
                                                CollectionsStore.removeCity(withId: clock.id)
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
            .onMapCameraChange(frequency: .continuous) { context in
                lastKnownRegion = context.region
                updateMapSolarReference(center: context.region.center)
            }
            .onChange(of: isUsingExploreMode) { _, isExploreMode in
                guard isExploreMode else { return }
                withAnimation(.smooth(duration: 0.25)) {
                    // Force a flat camera when entering 2D mode.
                    position = .region(lastKnownRegion)
                }
            }

            if isUsingExploreMode && showSunCompass {
                GeometryReader { geometry in
                    let analogClockSize = min(geometry.size.width, geometry.size.height)
                    let ringDiameter = max(analogClockSize - 24, 0)
                    let ringWidth: CGFloat = 32
                    let lineRadius = max((ringDiameter / 2) - (ringWidth / 2), 0)
                    let angles = mapSolarAngles

                    ZStack {
                        // External Circle
                        Circle()
                            .glassEffect(.clear.tint(.black.opacity(0.75)))
                            .mask {
                                Circle()
                                    .stroke(style: StrokeStyle(lineWidth: ringWidth))
                            }
                            .overlay { // Internal Border
                                Circle()
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    .frame(
                                        width: max(ringDiameter - ringWidth, 0),
                                        height: max(ringDiameter - ringWidth, 0)
                                    )
                                    .blendMode(.plusLighter)
                            }

                        EarthCompassLabelsView(
                            diameter: ringDiameter,
                            ringWidth: ringWidth
                        )

                        EarthSolarLineView(
                            angle: angles.sunrise,
                            diameter: ringDiameter,
                            radius: lineRadius,
                            color: Color.white.opacity(0.50)
                        )

                        EarthSolarLineView(
                            angle: angles.sunset,
                            diameter: ringDiameter,
                            radius: lineRadius,
                            color: Color.white.opacity(0.50)
                        )

                        EarthSolarLineView(
                            angle: angles.currentSun,
                            diameter: ringDiameter,
                            radius: lineRadius,
                            color: .white,
                            lineWidth: 2.5,
                            endpointSize: 16,
                            disableAnimation: false
                        )

                        // Center Point
                        Circle()
                            .fill(.white)
                            .frame(width: 8, height: 8)
                    }
                    .frame(width: ringDiameter, height: ringDiameter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                }
                .offset(y: ringAndControlsOffsetY)
            }

            // Bottom Controls - Hide when renaming
            if !showingRenameAlert {
                VStack(spacing: 8) {
                    if !(worldClocks.isEmpty && !showLocalTime) {
                        ScrollTimeView(
                            timeOffset: $timeOffset,
                            showButtons: $showScrollTimeButtons,
                            worldClocks: $worldClocks
                        )
                        .padding(.horizontal)
                        .transition(.blurReplace())
                    }

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

                                // Sun Compass Toggle Button - Only show in 2D mode
                                if isUsingExploreMode {
                                    Button(action: {
                                        toggleSunCompass()
                                    }) {
                                        Image(systemName: showSunCompass ? "safari.fill" : "safari")
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
                    .transition(.blurReplace())
                }
                .padding(.bottom, 8)
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
        .animation(.spring(), value: worldClocks)
        .animation(.spring(), value: isUsingExploreMode)
        .animation(.spring(), value: showMapLabels)
        .animation(.spring(), value: showSunCompass)
        .animation(.spring(), value: showingRenameAlert)
        .animation(.spring(), value: selectedFlightCities.from)
        .animation(.spring(), value: selectedFlightCities.to)
            
        .task {
            currentDate = Date()
            startTimer()
            updateMapSolarReference(center: mapCenterCoordinate)
        }
        // Fetch weather for sky gradient (rain-aware)
        .task(id: "\(showSkyDot)-\(showWeather)") {
            if showSkyDot && showWeather {
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
                
                ToolbarItemGroup(placement: .topBarLeading) {
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
                    timeOffset: timeOffset
                )
                .environmentObject(weatherManager)
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
                        CollectionsStore.renameCity(withId: clockId, to: nameToSave)
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
                    timeOffset: timeOffset
                )
                .environmentObject(weatherManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
            }
        }
    }  
}

private struct EarthSolarLineView: View {
    let angle: Double
    let diameter: CGFloat
    let radius: CGFloat
    let color: Color
    var lineWidth: CGFloat = 1.50
    var endpointSize: CGFloat = 0
    var disableAnimation: Bool = true

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let endPoint = CGPoint(
                x: center.x,
                y: center.y - radius
            )

            var linePath = Path()
            linePath.move(to: center)
            linePath.addLine(to: endPoint)
            context.stroke(
                linePath,
                with: .color(color),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )

            if endpointSize > 0 {
                let circleRect = CGRect(
                    x: endPoint.x - endpointSize / 2,
                    y: endPoint.y - endpointSize / 2,
                    width: endpointSize,
                    height: endpointSize
                )
                context.fill(Path(ellipseIn: circleRect), with: .color(color))
            }
        }
        .frame(width: diameter, height: diameter)
        .rotationEffect(.degrees(angle))
        .transaction { transaction in
            if disableAnimation {
                transaction.animation = nil
            }
        }
    }
}

private struct EarthCompassLabelsView: View {
    let diameter: CGFloat
    let ringWidth: CGFloat

    private let directions: [(label: String, angle: Double, rotation: Double)] = [
        ("N", 0, 0),
        ("NE", 45, 45),
        ("E", 90, 0),
        ("SE", 135, -45),
        ("S", 180, 0),
        ("SW", 225, 45),
        ("W", 270, 0),
        ("NW", 315, -45)
    ]

    var body: some View {
        let labelOffset: CGFloat = 8
        let radius = max((diameter / 2) - (ringWidth / 2) + labelOffset, 0)
        let center = CGPoint(x: diameter / 2, y: diameter / 2)

        ZStack {
            ForEach(directions, id: \.label) { direction in
                let angleRadians = (direction.angle - 90) * .pi / 180
                let position = CGPoint(
                    x: center.x + radius * CGFloat(cos(angleRadians)),
                    y: center.y + radius * CGFloat(sin(angleRadians))
                )

                Text(direction.label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize()
                    .rotationEffect(.degrees(direction.rotation))
                    .position(x: position.x, y: position.y)
            }
        }
        .frame(width: diameter, height: diameter)
    }
}
