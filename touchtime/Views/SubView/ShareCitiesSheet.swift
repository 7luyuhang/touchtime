//
//  ShareCitiesSheet.swift
//  touchtime
//
//  Created on 27/09/2025.
//

import SwiftUI
import UIKit
import WeatherKit

/// Shown in place of the share sheet when there is no local time, no
/// cities and no pinned countdowns to share.
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

    /// Pinned countdown being shared as an image, counted from the moment
    /// the menu item is tapped, like the city card.
    private struct CountdownShareData: Identifiable {
        let id = UUID()
        let item: CountdownItem
        let now: Date
    }

    /// The one item selected, which the Share menu can also share as an image.
    private enum SingleSelection {
        case city(name: String, timeZoneIdentifier: String)
        case countdown(CountdownItem)
    }

    @Binding var worldClocks: [WorldClock]
    @Binding var showSheet: Bool
    @State private var selectedCities: Set<UUID> = []
    @State private var selectedCountdowns: Set<UUID> = []
    @State private var showLocalTime = false
    @State private var cityShareData: CityShareData? = nil
    @State private var countdownShareData: CountdownShareData? = nil
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
    // Same Time Display settings as the countdown sheet rows, so shared
    // countdown text breaks the interval into the units chosen there.
    @AppStorage("countdownShowYears") private var countdownShowYears = false
    @AppStorage("countdownShowMonths") private var countdownShowMonths = false
    @AppStorage("countdownShowDays") private var countdownShowDays = true
    
    @EnvironmentObject private var weatherManager: WeatherManager
    @Environment(CountdownStore.self) private var countdownStore
    
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
    
    // Current time plus the Slide to Adjust offset, which the countdowns count from
    var now: Date {
        currentDate.addingTimeInterval(timeOffset)
    }
    
    // Pinned countdowns, in the order of their cards on Home
    var pinnedCountdowns: [CountdownItem] {
        countdownStore.pinnedCountdowns(at: now)
    }
    
    // "in 4 days", "3 days ago" or "Today", in the countdown sheet's units
    func countdownText(for item: CountdownItem) -> String {
        CountdownShare.footerText(
            from: item.pausedAt ?? now,
            to: item.effectiveTargetDate(at: now),
            showYears: countdownShowYears,
            showMonths: countdownShowMonths,
            showDays: countdownShowDays
        )
    }
    
    // Generate share text
    func generateShareText() -> String {
        var shareLines: [String] = []
        
        // Add selected pinned countdowns, which come before the cities on Home
        for item in pinnedCountdowns where selectedCountdowns.contains(item.id) {
            shareLines.append(CountdownShare.copyText(
                title: item.title,
                targetDate: item.effectiveTargetDate(at: now),
                now: item.pausedAt ?? now,
                showYears: countdownShowYears,
                showMonths: countdownShowMonths,
                showDays: countdownShowDays
            ))
        }
        
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
    
    var isLocalTimeSelected: Bool {
        showLocalTimeInHome && showLocalTime
    }
    
    // Local time, cities and countdowns selected, all together
    var selectionCount: Int {
        (isLocalTimeSelected ? 1 : 0) + selectedCities.count + selectedCountdowns.count
    }
    
    // The selected item, when exactly one is selected
    private var singleSelection: SingleSelection? {
        guard selectionCount == 1 else { return nil }
        if isLocalTimeSelected {
            return .city(name: String(localized: "Local"), timeZoneIdentifier: TimeZone.current.identifier)
        }
        if let clockId = selectedCities.first,
           let clock = worldClocks.first(where: { $0.id == clockId }) {
            return .city(name: clock.localizedCityName, timeZoneIdentifier: clock.timeZoneIdentifier)
        }
        if let countdownId = selectedCountdowns.first,
           let item = pinnedCountdowns.first(where: { $0.id == countdownId }) {
            return .countdown(item)
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
    
    /// Opens the share-as-image screen for the one selected city or
    /// countdown, fixing the time it shows at this moment.
    private func shareAsImage(_ selection: SingleSelection) {
        switch selection {
        case .city(let name, let timeZoneIdentifier):
            shareCardAsImage(cityName: name, timeZoneIdentifier: timeZoneIdentifier)
        case .countdown(let item):
            countdownShareData = CountdownShareData(item: item, now: now)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Pinned countdowns, above the cities like on Home
                    ForEach(pinnedCountdowns) { item in
                        let isSelected = selectedCountdowns.contains(item.id)

                        HStack(spacing: 16) {
                            // Selection indicator
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.25))
                                .contentTransition(.symbolEffect(.replace))
                                .animation(.spring(), value: isSelected)
                            
                            // Countdown title
                            Text(item.title)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Spacer()
                            
                            // Day count on the right, kept whole while a long title truncates
                            Text(countdownText(for: item))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .layoutPriority(1)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring()) {
                                if selectedCountdowns.contains(item.id) {
                                    selectedCountdowns.remove(item.id)
                                } else {
                                    selectedCountdowns.insert(item.id)
                                }
                            }
                            if hapticEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                        }
                    }
                    
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
            .navigationTitle(String(localized: "Share"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollIndicators(.hidden)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Only show share button if at least one item is selected
                    if selectionCount > 0 {
                        if let selection = singleSelection {
                            // Single selection: Menu with "Copy as Text" and "Share as Image"
                            Menu {
                                Button(action: copyTimeAsText) {
                                    Label(String(localized: "Copy as Text"), systemImage: "quote.opening")
                                }
                                Button {
                                    shareAsImage(selection)
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
        // Share as Image for a countdown: the same full-screen preview as
        // its pinned card on Home
        .fullScreenCover(item: $countdownShareData) { share in
            CountdownShareAsImageView(
                title: share.item.title,
                targetDate: share.item.effectiveTargetDate(at: share.now),
                emoji: share.item.emoji,
                photoData: share.item.photoData,
                photoCrop: share.item.photoCrop,
                isRepeating: share.item.repeatFrequency != .never,
                now: share.now,
                pausedAt: share.item.pausedAt
            )
        }
        .presentationDetents([.medium])
    }
}
