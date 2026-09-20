//
//  ShareCitiesSheet.swift
//  touchtime
//
//  Created on 27/09/2025.
//

import SwiftUI
import UIKit
import WeatherKit

/// Shown in place of the share sheet when there is no local time and no
/// cities to share.
struct ShareCitiesEmptyView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Nothing to Share", systemImage: "square.and.arrow.up")
            } description: {
                Text("Add cities to share their time.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct ShareCitiesSheet: View {
    /// City whose card is being shared as an image. The time is fixed
    /// when the menu item is tapped, so the share preview shows that
    /// moment instead of ticking (and reseeding its stars) every second.
    private struct CityShareData: Identifiable {
        let id = UUID()
        let cityName: String
        let timeZoneIdentifier: String
        /// Wall-clock time and Slide to Adjust offset at the tap.
        let baseDate: Date
        let timeOffset: TimeInterval

        /// The time the card shows.
        var date: Date {
            baseDate.addingTimeInterval(timeOffset)
        }
    }

    @Binding var worldClocks: [WorldClock]
    @Binding var showSheet: Bool
    @State private var selectedCities: Set<UUID> = []
    @State private var showLocalTime = false
    @State private var cityShareData: CityShareData? = nil
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showLocalTime") private var showLocalTimeInHome = true
    @AppStorage("customLocalName") private var customLocalName = ""
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("showSkyDot") private var showSkyDot = true
    @AppStorage("showWeather") private var showWeather = false
    @AppStorage("useCelsius") private var useCelsius = true
    @AppStorage("showAnalogClock") private var showAnalogClock = false
    @AppStorage("analogClockShowScale") private var analogClockShowScale = false
    @AppStorage("showSunPosition") private var showSunPosition = false
    @AppStorage("showWeatherCondition") private var showWeatherCondition = false
    @AppStorage("showTemperatureIndicator") private var showTemperatureIndicator = false
    @AppStorage("showTemperatureRange") private var showTemperatureRange = false
    @AppStorage("showUVIndex") private var showUVIndex = false
    @AppStorage("showWindDirection") private var showWindDirection = false
    @AppStorage("showSunAzimuth") private var showSunAzimuth = false
    @AppStorage("showMoonAzimuth") private var showMoonAzimuth = false
    @AppStorage("showMoonSunAzimuth") private var showMoonSunAzimuth = false
    @AppStorage("showSunriseSunset") private var showSunriseSunset = false
    @AppStorage("showDaylight") private var showDaylight = false
    @AppStorage("showTimeOverlay") private var showTimeOverlay = false
    @AppStorage("showSolarCurve") private var showSolarCurve = false
    @AppStorage("solarCurveShowSun") private var solarCurveShowSun = false
    @AppStorage("availableTimeEnabled") private var availableTimeEnabled = AvailableTimeDefaults.isEnabled
    @AppStorage("hasLifetimeAccess") private var hasLifetimeAccess = false
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

    private var effectiveShowWeatherCondition: Bool {
        showWeatherCondition
    }

    private var effectiveShowTemperatureIndicator: Bool {
        hasLifetimeAccess && showTemperatureIndicator
    }

    private var effectiveShowTemperatureRange: Bool {
        hasLifetimeAccess && showTemperatureRange
    }

    private var effectiveShowUVIndex: Bool {
        hasLifetimeAccess && showUVIndex
    }

    private var effectiveShowWindDirection: Bool {
        hasLifetimeAccess && showWindDirection
    }

    private var effectiveShowMoonAzimuth: Bool {
        hasLifetimeAccess && showMoonAzimuth
    }

    private var effectiveShowMoonSunAzimuth: Bool {
        hasLifetimeAccess && showMoonSunAzimuth
    }

    private var effectiveShowDaylight: Bool {
        hasLifetimeAccess && showDaylight
    }

    private var effectiveShowTimeOverlay: Bool {
        hasLifetimeAccess && showTimeOverlay && availableTimeEnabled
    }

    private var complicationOptions: ComplicationDisplayOptions {
        ComplicationDisplayOptions(
            showAnalogClock: showAnalogClock,
            analogClockShowScale: analogClockShowScale,
            showSunPosition: showSunPosition,
            showWeatherCondition: effectiveShowWeatherCondition,
            showTemperatureIndicator: effectiveShowTemperatureIndicator,
            showTemperatureRange: effectiveShowTemperatureRange,
            showUVIndex: effectiveShowUVIndex,
            showWindDirection: effectiveShowWindDirection,
            showSunAzimuth: showSunAzimuth,
            showMoonAzimuth: effectiveShowMoonAzimuth,
            showMoonSunAzimuth: effectiveShowMoonSunAzimuth,
            showSunriseSunset: showSunriseSunset,
            showDaylight: effectiveShowDaylight,
            showTimeOverlay: effectiveShowTimeOverlay,
            showSolarCurve: showSolarCurve,
            solarCurveShowSun: solarCurveShowSun
        )
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
    
    // Get formatted date for city card at a fixed time
    func getCityDate(timeZoneIdentifier: String, baseDate: Date, offset: TimeInterval) -> String {
        guard let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) else { return "" }
        let adjustedTime = baseDate.addingTimeInterval(offset)
        return adjustedTime.formattedDate(style: dateStyle, timeZone: targetTimeZone, relativeTo: baseDate)
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
    
    // MARK: - Share as Image
    
    /// Opens the share-as-image screen for the selected city, fixing the
    /// time it shows at this moment. No haptic here: the share screen plays
    /// its own entrance pattern.
    private func shareCardAsImage(cityName: String, timeZoneIdentifier: String) {
        cityShareData = CityShareData(
            cityName: cityName,
            timeZoneIdentifier: timeZoneIdentifier,
            baseDate: currentDate,
            timeOffset: timeOffset
        )
    }
    
    /// The share card for a city at the export size of the given frame: the
    /// row's card replica on its sky backdrop, with the local time as the
    /// footer. The share screen previews it live and renders it for the file.
    private func cityShareCard(for share: CityShareData, aspectRatio: ShareAspectRatio, frameCornerRadius: CGFloat = 0) -> some View {
        let timeZoneIdentifier = share.timeZoneIdentifier
        let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
        let weather = showWeather ? weatherManager.weatherData[timeZoneIdentifier] : nil
        let clock = WorldClock(cityName: share.cityName, timeZoneIdentifier: timeZoneIdentifier)
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24HourFormat ? "HH:mm" : "h:mm"
        formatter.timeZone = targetTimeZone
        let timeString = formatter.string(from: share.date)
        formatter.timeZone = TimeZone.current
        let localTimeString = formatter.string(from: share.date)
        
        // Weekday is drawn by the card from its own date, so only the
        // text-based displays need a string here.
        let additionalText: String
        switch additionalTimeDisplay {
        case "Time Difference":
            additionalText = clock.timeDifference
        case "UTC":
            additionalText = clock.utcOffset
        default:
            additionalText = ""
        }
        
        return CityCardSnapshotView(
            cityName: share.cityName,
            timeString: timeString,
            localCityName: localCityName,
            localTimeString: localTimeString,
            dateString: getCityDate(
                timeZoneIdentifier: timeZoneIdentifier,
                baseDate: share.baseDate,
                offset: share.timeOffset
            ),
            date: share.date,
            timeZone: targetTimeZone,
            timeZoneIdentifier: timeZoneIdentifier,
            weather: weather,
            weatherCondition: weather?.condition,
            useCelsius: useCelsius,
            complications: complicationOptions,
            additionalTimeDisplay: additionalTimeDisplay,
            showSkyDot: showSkyDot,
            additionalTimeText: additionalText,
            aspectRatio: aspectRatio,
            frameCornerRadius: frameCornerRadius
        )
        .environmentObject(weatherManager)
        .environment(\.colorScheme, .dark)
    }
    
    /// Renders the city share card into the image that gets saved or
    /// shared, falling back to a placeholder if rendering fails.
    private func renderCityShareImage(for share: CityShareData, aspectRatio: ShareAspectRatio) -> UIImage {
        let renderer = ImageRenderer(content: cityShareCard(for: share, aspectRatio: aspectRatio))
        renderer.scale = 3
        return renderer.uiImage ?? UIImage(systemName: "photo") ?? UIImage()
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
            ScrollView {
                VStack(spacing: 0) {
                    // Local time card
                    if showLocalTimeInHome {
                        let isSelected = showLocalTime

                        HStack(spacing: 16) {
                            
                            // Selection indicator
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.25))
                                .contentTransition(.symbolEffect(.replace))
                                .animation(.spring(), value: isSelected)
                            
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
                        let isSelected = selectedCities.contains(clock.id)

                        HStack(spacing: 16) {
                            // Selection indicator
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.25))
                                .contentTransition(.symbolEffect(.replace))
                                .animation(.spring(), value: isSelected)
                            
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
            .safeAreaPadding(.bottom, 8)
            .navigationTitle(String(localized: "Share Cities"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
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
                .contentShape(Capsule(style: .continuous))
                .glassEffect(.regular.interactive())
                .buttonStyle(.plain)
            }
            
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Only show share button if at least one city is selected
                    if !selectedCities.isEmpty || (showLocalTimeInHome && showLocalTime) {
                        if isSingleSelection, let info = singleSelectionInfo {
                            // Single selection: Menu with "Copy as Text" and "Share as Image"
                            Menu {
                                Button(action: copyTimeAsText) {
                                    Label(String(localized: "Copy as Text"), systemImage: "quote.opening")
                                }
                                Button {
                                    shareCardAsImage(cityName: info.cityName, timeZoneIdentifier: info.timeZoneIdentifier)
                                } label: {
                                    Label(String(localized: "Share as Image"), systemImage: "camera.macro")
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(String(localized: "Share"))
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
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
        // Share as Image: the same full-screen preview as the Home cards,
        // with frame, share and save actions
        .fullScreenCover(item: $cityShareData) { share in
            ShareAsImageView(title: share.cityName) { aspectRatio, frameCornerRadius in
                cityShareCard(for: share, aspectRatio: aspectRatio, frameCornerRadius: frameCornerRadius)
            } render: { aspectRatio in
                renderCityShareImage(for: share, aspectRatio: aspectRatio)
            }
        }
        .presentationDetents([.medium])
    }
}
