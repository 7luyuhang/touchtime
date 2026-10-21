//
//  SunriseSunsetSheet.swift
//  touchtime
//
//  Created on 19/10/2025.
//

import SwiftUI
import Combine
import CoreLocation
import WeatherKit

/// One of the four principal moon phases with the instant it next occurs.
struct UpcomingMoonPhase: Identifiable {
    let icon: String
    let name: String
    let date: Date
    var id: String { icon }
}

struct SunriseSunsetSheet: View {
    let cityName: String
    let timeZoneIdentifier: String
    let initialDate: Date
    let timeOffset: TimeInterval
    /// Shown inline as a detail pane on iPhone Duo instead of as a sheet,
    /// split from the list along this axis: beside it in landscape, above it
    /// in portrait. Always expanded, without a title or close button, and
    /// without its own sky, as HomeView draws one behind both panes.
    var splitAxis: Axis? = nil
    /// Opens at the large detent, with no medium detent to shrink to.
    let largeDetentOnly: Bool
    
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showSkyDot") private var showSkyDot = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("showWeather") private var showWeather = false
    @AppStorage("show10DaysWeather") private var storedWeatherExpanded = false
    @AppStorage("showUpcomingMoonPhases") private var storedMoonPhasesExpanded = false
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("showAddWidgetTip") private var showAddWidgetTip = true
    @Environment(\.dismiss) private var dismiss
    @State private var currentDate: Date = Date()
    @EnvironmentObject private var weatherManager: WeatherManager
    @State private var weatherLoadAttempted = false // No Weather Data
    @State private var isWeatherExpanded = false // Track weather section expansion
    @State private var showDaylightSheet = false // Track daylight sheet
    @State private var showDSTSheet = false // Track DST sheet
    @Namespace private var dstZoomNamespace // Pairs the DST pill with the sheet that zooms out of it
    @State private var floatingDSTPillHeight: CGFloat = 0 // Rounds the zoom's start into the pill's capsule
    @State private var showMapSheet = false // Track map sheet
    @Namespace private var mapZoomNamespace // Pairs the location button with the map sheet that zooms out of it
    @State private var currentDetent: PresentationDetent // Track current sheet size
    @State private var showMoonPhaseView = false // Track moon phase view navigation
    @State private var showWidgetIntroSheet = false // Track widget intro sheet
    @State private var sunTimes: (sunrise: Date?, sunset: Date?)?
    @State private var eveningGoldenHour: (start: Date?, end: Date?)?
    @State private var moonInfo: (moonrise: Date?, moonset: Date?, phase: String, phaseIcon: String)?
    @State private var upcomingMoonPhases: [UpcomingMoonPhase] = []
    @State private var isMoonPhasesExpanded = false // Track upcoming phases expansion
    @State private var astronomyDayCacheKey: String = ""

    init(
        cityName: String,
        timeZoneIdentifier: String,
        initialDate: Date,
        timeOffset: TimeInterval,
        splitAxis: Axis? = nil,
        largeDetentOnly: Bool = false
    ) {
        self.cityName = cityName
        self.timeZoneIdentifier = timeZoneIdentifier
        self.initialDate = initialDate
        self.timeOffset = timeOffset
        self.splitAxis = splitAxis
        self.largeDetentOnly = largeDetentOnly
        _currentDetent = State(initialValue: largeDetentOnly ? .large : .medium)
    }

    private var isEmbedded: Bool {
        splitAxis != nil
    }

    /// Beside the list the bottom bar moves into the vertical bar, which has
    /// no room for the DST pill, so the pill floats over the content instead.
    private var floatsDSTPill: Bool {
        splitAxis == .horizontal
    }

    private static let dstZoomSourceID = "dst"
    private static let mapZoomSourceID = "map"

    // Large detent layout: sticky time section and full-sheet sky
    private var isExpanded: Bool {
        isEmbedded || currentDetent == .large
    }
    
    // Computed properties to get weather data directly from weatherManager
    private var currentWeather: CurrentWeather? {
        weatherManager.weatherData[timeZoneIdentifier]
    }
    
    private var dailyWeather: DayWeather? {
        weatherManager.dailyWeatherData[timeZoneIdentifier]
    }
    
    private var weeklyWeather: [DayWeather] {
        weatherManager.weeklyWeatherData[timeZoneIdentifier] ?? []
    }
    
    private var hourlyWeather: [HourWeather] {
        weatherManager.hourlyWeatherData[timeZoneIdentifier] ?? []
    }

