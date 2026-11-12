//
//  CityDetailView.swift
//  touchtimeWatch
//
//  A city's world clock, analogue clock, moon phase, solar curve, sun
//  position, daylight, weather, precipitation, wind, UV index, humidity, or
//  pressure.
//  Turning the Digital Crown moves a day at a time in Moon Phase, and an hour
//  in the other views, except in Weather, Precipitation, Wind, UV Index,
//  Humidity, Pressure and Sun Position's live compass, which show now.
//  Weather's, Precipitation's, UV Index's, Humidity's and Pressure's days
//  ahead take the Crown themselves.
//

import SwiftUI

struct CityDetailView: View {
    let city: ClockCity
    /// Every clock, each dotted on the map.
    let mapCities: [ClockCity]
    /// The time every clock shows in place of now, or nil for now.
    @Binding var adjustedDate: Date?

    @Environment(WatchCityStore.self) private var cityStore
    /// False as soon as the details start going back to the list, before
    /// they finish sliding away.
    @Environment(\.isPresented) private var isPresented
    @AppStorage(CityDetailDisplay.storageKey) private var display: CityDetailDisplay = .worldClock
    @State private var showsDisplayPicker = false
    @State private var showsMoonInfo = false
    @State private var moonInfoDate = Date()
    @State private var showsSunTimes = false
    @State private var sunTimesDate = Date()
    /// Whether Sun Position's or Wind's compass, or Pressure's barometer, is
    /// live: where the watch is rather than the city.
    @State private var isLive = false
    /// Whether World Map's map has turned, or is turning, into the globe.
    @State private var showsGlobe = false
    /// Whether Conditions shows its days rather than its hours.
    @State private var showsWeatherDays = true
    /// How many days after today the Digital Crown has turned to in
    /// Conditions, Precipitation, UV Index, Humidity and Pressure.
    @State private var crownDays: Double = 0
    /// Taps on Current Time, each felt. Not the adjusted date, which the
    /// Digital Crown and going live also clear, with haptics of their own.
    @State private var currentTimeTaps = 0
    /// How far the Digital Crown has moved: days in Moon Phase, hours otherwise.
    @State private var crownSteps: Double = 0
    /// The time the Digital Crown's steps count from: the clocks' time when
    /// it last rested at zero, or nil for now.
    @State private var crownStart: Date?
    /// Freeze "now" on the first step so minute ticks cannot shift the adjustment.
    @State private var crownReferenceDate: Date?
    @FocusState private var isCrownFocused: Bool

    /// Keep the Crown's range at a year in either direction for both step sizes.
    private var crownRange: Double {
        display == .moonPhase ? 365 : 24 * 365
    }

    private var stepOffset: Int {
        Int(crownSteps.rounded())
    }

    private var isAdjusted: Bool {
        adjustedDate != nil
    }

    private var crownMovesTime: Bool {
        !display.showsNow && !isLive
    }

    /// Back to now, Analogue's hands take a little longer over the hours they
    /// turn back through than over a step of the Digital Crown.
    private var adjustedDateAnimation: Animation {
        display == .analogue && !isAdjusted ? .smooth(duration: 0.8) : .smooth
    }

