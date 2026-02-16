//
//  ShareCitiesSheet.swift
//  touchtime
//
//  Created on 27/09/2025.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WeatherKit

// Lazy card image for deferred rendering (Share as Image)
private struct ShareLazyCardImage: Transferable {
    let render: () -> UIImage
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { lazy in
            let image = lazy.render()
            guard let data = image.pngData() else {
                throw CocoaError(.fileWriteUnknown)
            }
            return data
        }
    }
}

struct ShareCitiesSheet: View {
    @Binding var worldClocks: [WorldClock]
    @Binding var showSheet: Bool
    @State private var selectedCities: Set<UUID> = []
    @State private var showLocalTime = false
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showLocalTime") private var showLocalTimeInHome = true
    @AppStorage("customLocalName") private var customLocalName = ""
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("showSkyDot") private var showSkyDot = true
    @AppStorage("showAnalogClock") private var showAnalogClock = false
    @AppStorage("analogClockShowScale") private var analogClockShowScale = false
    @AppStorage("showSunPosition") private var showSunPosition = false
    @AppStorage("showWeatherCondition") private var showWeatherCondition = false
    @AppStorage("showSunAzimuth") private var showSunAzimuth = false
    @AppStorage("showSunriseSunset") private var showSunriseSunset = false
    @AppStorage("showDaylight") private var showDaylight = false
    @AppStorage("showSolarCurve") private var showSolarCurve = false
    @AppStorage("additionalTimeDisplay") private var additionalTimeDisplay = "None"
    
    @EnvironmentObject private var weatherManager: WeatherManager
    
    let currentDate: Date
    let timeOffset: TimeInterval
    
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
        