    private var recentPressureTrends: [PressureTrend] {
        weatherManager.recentPressureTrendsData[timeZoneIdentifier] ?? []
    }

    private var weatherConditionForSky: WeatherCondition? {
        guard showWeather else { return nil }
        return currentWeather?.condition
    }

    private var dateFormat: DetailsDateFormat {
        DetailsDateFormat(timeZoneIdentifier: timeZoneIdentifier, use24HourFormat: use24HourFormat)
    }
    
    // Timer to update the current date
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Check if weather is clear (sunny)
    private var isWeatherClear: Bool {
        guard let weather = currentWeather else { return false }
        switch weather.condition {
        case .clear, .mostlyClear:
            return true
        default:
            return false
        }
    }
    
    
    private func calendarForTimeZone() -> Calendar {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return calendar
    }

    private func astronomyDayKey(for adjustedDate: Date) -> String {
        let calendar = calendarForTimeZone()
        let components = calendar.dateComponents([.year, .month, .day], from: adjustedDate)
        return "\(timeZoneIdentifier)_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)"
    }

    /// Finds the exact instant the moon's age next reaches `targetAgeDays`
    /// (0 = new moon, then quarter-cycle steps for first quarter, full moon
    /// and last quarter). Uses the same MoonAstronomy age as the moon phase
    /// calendar's day dots, so the dates always match them.
    private func findNextMoonPhaseDate(targetAgeDays: Double, startingFrom date: Date) -> Date? {
        let cycle = MoonAstronomy.synodicMonthDays
        let dayInSeconds: TimeInterval = 86400

        // Days left until the target age, wrapping at the cycle boundary:
        // counts down to zero at the phase instant, then jumps back up.
        func remainingDays(at date: Date) -> Double {
            let diff = (targetAgeDays - MoonAstronomy.snapshot(for: date).ageDays)
                .truncatingRemainder(dividingBy: cycle)
            return diff < 0 ? diff + cycle : diff
        }

        // Scan forward in 24h windows for the one containing the countdown wrap;
        // one must occur within a synodic month (~29.5 days).
        var windowStart = date
        var remainingAtStart = remainingDays(at: windowStart)

        for _ in 0..<31 {
            let windowEnd = windowStart.addingTimeInterval(dayInSeconds)
            let remainingAtEnd = remainingDays(at: windowEnd)

            if remainingAtEnd > remainingAtStart {
                // Bisect the window down to ~1s to pin the crossing instant
                var lowerBound = windowStart
                var upperBound = windowEnd
                for _ in 0..<17 {
                    let midpoint = lowerBound.addingTimeInterval(upperBound.timeIntervalSince(lowerBound) / 2)
                    if remainingDays(at: midpoint) <= remainingAtStart {
                        lowerBound = midpoint
                    } else {
                        upperBound = midpoint
                    }
                }
                return upperBound
            }

            windowStart = windowEnd
            remainingAtStart = remainingAtEnd
        }

        return nil
    }

    private func refreshAstronomyData(force: Bool = false, referenceDate: Date) {
        guard let coordinates = getCoordinatesForTimeZone(timeZoneIdentifier) else {
            sunTimes = nil
            eveningGoldenHour = nil
            moonInfo = nil
            upcomingMoonPhases = []
            astronomyDayCacheKey = ""
            return
        }

        let adjustedDate = referenceDate.addingTimeInterval(timeOffset)
        let dayKey = astronomyDayKey(for: adjustedDate)

        if !force && dayKey == astronomyDayCacheKey {
            return
        }

        astronomyDayCacheKey = dayKey

        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current

        let events = SolarCalculator.events(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            date: adjustedDate,
            timeZone: timeZone
        )
        sunTimes = (events.sunrise, events.sunset)
        eveningGoldenHour = (events.eveningGoldenHourStart, events.eveningGoldenHourEnd)

        let moonEvents = MoonAstronomy.riseAndSet(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            date: adjustedDate,
            timeZone: timeZone
        )
        // Day-level phase, the same rule as the moon calendar (MoonDay): the
        // instantaneous phase would call the new moon day a crescent within
        // two hours of the exact new moon.
        let phase = MoonDay(containing: adjustedDate, calendar: calendarForTimeZone()).phase
        moonInfo = (
            moonrise: moonEvents.moonrise,
            moonset: moonEvents.moonset,
            phase: phase.localizedName,
            phaseIcon: phase.symbolName
        )

        // The four principal phases coming up, soonest first
        let quarterCycle = MoonAstronomy.synodicMonthDays / 4
        let principalPhases: [(icon: String, name: String, targetAgeDays: Double)] = [
            ("moonphase.new.moon", String(localized: "New"), 0),
            ("moonphase.first.quarter", String(localized: "First"), quarterCycle),
            ("moonphase.full.moon", String(localized: "Full"), quarterCycle * 2),
            ("moonphase.last.quarter", String(localized: "Last"), quarterCycle * 3)
        ]
        upcomingMoonPhases = principalPhases
            .compactMap { phase in
                findNextMoonPhaseDate(targetAgeDays: phase.targetAgeDays, startingFrom: adjustedDate)
                    .map { UpcomingMoonPhase(icon: phase.icon, name: phase.name, date: $0) }
            }
            .sorted { $0.date < $1.date }
    }
    