    /// Whether the view shows a day after today rather than now.
    private var showsLaterDay: Bool {
        switch display {
        case .weather: showsWeatherDays && Int(crownDays.rounded()) > 0
        case .precipitation, .uvIndex, .humidity, .pressure: Int(crownDays.rounded()) > 0
        case .worldClock, .analogue, .solarCurve, .sunPosition, .daylight, .moonPhase, .wind: false
        }
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = adjustedDate ?? context.date
            let dateLabel = date.formattedDate(
                style: cityStore.dateStyle, timeZone: city.timeZone, relativeTo: context.date
            )
            // Short enough to curve along the sun's track, and the same in the
            // daylight ring's middle.
            let shortDateLabel = date.formattedDate(
                style: cityStore.dateStyle,
                timeZone: city.timeZone,
                relativeTo: context.date,
                allowsWeekday: false
            )

            Group {
                switch display {
                case .worldClock:
                    VStack(spacing: 0) {
                        CityMapView(
                            date: date,
                            timeZoneIdentifiers: mapCities.map(\.timeZone.identifier),
                            highlightedTimeZoneIdentifier: city.timeZone.identifier,
                            isGlobe: $showsGlobe
                        ) {
                            clock(date: date)
                        }

                        dateRow(date: date, label: dateLabel, showsTime: showsGlobe)
                    }
                    .accessibilityElement(children: .combine)
                case .analogue:
                    CityAnalogueView(
                        date: date,
                        timeZone: city.timeZone,
                        isLocal: city.isLocal,
                        isAdjusting: isAdjusted,
                        referenceDate: isAdjusted ? context.date : nil
                    )
                case .moonPhase:
                    CityMoonPhaseView(date: date, timeZone: city.timeZone, dateLabel: dateLabel) {
                        moonInfoDate = date
                        isCrownFocused = false
                        showsMoonInfo = true
                    }
                    // The list row's sky stays behind the content during
                    // navigation. Fade in the moon's black backing with it.
                    .background {
                        Color.black.ignoresSafeArea()
                    }
                case .solarCurve:
                    CitySolarCurveView(date: date, timeZone: city.timeZone) {
                        sunTimesDate = date
                        isCrownFocused = false
                        showsSunTimes = true
                    } footer: {
                        dateRow(date: date, label: dateLabel, showsTime: true)
                    }
                case .sunPosition:
                    CitySunPositionView(
                        date: date,
                        timeZone: city.timeZone,
                        dateLabel: shortDateLabel,
                        isAdjusting: isAdjusted,
                        canGoLive: city.isLocal,
                        isLive: $isLive
                    )
                case .daylight:
                    CityDaylightView(
                        date: date,
                        timeZone: city.timeZone,
                        dateLabel: shortDateLabel,
                        isAdjusting: isAdjusted,
                        referenceDate: isAdjusted ? context.date : nil
                    )
                    .background {
                        Color.black.ignoresSafeArea()
                    }
                case .weather:
                    CityWeatherView(
                        date: date,
                        timeZone: city.timeZone,
                        useCelsius: cityStore.useCelsius,
                        dateStyle: cityStore.dateStyle,
                        showsDays: $showsWeatherDays,
                        crownDays: $crownDays
                    )
                case .precipitation:
                    CityPrecipitationView(
                        date: date,
                        timeZone: city.timeZone,
                        dateStyle: cityStore.dateStyle,
                        crownDays: $crownDays
                    )
                case .wind:
                    CityWindView(
                        date: date,
                        timeZone: city.timeZone,
                        windSpeedUnit: cityStore.windSpeedUnit,
                        canGoLive: city.isLocal,
                        isLive: $isLive
                    )
                case .uvIndex:
                    CityUVIndexView(
                        date: date,
                        timeZone: city.timeZone,
                        dateStyle: cityStore.dateStyle,
                        crownDays: $crownDays
                    )
                case .humidity:
                    CityHumidityView(
                        date: date,
                        timeZone: city.timeZone,
                        useCelsius: cityStore.useCelsius,
                        dateStyle: cityStore.dateStyle,
                        crownDays: $crownDays
                    )
                case .pressure:
                    CityPressureView(
                        date: date,
                        timeZone: city.timeZone,
                        pressureUnit: cityStore.pressureUnit,
                        dateStyle: cityStore.dateStyle,
                        crownDays: $crownDays,
                        canGoLive: city.isLocal,
                        isLive: $isLive
                    )
                }
            }
            // Like World Clock, the clock sits low enough to leave the map
            // the screen's full width.
            .ignoresSafeArea(edges: .bottom)
            .containerBackground(for: .navigation) {
                switch display {
                case .worldClock, .analogue, .sunPosition, .weather, .precipitation, .wind, .uvIndex, .humidity, .pressure:
                    CitySkyBackground(date: date, timeZone: city.timeZone)
                case .moonPhase, .solarCurve, .daylight:
                    Color.black
                }
            }
            // Verbatim, so the string catalog doesn't gain an empty key
            .navigationTitle(Text(verbatim: ""))
            .toolbarTitleDisplayMode(.inline)
            .toolbarForegroundStyle(.primary, for: .navigationBar)
            .animation(adjustedDateAnimation, value: adjustedDate)
            .onChange(of: stepOffset) { _, steps in
                if steps == 0 {
                    adjustedDate = crownStart
                    crownReferenceDate = nil
                } else {
                    let referenceDate = crownReferenceDate ?? crownStart ?? .now
                    crownReferenceDate = referenceDate
                    adjustedDate = crownDate(steps, from: referenceDate)
                }
            }
        }
        .tint(.primary)
        // Beside the details rather than around them, since turns for a view
        // inside them, as Weather's days, would reach the time too. And
        // clicking all along rather than only while it moves the time, since
        // a Digital Crown whose haptics have been on keeps clicking with them
        // off again.
        .background {
            Color.clear
                // Not while sliding back to the list: the details would take
                // the Digital Crown back from it, and a quick turn would move
                // the list's clocks rather than scroll it.
                .focusable(isPresented && crownMovesTime)
                .focused($isCrownFocused)
                .digitalCrownRotation(
                    $crownSteps,
                    from: -crownRange,
                    through: crownRange,
                    by: 1,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
        }
        .scrollIndicators(.hidden)
        .navigationBarBackButtonHidden(isAdjusted || showsLaterDay)
        .toolbar {
            // While adjusting time, or showing a day after today, replace the
            // list button with a reset button in the same leading corner.
            if isAdjusted || showsLaterDay {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Current Time", systemImage: "xmark") {
                        currentTimeTaps += 1
                        showCurrentTime()
                        withAnimation(.smooth) {
                            crownDays = 0
                        }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCrownFocused = false
                    showsDisplayPicker = true
                } label: {
                    Image(systemName: display.symbolName)
                        .symbolRenderingMode(.monochrome)
                }
                .accessibilityLabel("Choose View")
                .accessibilityValue(Text(display.title))
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: currentTimeTaps)
        .sheet(isPresented: $showsDisplayPicker, onDismiss: {
            isCrownFocused = crownMovesTime
        }) {
            CityDetailDisplayPicker(cityName: city.name, selection: $display)
        }
        // Each sheet captures its date so the body reads it. Otherwise the
        // sheet opens with the date from before the tap.
        .sheet(isPresented: $showsMoonInfo, onDismiss: {
            isCrownFocused = true
        }) { [moonInfoDate] in
            CityMoonPhasesSheet(date: moonInfoDate, timeZone: city.timeZone, firstWeekday: cityStore.firstWeekday)
        }
        .sheet(isPresented: $showsSunTimes, onDismiss: {
            isCrownFocused = true
        }) { [sunTimesDate] in
            CitySunTimesSheet(date: sunTimesDate, timeZone: city.timeZone, dateStyle: cityStore.dateStyle)
        }
        .onAppear {
            // Weather, Precipitation, Wind, UV Index, Humidity and Pressure
            // show now, even after the analog clock moved every clock.
            if display.showsNow {
                showCurrentTime()
            }
            // Returning from a sheet must keep an in-progress Crown adjustment's anchor.
            if crownSteps == 0 {
                crownStart = adjustedDate
            }
            isCrownFocused = !showsMoonInfo && !showsSunTimes && !showsDisplayPicker && crownMovesTime
        }
        .onChange(of: display) { _, _ in
            // Start the new step size at the displayed date without moving it.
            crownStart = adjustedDate
            crownReferenceDate = nil
            crownSteps = 0
            isLive = false
            showsGlobe = false
            showsWeatherDays = true
            crownDays = 0
            if display.showsNow {
                showCurrentTime()
            }
        }
        .onChange(of: isLive) { _, isLive in
            // Live is now, and today rather than a day after it.
            if isLive {
                showCurrentTime()
                crownDays = 0
            }
            isCrownFocused = crownMovesTime
        }
    }

