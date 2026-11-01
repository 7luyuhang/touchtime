//
//  CityDetailView.swift
//  touchtimeWatch
//
//  A city's world clock, moon phase, solar curve, or daylight. Turning the Digital
//  Crown moves a day at a time in Moon Phase, and an hour in the other views.
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

            Group {
                switch display {
                case .worldClock:
                    VStack(alignment: .leading, spacing: 4) {
                        CityMapView(
                            date: date,
                            timeZoneIdentifiers: mapCities.map(\.timeZone.identifier),
                            highlightedTimeZoneIdentifier: city.timeZone.identifier
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                        summary(date: date, now: context.date)
                    }
                case .moonPhase:
                    CityMoonPhaseView(date: date, timeZone: city.timeZone) {
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
                        referenceDate: isAdjusted ? context.date : nil
                    )
                case .daylight:
                    CityDaylightView(
                        date: date,
                        timeZone: city.timeZone,
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
                case .worldClock:
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
        .focusable()
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
                    Button("Current Time", systemImage: "xmark") {
                        withAnimation(.smooth) {
                            crownStart = nil
                            crownReferenceDate = nil
                            crownSteps = 0
                            adjustedDate = nil
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
                }
                .accessibilityLabel("Choose View")
                .accessibilityValue(Text(display.title))
            }
        }
        .sheet(isPresented: $showsDisplayPicker, onDismiss: {
            isCrownFocused = true
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
            isCrownFocused = !showsMoonInfo && !showsDisplayPicker
        }
        .onChange(of: display) { _, _ in
            // Start the new step size at the displayed date without moving it.
            crownStart = adjustedDate
            crownReferenceDate = nil
            crownSteps = 0
        }
    }

    private func summary(date: Date, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            let time = ClockTimeText(date: date, timeZone: city.timeZone, alignsLeadingInk: true)
                .foregroundStyle(.white)

            // The sun's times give way on screens too narrow for both
            ViewThatFits(in: .horizontal) {
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

            let dayAndOffset = WatchTimeFormat.dayAndOffset(date, in: city.timeZone, now: now, dateStyle: cityStore.dateStyle)
            // Changing within the stack keeps the blend mode outside the
            // blur, which would otherwise grey the date mid-change
            ZStack(alignment: .leading) {
                Text(dayAndOffset)
                    .transition(.blurReplace)
                    .id(dayAndOffset)
            }
            .foregroundStyle(.secondary)
            .blendMode(.plusLighter)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        // The time can shrink to fit, so the outer stack would otherwise
        // squeeze it to make room for the map
        .fixedSize(horizontal: false, vertical: true)
        // In line with the navigation bar, which clears the screen's rounded
        // corners on every watch size
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
