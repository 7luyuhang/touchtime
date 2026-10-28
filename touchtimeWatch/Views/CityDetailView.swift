//
//  CityDetailView.swift
//  touchtimeWatch
//
//  A city's clock over its sky, below the day/night world map. Turning the
//  Digital Crown moves the time an hour at a time.
//

import SwiftUI

struct CityDetailView: View {
    let city: ClockCity
    /// Every clock, each dotted on the map.
    let mapCities: [ClockCity]
    /// The time every clock shows in place of now, or nil for now.
    @Binding var adjustedDate: Date?

    @Environment(WatchCityStore.self) private var cityStore
    /// How far the Digital Crown has moved the time, in hours.
    @State private var crownHours: Double = 0
    /// The time the Digital Crown's hours count from: the clocks' time when
    /// it last rested at zero, or nil for now.
    @State private var crownStart: Date?
    @FocusState private var isCrownFocused: Bool

    /// How many hours the Digital Crown can move the time, either way.
    private static let crownRange: Double = 24

    private var hourOffset: Int {
        Int(crownHours.rounded())
    }

    private var isAdjusted: Bool {
        adjustedDate != nil
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = adjustedDate ?? context.date

            VStack(alignment: .leading, spacing: 4) {
                CityMapView(
                    date: date,
                    timeZoneIdentifiers: mapCities.map(\.timeZone.identifier),
                    highlightedTimeZoneIdentifier: city.timeZone.identifier
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                summary(date: date, now: context.date)
            }
            // Like World Clock, the clock sits low enough to leave the map
            // the screen's full width
            .ignoresSafeArea(edges: .bottom)
            .containerBackground(for: .navigation) {
                CitySkyBackground(date: date, timeZone: city.timeZone)
            }
            .navigationTitle(city.name)
            .animation(.smooth, value: adjustedDate)
            .onChange(of: hourOffset) { _, hours in
                adjustedDate = hours == 0 ? crownStart : wholeHour(hours, from: crownStart ?? context.date)
            }
        }
        .focusable()
        .focused($isCrownFocused)
        .digitalCrownRotation(
            $crownHours,
            from: -Self.crownRange,
            through: Self.crownRange,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .toolbar {
            // The list button keeps the leading corner, so the time can be
            // taken back to the list
            if isAdjusted {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Current Time", systemImage: "xmark") {
                        withAnimation(.smooth) {
                            crownStart = nil
                            crownHours = 0
                            adjustedDate = nil
                        }
                    }
                }
            }
        }
        .onAppear {
            crownStart = adjustedDate
            isCrownFocused = true
        }
    }

    private func summary(date: Date, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            let time = ClockTimeText(date: date, timeZone: city.timeZone)
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

    /// The whole hour on the city's clock `hours` hours from `date`, counting
    /// from the hour under way.
    private func wholeHour(_ hours: Int, from date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = city.timeZone
        let hourStart = calendar.dateInterval(of: .hour, for: date)?.start ?? date
        // Turning back, the start of the hour under way is the first stop
        let steps = hours < 0 && hourStart < date ? hours + 1 : hours
        return hourStart.addingTimeInterval(TimeInterval(steps) * 3600)
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
                    .foregroundStyle(.tint)
                ClockTimeText(date: sunrise, timeZone: timeZone, size: .small)
            }
            GridRow {
                Image(systemName: "sunset.fill")
                    .foregroundStyle(.tint)
                ClockTimeText(date: sunset, timeZone: timeZone, size: .small)
            }
        }
        .font(.caption2)
        .fixedSize()
    }
}
