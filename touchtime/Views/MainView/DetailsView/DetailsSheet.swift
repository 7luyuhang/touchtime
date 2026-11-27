//
//  SunriseSunsetSheet.swift
//  touchtime
//
//  Created on 19/10/2025.
//

import SwiftUI
import Combine
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
    /// Called with the sticky time card's bottom, in global coordinates,
    /// whenever it moves. The sky HomeView draws behind the detail pane stops
    /// its clouds there.
    let onTimeCardBottomChanged: (CGFloat) -> Void
    
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
    @Namespace private var dstZoomNamespace // Pairs the DST card with the sheet that zooms out of it
    @State private var currentDetent: PresentationDetent // Track current sheet size
    @State private var showsResetButton: Bool // Track scrolled time, for the reset button
    @State private var showMoonPhaseView = false // Track moon phase view navigation
    @State private var showWidgetIntroSheet = false // Track widget intro sheet
    @State private var sunTimes: (sunrise: Date?, sunset: Date?)?
    @State private var eveningGoldenHour: (start: Date?, end: Date?)?
    @State private var moonInfo: (moonrise: Date?, moonset: Date?, phase: String, phaseIcon: String)?
    @State private var upcomingMoonPhases: [UpcomingMoonPhase] = []
    @State private var isMoonPhasesExpanded = false // Track upcoming phases expansion
    @State private var astronomyDayCacheKey: String = ""
    /// The bottom of the sticky time card, in global coordinates, which the
    /// sky's clouds stop at. Nil until the card is first laid out; it stays
    /// put at the medium detent, which drops the card, as the sky is hidden
    /// there.
    @State private var timeCardBottom: CGFloat?

    init(
        cityName: String,
        timeZoneIdentifier: String,
        initialDate: Date,
        timeOffset: TimeInterval,
        splitAxis: Axis? = nil,
        largeDetentOnly: Bool = false,
        onTimeCardBottomChanged: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.cityName = cityName
        self.timeZoneIdentifier = timeZoneIdentifier
        self.initialDate = initialDate
        self.timeOffset = timeOffset
        self.splitAxis = splitAxis
        self.largeDetentOnly = largeDetentOnly
        self.onTimeCardBottomChanged = onTimeCardBottomChanged
        _currentDetent = State(initialValue: largeDetentOnly ? .large : .medium)
        _showsResetButton = State(initialValue: timeOffset != 0)
    }

    private var isEmbedded: Bool {
        splitAxis != nil
    }

    private static let dstZoomSourceID = "dst"

    /// The clouds over the top of the details are smaller than their sky's
    /// height alone would make them, so a few more show across it.
    static let cloudScale: CGFloat = 0.7

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
                MoonAstronomy.nextPhaseDate(targetAgeDays: phase.targetAgeDays, startingFrom: adjustedDate)
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
                showClouds: true,
                cloudVariation: cityName,
                cloudScale: Self.cloudScale,
                // Over the top of the sheet, down to the time card, and clear
                // over the list below it
                cloudsBottom: timeCardBottom,
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

                    // Next DST change, for cities that observe DST
                    if let dst = dstInfo, let transitionDate = dst.transitionDate {
                        DSTCard(
                            isStart: dst.isStart,
                            transitionDate: transitionDate,
                            offsetHours: dst.offsetHours,
                            dateFormat: dateFormat,
                            showsDSTSheet: $showDSTSheet
                        )
                        // Zoom sources only clip to rounded rectangles; this
                        // one rounds like the card
                        .matchedTransitionSource(id: Self.dstZoomSourceID, in: dstZoomNamespace) { source in
                            source.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
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
                            headerTopPadding: (showWeather && (currentWeather != nil || weatherLoadAttempted)) || dstInfo != nil || isExpanded ? 24 : 8,
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
            // While the sheet presents, iOS 27 lays the page out short of the
            // bottom safe area, which would cut the cards off above bare glass
            // until it lands. The sheet still clips them at its own edge.
            .scrollClipDisabled(!isEmbedded)
            // Above the list it fades out toward the fold
            .foldEdgeFade(.bottom, splitAxis: splitAxis)
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
                        // Kept while the card is out of sight, behind another
                        // tab: back on screen in the same place, it isn't
                        // reported again
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.frame(in: .global).maxY
                        } action: { bottom in
                            timeCardBottom = bottom
                            onTimeCardBottomChanged(bottom)
                        }
                        .transition(.blurReplace())
                    }
                }
                .animation(.bouncy(), value: currentDetent)
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
            .onChange(of: timeOffset) { _, newValue in
                // Keep sun/moon data in sync when scroll time is reset while the sheet is open
                refreshAstronomyData(referenceDate: currentDate)
                // Not animated, though the reset changes the offset in a
                // spring: removed animated from the iPhone Duo's vertical bar,
                // the button leaves its glass behind, empty, fading out at the
                // bottom of the sheet
                var update = Transaction()
                update.disablesAnimations = true
                withTransaction(update) {
                    showsResetButton = newValue != 0
                }
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

                    // Reset scroll time. The detail pane leaves this to the
                    // list's Slide to Adjust bar.
                    if showsResetButton {
                        ToolbarItem(placement: .topBarTrailing) {
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
        }
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
