//
//  CityDetailView.swift
//  touchtimeWatch
//
//  A city's world clock, moon phase, solar curve, sun position, or daylight.
//  Turning the Digital Crown moves a day at a time in Moon Phase, and an hour
//  in the other views, except in Sun Position's live compass, which shows now.
//

import SwiftUI

struct CityDetailView: View {
    let city: ClockCity
    /// Every clock, each dotted on the map.
    let mapCities: [ClockCity]
    /// The time every clock shows in place of now, or nil for now.
    @Binding var adjustedDate: Date?

    @Environment(WatchCityStore.self) private var cityStore
    @AppStorage("watchDetailDisplay") private var display: CityDetailDisplay = .worldClock
    @State private var showsDisplayPicker = false
    @State private var showsMoonInfo = false
    @State private var moonInfoDate = Date()
    @State private var showsLiveCompass = false
    /// Whether World Clock's map has turned, or is turning, into the globe.
    @State private var showsGlobe = false
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

                        dateRow(date: date, label: WatchTimeFormat.dayAndOffset(
                            date, in: city.timeZone, now: context.date, dateStyle: cityStore.dateStyle
                        ))
                    }
                    .accessibilityElement(children: .combine)
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
                    CitySolarCurveView(
                        date: date,
                        timeZone: city.timeZone,
                        dateLabel: dateLabel
                    )
                case .sunPosition:
                    CitySunPositionView(
                        date: date,
                        timeZone: city.timeZone,
                        dateLabel: shortDateLabel,
                        isAdjusting: isAdjusted,
                        isLive: $showsLiveCompass
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
                }
            }
            // Like World Clock, the clock sits low enough to leave the map
            // the screen's full width.
            .ignoresSafeArea(edges: .bottom)
            .containerBackground(for: .navigation) {
                switch display {
                case .worldClock, .sunPosition:
                    CitySkyBackground(date: date, timeZone: city.timeZone)
                case .moonPhase, .solarCurve, .daylight:
                    Color.black
                }
            }
            .navigationTitle {
                if display == .solarCurve, let adjustedDate {
                    CrownTimeTitle(date: adjustedDate, timeZone: city.timeZone)
                        .transition(.blurReplace)
                        .allowsHitTesting(false)
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbarForegroundStyle(.primary, for: .navigationBar)
            .animation(.smooth, value: adjustedDate)
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
        .focusable(!showsLiveCompass)
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
        .scrollIndicators(.hidden)
        .navigationBarBackButtonHidden(isAdjusted)
        .toolbar {
            // While adjusting time, replace the list button with a reset
            // button in the same leading corner.
            if isAdjusted {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Current Time", systemImage: "xmark", action: showCurrentTime)
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
        .sheet(isPresented: $showsDisplayPicker, onDismiss: {
            isCrownFocused = !showsLiveCompass
        }) {
            CityDetailDisplayPicker(cityName: city.name, selection: $display)
        }
        .sheet(isPresented: $showsMoonInfo, onDismiss: {
            isCrownFocused = true
        }) {
            CityMoonPhasesSheet(date: moonInfoDate, timeZone: city.timeZone)
        }
        .onAppear {
            // Returning from a sheet must keep an in-progress Crown adjustment's anchor.
            if crownSteps == 0 {
                crownStart = adjustedDate
            }
            isCrownFocused = !showsMoonInfo && !showsDisplayPicker && !showsLiveCompass
        }
        .onChange(of: display) { _, _ in
            // Start the new step size at the displayed date without moving it.
            crownStart = adjustedDate
            crownReferenceDate = nil
            crownSteps = 0
            showsLiveCompass = false
            showsGlobe = false
        }
        .onChange(of: showsLiveCompass) { _, showsLiveCompass in
            if showsLiveCompass {
                showCurrentTime()
            }
            isCrownFocused = !showsLiveCompass
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

    /// The city's day under the clock, or centered under the globe after the
    /// city's time once the clock has made way for the globe.
    private func dateRow(date: Date, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if showsGlobe {
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
        .frame(maxWidth: .infinity, alignment: showsGlobe ? .center : .leading)
        .fixedSize(horizontal: false, vertical: true)
        .scenePadding(.navigationBar, edges: .horizontal)
        .padding(.bottom, 14)
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

/// Show the selected time as a plain navigation title while adjusting it.
private struct CrownTimeTitle: View {
    let date: Date
    let timeZone: TimeZone

    @Environment(\.locale) private var locale

    var body: some View {
        let formattedTime = WatchTimeFormat.time(date, in: timeZone, hourCycle: locale.hourCycle)

        Text(formattedTime.digits)
            .foregroundStyle(.white)
            .monospacedDigit()
            .fixedSize()
            .contentTransition(.numericText())
            .animation(.smooth(duration: 0.25), value: formattedTime.digits)
            .accessibilityLabel([formattedTime.digits, formattedTime.period].compactMap { $0 }.joined(separator: " "))
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