    // Map timezone identifiers to coordinates using shared utility
    private func getCoordinatesForTimeZone(_ identifier: String) -> (latitude: Double, longitude: Double)? {
        return TimeZoneCoordinates.getCoordinate(for: identifier)
    }
    
    // Calculate DST information
    private var dstInfo: (transitionDate: Date?, isStart: Bool, offsetHours: Int)? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }
        
        let adjustedDate = currentDate.addingTimeInterval(timeOffset)
        
        // Check if timezone supports DST by checking if there's a next transition
        guard let nextTransition = timeZone.nextDaylightSavingTimeTransition(after: adjustedDate) else {
            return nil
        }
        
        // Check if currently in DST
        let isCurrentlyDST = timeZone.isDaylightSavingTime(for: adjustedDate)
        
        // Check if the next transition will start or end DST
        // If currently in DST, next transition will end it (isStart = false)
        // If currently not in DST, next transition will start it (isStart = true)
        let isStart = !isCurrentlyDST
        
        // Calculate DST offset
        // For DST start: time moves forward (+1 hour)
        // For DST end: time moves backward (-1 hour)
        // Get the offset after the transition
        let offsetAfterTransition = timeZone.daylightSavingTimeOffset(for: nextTransition)
        let offsetBeforeTransition = timeZone.daylightSavingTimeOffset(for: adjustedDate)
        
        // The change in offset is what we want to display
        let offsetChange = offsetAfterTransition - offsetBeforeTransition
        let offsetHours = Int(offsetChange / 3600)
        
        return (nextTransition, isStart, offsetHours)
    }
    
    // At medium the sheet floats as an inset card, and switching to large drops
    // its bottom edge to the screen's. The sky stays in place, transparent, and
    // fades in once that's mostly done, so the drop happens on the glass.
    @ViewBuilder
    private var sheetSkyBackground: some View {
        if showSkyDot && !isEmbedded {
            SkyBackgroundView(
                date: currentDate.addingTimeInterval(timeOffset),
                timeZoneIdentifier: timeZoneIdentifier,
                weatherCondition: weatherConditionForSky,
                appliesCardChrome: false
            )
            .animation(skyFadeAnimation) { sky in
                sky.opacity(currentDetent == .large ? 1 : 0)
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
    }

    // Fades out quickly on the way back, before the sheet floats again
    private var skyFadeAnimation: Animation {
        currentDetent == .large
            ? .easeInOut(duration: 0.35).delay(0.15)
            : .easeOut(duration: 0.15)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Add Widget Tip
                    if showAddWidgetTip {
                        AddWidgetTip(isShown: $showAddWidgetTip, showsIntroSheet: $showWidgetIntroSheet)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .transition(.blurReplace())
                    }

                    // Weather section - only show if weather is enabled in settings
                    if showWeather {
                        WeatherSection(
                            weather: currentWeather,
                            dailyWeather: dailyWeather,
                            weeklyWeather: weeklyWeather,
                            hourlyWeather: hourlyWeather,
                            recentPressureTrends: recentPressureTrends,
                            loadAttempted: weatherLoadAttempted,
                            timeZoneIdentifier: timeZoneIdentifier,
                            currentDate: currentDate,
                            dateFormat: dateFormat,
                            isExpanded: $isWeatherExpanded
                        )
                    }

                    if let times = sunTimes {
                        SolarTimeSection(
                            sunrise: times.sunrise,
                            sunset: times.sunset,
                            goldenHourStart: eveningGoldenHour?.start,
                            goldenHourEnd: eveningGoldenHour?.end,
                            headerTopPadding: (showWeather && (currentWeather != nil || weatherLoadAttempted)) || isExpanded ? 24 : 8,
                            currentDate: currentDate,
                            timeOffset: timeOffset,
                            dateFormat: dateFormat,
                            showsDaylightSheet: $showDaylightSheet
                        )

                        if let moon = moonInfo {
                            MoonTimeSection(
                                moonrise: moon.moonrise,
                                moonset: moon.moonset,
                                phaseName: moon.phase,
                                phaseIcon: moon.phaseIcon,
                                upcomingPhases: upcomingMoonPhases,
                                currentDate: currentDate,
                                timeOffset: timeOffset,
                                timeZoneIdentifier: timeZoneIdentifier,
                                dateFormat: dateFormat,
                                showsMoonPhaseView: $showMoonPhaseView,
                                isPhasesExpanded: $isMoonPhasesExpanded
                            )
                        }
                    }

                    // Dots world map with the current city highlighted
                    // and the solar terminator curve for the shown time
                    DotsWorldMapView(
                        timeZoneIdentifier: timeZoneIdentifier,
                        date: currentDate.addingTimeInterval(timeOffset)
                    )
                        .padding(.horizontal, 24)
                        .padding(.top)
                        .padding(.bottom)
                }
                .animation(.bouncy(), value: currentDetent)
            }
            .scrollIndicators(.hidden)
            // Above the list it fades out toward the fold
            .foldEdgeFade(.bottom, isActive: splitAxis == .vertical)
            .safeAreaInset(edge: .top, spacing: 0) {
                Group {
                    if isExpanded {
                        StickyTimeCard(
                            cityName: cityName,
                            timeZoneIdentifier: timeZoneIdentifier,
                            currentDate: currentDate,
                            timeOffset: timeOffset,
                            weather: currentWeather,
                            skyWeatherCondition: weatherConditionForSky,
                            dateFormat: dateFormat
                        )
                        .padding(.horizontal, 16)
                        // Beside the list, level with its first card
                        // (the list starts 24pt down)
                        .padding(.top, isEmbedded ? 24 : 8)
                        .transition(.blurReplace())
                    }
                }
                .animation(.bouncy(), value: currentDetent)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if floatsDSTPill, let dst = dstInfo, let transitionDate = dst.transitionDate {
                    Button(action: openDSTSheet) {
                        DSTLabel(isStart: dst.isStart, transitionDate: transitionDate, offsetHours: dst.offsetHours, dateFormat: dateFormat)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        floatingDSTPillHeight = height
                    }
                    // Zoom sources only clip to rounded rectangles
                    .matchedTransitionSource(id: Self.dstZoomSourceID, in: dstZoomNamespace) { source in
                        source.clipShape(RoundedRectangle(cornerRadius: floatingDSTPillHeight / 2, style: .continuous))
                    }
                    // Level with the list's Slide to Adjust bar: as tall as
                    // ScrollTimeView's controls (52pt) and as far up (8pt)
                    .frame(minHeight: 52)
                    .padding(.bottom, 8)
                }
            }
            .background {
                sheetSkyBackground
            }
            // Beside the list the stack still reserves a vertical bar's width
            // at its trailing edge, though the system draws that bar at the
            // window edge
            .ignoresSafeArea(.container, edges: splitAxis == .horizontal ? .trailing : [])
            // Only beside the list does the pane reach the bottom edge
            .verticalBarBottomInset(isActive: splitAxis == .horizontal)
            // The detail pane sits on HomeView's sky background
            .clearNavigationBackground(isEmbedded)
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onAppear {
                currentDate = initialDate
                isWeatherExpanded = storedWeatherExpanded
                isMoonPhasesExpanded = storedMoonPhasesExpanded
                refreshAstronomyData(force: true, referenceDate: initialDate)
            }
            .task(id: timeZoneIdentifier) {
                // The detail pane switches cities in place
                weatherLoadAttempted = false
                refreshAstronomyData(force: true, referenceDate: currentDate)
                // Fetch weather data only if weather is enabled
                // Using .task(id:) ensures this runs when timeZoneIdentifier changes
                guard showWeather else { return }
                await weatherManager.getWeather(for: timeZoneIdentifier)
                weatherLoadAttempted = true
                await weatherManager.getRecentPressureTrends(for: timeZoneIdentifier)
            }
            .onReceive(timer) { now in
                let calendar = Calendar.current
                if calendar.component(.minute, from: now) != calendar.component(.minute, from: currentDate) {
                    currentDate = now
                    refreshAstronomyData(referenceDate: now)
                }
            }
            .onChange(of: timeOffset) { _, _ in
                // Keep sun/moon data in sync when scroll time is reset while the sheet is open
                refreshAstronomyData(referenceDate: currentDate)
            }
            .onChange(of: currentDetent) { oldValue, newValue in
                if newValue == .large && hapticEnabled {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                }
            }
            .toolbar {
                
                if !isEmbedded {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text(cityName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            let adjustedDate = currentDate.addingTimeInterval(timeOffset)
                            Text(adjustedDate.formattedDate(
                                style: dateStyle,
                                timeZone: TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
                            ))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                        }
                    }
                    
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
                }
                
                // Bottom bar: location + DST (if any) + reset (if time is scrolled).
                // The detail pane leaves the reset to the list's Slide to Adjust
                // bar, and beside the list its DST pill floats over the content.
                // Open in Map
                if getCoordinatesForTimeZone(timeZoneIdentifier) != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            if hapticEnabled {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            showMapSheet = true
                        } label: {
                            Image(systemName: "location.fill")
                        }
                    }
                    .matchedTransitionSource(id: Self.mapZoomSourceID, in: mapZoomNamespace)
                }
                
                if !floatsDSTPill && getCoordinatesForTimeZone(timeZoneIdentifier) != nil && dstInfo != nil {
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                }
                
                // DST information in bottom bar
                if !floatsDSTPill, let dst = dstInfo, let transitionDate = dst.transitionDate {
                    ToolbarItem(placement: .bottomBar) {
                        Button(action: openDSTSheet) {
                            DSTLabel(isStart: dst.isStart, transitionDate: transitionDate, offsetHours: dst.offsetHours, dateFormat: dateFormat)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                    .matchedTransitionSource(id: Self.dstZoomSourceID, in: dstZoomNamespace)
                }
                
                if !isEmbedded && timeOffset != 0 {
                    // DST pill already expands to fill the middle; without it,
                    // a flexible spacer pushes the reset button to the far right.
                    if dstInfo != nil {
                        ToolbarSpacer(.fixed, placement: .bottomBar)
                    } else if getCoordinatesForTimeZone(timeZoneIdentifier) != nil {
                        ToolbarSpacer(.flexible, placement: .bottomBar)
                    }
                    
                    // Reset scroll time
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            if hapticEnabled {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                            NotificationCenter.default.post(name: NSNotification.Name("ResetScrollTime"), object: nil)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .fontWeight(.semibold)
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                    }
                }
            }
            .presentationDetents(largeDetentOnly ? [.large] : [.medium, .large], selection: $currentDetent)
            .presentationDragIndicator(.visible)
            .sheet(isPresented: $showMoonPhaseView) {
                MoonPhaseView(
                    cityName: cityName,
                    timeZoneIdentifier: timeZoneIdentifier,
                    timeOffset: timeOffset
                )
            }
            .sheet(isPresented: $showWidgetIntroSheet) {
                WidgetIntroSheet()
            }
            .sheet(isPresented: $showDaylightSheet) {
                DaylightSheet(
                    timeZoneIdentifier: timeZoneIdentifier,
                    timeOffset: timeOffset
                )
            }
            .sheet(isPresented: $showDSTSheet) {
                if let dst = dstInfo, let transitionDate = dst.transitionDate {
                    DSTSheet(
                        transitionDate: transitionDate,
                        isStart: dst.isStart,
                        timeOffset: timeOffset,
                        dateFormat: dateFormat
                    )
                    .navigationTransition(.zoom(sourceID: Self.dstZoomSourceID, in: dstZoomNamespace))
                }
            }
            .sheet(isPresented: $showMapSheet) {
                if let coords = getCoordinatesForTimeZone(timeZoneIdentifier) {
                    CityMapSheet(
                        cityName: cityName,
                        coordinate: CLLocationCoordinate2D(latitude: coords.latitude, longitude: coords.longitude)
                    )
                    .navigationTransition(.zoom(sourceID: Self.mapZoomSourceID, in: mapZoomNamespace))
                }
            }
        }
    }

    private func openDSTSheet() {
        if hapticEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        showDSTSheet = true
    }
}

private extension View {
    @ViewBuilder
    func clearNavigationBackground(_ isClear: Bool) -> some View {
        if isClear {
            containerBackground(.clear, for: .navigation)
        } else {
            self
        }
    }
}