        let adjustedDate = currentDate.addingTimeInterval(timeOffset)
        return formatter.string(from: adjustedDate).lowercased()
    }
    
    // Generate share text
    func generateShareText() -> String {
        var shareLines: [String] = []
        
        // Add local time if selected and shown in home
        if showLocalTimeInHome && showLocalTime {
            let localName = String(localized: "Local")
            let localTime = formatTime(for: TimeZone.current)
            shareLines.append("\(localName) \(localTime)")
        }
        
        // Add selected world clocks
        for clock in worldClocks {
            if selectedCities.contains(clock.id) {
                if let timeZone = TimeZone(identifier: clock.timeZoneIdentifier) {
                    let time = formatTime(for: timeZone)
                    shareLines.append("\(clock.localizedCityName) \(time)")
                }
            }
        }
        
        return shareLines.joined(separator: "\n")
    }
    
    // Check if all cities are selected
    var allCitiesSelected: Bool {
        let allWorldClocksSelected = worldClocks.allSatisfy { selectedCities.contains($0.id) }
        let localTimeSelected = !showLocalTimeInHome || showLocalTime
        return allWorldClocksSelected && localTimeSelected
    }
    
    // Single selection: exactly one city OR only Local
    var isSingleSelection: Bool {
        let hasLocal = showLocalTimeInHome && showLocalTime
        let cityCount = selectedCities.count
        return (hasLocal && cityCount == 0) || (!hasLocal && cityCount == 1)
    }
    
    // Info for single selection (cityName, timeZoneIdentifier)
    var singleSelectionInfo: (cityName: String, timeZoneIdentifier: String)? {
        if showLocalTimeInHome && showLocalTime && selectedCities.isEmpty {
            return (String(localized: "Local"), TimeZone.current.identifier)
        }
        if selectedCities.count == 1,
           let clockId = selectedCities.first,
           let clock = worldClocks.first(where: { $0.id == clockId }) {
            return (clock.localizedCityName, clock.timeZoneIdentifier)
        }
        return nil
    }
    
    // Get formatted date for city card
    func getCityDate(timeZoneIdentifier: String) -> String {
        guard let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) else { return "" }
        let adjustedTime = currentDate.addingTimeInterval(timeOffset)
        return adjustedTime.formattedDate(style: dateStyle, timeZone: targetTimeZone, relativeTo: currentDate)
    }
    
    // Copy time as text
    func copyTimeAsText() {
        UIPasteboard.general.string = generateShareText()
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }
    
    // Render city card as image for sharing
    func renderCardImage(cityName: String, timeZoneIdentifier: String) -> CardImage {
        let adjustedDate = currentDate.addingTimeInterval(timeOffset)
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if use24HourFormat {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm"
        }
        let timeString = formatter.string(from: adjustedDate)
        let dateString = getCityDate(timeZoneIdentifier: timeZoneIdentifier)
        let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
        
        let clock = WorldClock(cityName: cityName, timeZoneIdentifier: timeZoneIdentifier)
        let additionalText = additionalTimeDisplay == "Time Difference" ? clock.timeDifference : clock.utcOffset
        
        let snapshotView = CityCardSnapshotView(
            cityName: cityName,
            timeString: timeString,
            dateString: dateString,
            date: adjustedDate,
            timeZone: targetTimeZone,
            timeZoneIdentifier: timeZoneIdentifier,
            weatherCondition: weatherManager.weatherData[timeZoneIdentifier]?.condition,
            showAnalogClock: showAnalogClock,
            analogClockShowScale: analogClockShowScale,
            showSunPosition: showSunPosition,
            showWeatherCondition: showWeatherCondition,
            showSunAzimuth: showSunAzimuth,
            showSunriseSunset: showSunriseSunset,
            showDaylight: showDaylight,
            showSolarCurve: showSolarCurve,
            additionalTimeDisplay: additionalTimeDisplay,
            showSkyDot: showSkyDot,
            additionalTimeText: additionalText
        )
        .environmentObject(weatherManager)
        .environment(\.colorScheme, .dark)
        
        let renderer = ImageRenderer(content: snapshotView)
        renderer.scale = 3
        
        if let uiImage = renderer.uiImage {
            return CardImage(uiImage: uiImage)
        }
        let placeholderImage = UIImage(systemName: "photo") ?? UIImage()
        return CardImage(uiImage: placeholderImage)
    }
    
    // Toggle all selections
    func toggleSelectAll() {
        // Provide haptic feedback if enabled
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
        
        withAnimation(.spring()) {
            if allCitiesSelected {
                // Deselect all
                selectedCities.removeAll()
                if showLocalTimeInHome {
                    showLocalTime = false
                }
            } else {
                // Select all
                selectedCities = Set(worldClocks.map { $0.id })
                if showLocalTimeInHome {
                    showLocalTime = true
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        // Local time card
                        if showLocalTimeInHome {
                            HStack(spacing: 16) {
                                
                                // Selection indicator
                                ZStack {
                                    if showLocalTime {
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
                                    Text(String(localized: "Local"))
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
                                    .foregroundStyle(.secondary)}

                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    showLocalTime.toggle()
                                }
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                            }
//                            Divider()
//                                .padding(.vertical, 12)
                        }
                        
                        // World clocks cards
                        ForEach(worldClocks) { clock in
                            HStack(spacing: 16) {
                                // Selection indicator
                                ZStack {
                                    if selectedCities.contains(clock.id) {
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
                                Text(clock.localizedCityName)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                
                                Spacer()
                                
                                // Time on the right
                                if let timeZone = TimeZone(identifier: clock.timeZoneIdentifier) {
                                    Text(formatTime(for: timeZone))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    if selectedCities.contains(clock.id) {
                                        selectedCities.remove(clock.id)
                                    } else {
                                        selectedCities.insert(clock.id)
                                    }
                                }
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                            }
                        }
                    }
                    // Overall List
                    .padding(.horizontal)
                }
                
                // Select All button
                VStack {
                    Spacer()
                    
                Button(action: toggleSelectAll) {
                    Text(allCitiesSelected ? String(localized: "Deselect All") : String(localized: "Select All"))
                        .font(.headline)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .contentTransition(.numericText())
                }
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        .blendMode(.plusLighter)
                )
                .glassEffect(.regular.interactive())
                .buttonStyle(.plain)
                }
            }
            .navigationTitle(String(localized: "Share Cities"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollIndicators(.hidden)
            
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Only show share button if at least one city is selected
                    if !selectedCities.isEmpty || (showLocalTimeInHome && showLocalTime) {
                        if isSingleSelection, let info = singleSelectionInfo {
                            // Single selection: Menu with "Copy as Text" and "Share as Image"
                            let lazyCard = ShareLazyCardImage { [self] in
                                renderCardImage(cityName: info.cityName, timeZoneIdentifier: info.timeZoneIdentifier).uiImage
                            }
                            Menu {
                                Button(action: copyTimeAsText) {
                                    Label(String(localized: "Copy as Text"), systemImage: "quote.opening")
                                }
                                ShareLink(item: lazyCard, preview: SharePreview(info.cityName)) {
                                    Label(String(localized: "Share as Image"), systemImage: "camera.macro")
                                }
                            } label: {
                                Text(String(localized: "Share"))
                                    .font(.headline)
                            }
                        } else {
                            // Multiple selections: direct ShareLink
                            ShareLink(item: generateShareText()) {
                                Text(String(localized: "Share"))
                                    .font(.headline)
                            }
                        }
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