    /// Back to now on every clock, with the Digital Crown at rest.
    private func showCurrentTime() {
        withAnimation(.smooth) {
            crownStart = nil
            crownReferenceDate = nil
            crownSteps = 0
            adjustedDate = nil
        }
    }

    /// The city's time, with its sunrise and sunset beside it.
    private func clock(date: Date) -> some View {
        let time = ClockTimeText(date: date, timeZone: city.timeZone, alignsLeadingInk: true)
            .foregroundStyle(.white)

        // The sun's times give way on screens too narrow for both
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                time
                Spacer(minLength: 0)
                if let sunTimes = sunTimes(on: date) {
                    SunTimesView(sunrise: sunTimes.sunrise, sunset: sunTimes.sunset, timeZone: city.timeZone)
                        .transition(.blurReplace)
                }
            }
            time
        }
        // The time can shrink to fit, so the stack would otherwise squeeze
        // it to make room for the map
        .fixedSize(horizontal: false, vertical: true)
        // In line with the navigation bar, which clears the screen's rounded
        // corners on every watch size
        .scenePadding(.navigationBar, edges: .horizontal)
    }

    /// The city's day along the bottom of the screen: under World Map's
    /// clock, or centered after the city's time where no clock shows, under
    /// the globe or the solar curve.
    private func dateRow(date: Date, label: String, showsTime: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if showsTime {
                ClockTimeText(date: date, timeZone: city.timeZone, size: .medium)
                    .foregroundStyle(.white)
                    // The date shrinks to fit first
                    .layoutPriority(1)
                    .transition(.blurReplace)
            }

            // Changing within the stack keeps the blend mode outside the
            // blur, which would otherwise grey the date mid-change
            ZStack(alignment: .leading) {
                Text(label)
                    .transition(.blurReplace)
                    .id(label)
            }
            .foregroundStyle(.secondary)
            .blendMode(.plusLighter)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: showsTime ? .center : .leading)
        .fixedSize(horizontal: false, vertical: true)
        .scenePadding(.navigationBar, edges: .horizontal)
        .padding(.bottom, 14)
        .accessibilityElement(children: .combine)
    }

    /// Move by calendar days for Moon Phase, preserving the local time across
    /// daylight-saving changes; other views stop on whole hours as before.
    private func crownDate(_ steps: Int, from date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = city.timeZone
        if display == .moonPhase {
            return calendar.date(byAdding: .day, value: steps, to: date) ?? date
        }
        let hourStart = calendar.dateInterval(of: .hour, for: date)?.start ?? date
        // Turning back, the start of the hour under way is the first stop.
        let hours = steps < 0 && hourStart < date ? steps + 1 : steps
        return hourStart.addingTimeInterval(TimeInterval(hours) * 3600)
    }

    /// The city's sunrise and sunset on `date`'s day, or nil when the sun
    /// stays up or down all day.
    private func sunTimes(on date: Date) -> (sunrise: Date, sunset: Date)? {
        guard let coordinate = TimeZoneCoordinates.getCoordinate(for: city.timeZone.identifier) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = city.timeZone
        guard let day = calendar.dateInterval(of: .day, for: date) else { return nil }

        let events = SolarCalculator.events(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            date: date,
            timeZone: city.timeZone
        )
        // Polar night puts both at noon; polar day pins them to the day's ends
        guard events.sunrise < events.sunset,
              events.sunrise > day.start,
              events.sunset < day.end.addingTimeInterval(-1) else { return nil }
        return (events.sunrise, events.sunset)
    }
}

/// The day's sunrise above its sunset, each after its symbol.
private struct SunTimesView: View {
    let sunrise: Date
    let sunset: Date
    let timeZone: TimeZone

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 3, verticalSpacing: 1) {
            GridRow {
                Image(systemName: "sunrise.fill")
                ClockTimeText(date: sunrise, timeZone: timeZone, size: .small)
            }
            GridRow {
                Image(systemName: "sunset.fill")
                ClockTimeText(date: sunset, timeZone: timeZone, size: .small)
            }
        }
        .font(.caption2)
        .fixedSize()
    }
}
