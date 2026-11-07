//
//  CityWeatherView.swift
//  touchtimeWatch
//

import SwiftUI
import WeatherKit

/// The city's temperature and conditions now, inside a ring of the next 12
/// hours' conditions, laid out like the daylight ring with its hours showing:
/// now at the top right, and each hour after it clockwise. Tapping the middle
/// trades the hours for the days ahead, laid out like the daylight ring
/// without its hours: today at the bottom left, each day after it clockwise,
/// and a dot like its sun that the Digital Crown moves from day to day.
struct CityWeatherView: View {
    let date: Date
    let timeZone: TimeZone
    /// The iPhone app's temperature unit: Celsius, or Fahrenheit when false.
    let useCelsius: Bool
    /// The iPhone app's date style, for `Date.formattedDate(style:)`.
    let dateStyle: String

    @Environment(WatchWeatherStore.self) private var weatherStore
    @Environment(\.isPresented) private var isPresented
    @State private var showsDays = false
    /// How many days after today the Digital Crown has turned to.
    @State private var crownDays: Double = 0
    @FocusState private var isCrownFocused: Bool

    /// The ring's edges, and the line around its hours.
    private static let lineWidth: CGFloat = 1
    private static let lineOpacity = 0.10

    /// The start of the hour under way, the first around the ring.
    private var currentHour: Date {
        WatchWeatherStore.hourStart(of: date)
    }

    var body: some View {
        let weather = weatherStore.weather[timeZone.identifier]
        let isLoading = weather == nil && !weatherStore.unavailableTimeZones.contains(timeZone.identifier)
        let hours = WeatherRing.clockHours(from: currentHour, in: timeZone)
        let days = days(in: weather)
        let chosenDayIndex = min(max(Int(crownDays.rounded()), 0), max(days.count - 1, 0))
        let chosenDay = showsDays && days.indices.contains(chosenDayIndex) ? days[chosenDayIndex] : nil

        VStack(spacing: 0) {
            GeometryReader { geometry in
                // As on the daylight ring, the hours take the footer's place,
                // and the ring shrinks a little to make room for them.
                let hourBandWidth = showsDays ? 0 : WeatherRingHours.bandWidth
                let diameter = max(0, min(geometry.size.width - 16, geometry.size.height) - hourBandWidth * 2)
                // As wide as the daylight ring, or narrower with the hours
                // showing, leaving the middle more room.
                let ringWidth = diameter * (showsDays ? 0.20 : 0.17)
                let holeDiameter = diameter - ringWidth * 2

                ZStack {
                    WeatherRingHours(
                        ringDiameter: diameter,
                        hours: hours,
                        isVisible: !showsDays,
                        lineWidth: Self.lineWidth,
                        lineOpacity: Self.lineOpacity
                    )
                    .accessibilityHidden(true)

                    WeatherRingConditions(
                        diameter: diameter,
                        ringWidth: ringWidth,
                        symbols: chosenDay == nil ? hourSymbols(in: weather) : daySymbols(days, chosen: chosenDayIndex),
                        dotDay: chosenDayIndex,
                        showsDays: chosenDay != nil,
                        lineWidth: Self.lineWidth,
                        lineOpacity: Self.lineOpacity
                    )
                    .accessibilityHidden(true)

                    WeatherRingCenter(
                        conditions: weather?.current,
                        day: chosenDay,
                        isLoading: isLoading,
                        useCelsius: useCelsius
                    )
                    .frame(width: holeDiameter * 0.80)
                    .frame(width: holeDiameter, height: holeDiameter)
                    .contentShape(.circle)
                    .onTapGesture {
                        guard showsDays || !days.isEmpty else { return }
                        if showsDays {
                            withAnimation(.smooth, completionCriteria: .removed) {
                                showsDays = false
                            } completion: {
                                // Back to today once the dot's gone, so it
                                // comes back there rather than travelling
                                // there from the day it left.
                                if !showsDays {
                                    crownDays = 0
                                }
                            }
                        } else {
                            withAnimation(.smooth) {
                                // From today, each time the days show.
                                crownDays = 0
                                showsDays = true
                            }
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }

            // Blended outside the transition, so the date blends with the sky
            // as it blurs in and out too, rather than only once it's in.
            ZStack {
                if let chosenDay {
                    Text(dayLabel(chosenDay))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                        .scenePadding(.navigationBar, edges: .horizontal)
                        // Spaced inside the stack, so the empty stack takes
                        // no room while the hours show.
                        .padding(.top, 8)
                        .transition(.blurReplace)
                }
            }
            .blendMode(.plusLighter)
        }
        // The circle's narrow top fits between the toolbar controls, as the
        // daylight ring's does.
        .padding(.top, -20)
        .padding(.bottom, 8)
        .animation(.smooth, value: weather?.fetchDate)
        .animation(.smooth, value: chosenDayIndex)
        // Held for as long as the weather shows, since the days can't take it
        // the moment they appear, but turned only while they show. As on the
        // details, not while sliding back to the list, so a quick turn
        // scrolls the list rather than the days.
        .focusable(isPresented)
        .focused($isCrownFocused)
        .digitalCrownRotation(
            showsDays ? $crownDays : .constant(0),
            from: 0,
            // Never an empty range, even with a day or none.
            through: Double(max(days.count - 1, 1)),
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: showsDays
        )
        .scrollIndicators(.hidden)
        // A sheet takes the Digital Crown, and doesn't give it back.
        .onAppear {
            isCrownFocused = true
        }
        .onDisappear {
            isCrownFocused = false
        }
        // Every quarter hour, in case the weather has gone stale.
        .onChange(of: Int(date.timeIntervalSinceReferenceDate / 900), initial: true) {
            weatherStore.update(for: timeZone)
        }
    }

    /// The forecast's days from today in the city, as many as go around the
    /// ring.
    private func days(in weather: CityWeather?) -> [CityWeather.Day] {
        guard let weather else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: date)
        return Array(weather.days.filter { $0.date >= today }.prefix(WeatherRing.dayCount))
    }

    /// Right now's conditions for the hour under way, and the forecast's for
    /// the others.
    private func conditions(hoursAhead: Int, in weather: CityWeather?) -> CityWeather.Conditions? {
        guard let weather else { return nil }
        if hoursAhead == 0 {
            return weather.current
        }
        return weather.hours[currentHour.addingTimeInterval(Double(hoursAhead) * 3600)]
    }

    /// Each slot's symbol while the hours show, by day or by night.
    private func hourSymbols(in weather: CityWeather?) -> [String?] {
        var symbols = [String?](repeating: nil, count: WeatherRing.slotCount)
        for hoursAhead in 0..<WeatherRing.hourCount {
            symbols[WeatherRing.slot(hoursAhead: hoursAhead)] = conditions(hoursAhead: hoursAhead, in: weather)
                .map { $0.condition.icon(isDaylight: $0.isDaylight) }
        }
        return symbols
    }

    /// Each slot's symbol while the days show: each day's in its slot, but
    /// the chosen day's at the bottom, leaving its slot to the dot.
    private func daySymbols(_ days: [CityWeather.Day], chosen: Int) -> [String?] {
        var symbols = [String?](repeating: nil, count: WeatherRing.slotCount)
        for (daysAhead, day) in days.enumerated() {
            let slot = daysAhead == chosen ? WeatherRing.chosenDaySlot : WeatherRing.slot(daysAhead: daysAhead)
            symbols[slot] = day.condition.icon
        }
        return symbols
    }

    /// In the iPhone app's date style, weekday and all, as under the details'
    /// other views.
    private func dayLabel(_ day: CityWeather.Day) -> String {
        day.date.formattedDate(style: dateStyle, timeZone: timeZone, relativeTo: date)
    }
}

/// Where the ring's hours and days go around it: in twelve slots like a
/// clock's hours, clockwise from the one at the top.
private enum WeatherRing {
    static let slotCount = 12
    static let hourCount = 12
    /// Today's slot is at the bottom left, and each day after it a slot
    /// further clockwise, round to the bottom right. The chosen day's symbol
    /// goes to the bottom, between them.
    static let dayCount = 9
    static let todaySlot = 8
    static let chosenDaySlot = 6

    /// The city's clock hour for each of the ring's hours, from the one under
    /// way. Read at each hour's middle: where clocks are off UTC's hours, it
    /// starts partway through the clock's hour before the one it ends in.
    static func clockHours(from currentHour: Date, in timeZone: TimeZone) -> [Int] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return (0..<hourCount).map { hoursAhead in
            calendar.component(.hour, from: currentHour.addingTimeInterval((Double(hoursAhead) + 0.5) * 3600))
        }
    }

    /// Now a twelfth of the way around, at the top right, and each hour after
    /// it a twelfth further.
    static func slot(hoursAhead: Int) -> Int {
        (hoursAhead + 1) % slotCount
    }

    static func slot(daysAhead: Int) -> Int {
        (todaySlot + daysAhead) % slotCount
    }

    static func angle(slot: Int) -> Angle {
        .degrees(Double(slot) * 360 / Double(slotCount))
    }

    /// The day's slot's angle, but on past the top rather than back around to
    /// it, so the dot keeps going clockwise from day to day.
    static func angle(daysAhead: Int) -> Angle {
        angle(slot: todaySlot + daysAhead)
    }

    /// Across the ring's bottom half, an hour turns over to read left to right
    /// rather than upside down, as on the daylight ring.
    static func isTurnedOver(slot: Int) -> Bool {
        let degrees = angle(slot: slot).degrees.truncatingRemainder(dividingBy: 360)
        return degrees > 90 && degrees < 270
    }
}

/// Each hour around the outside of the ring, inside a line like its edges,
/// with now on a pill like the daylight ring's current hour. The line comes
/// out from under the ring's edge as the hours blur in, as on the daylight
/// ring.
private struct WeatherRingHours: View {
    /// How far past the ring the hours and their line reach.
    static let bandWidth: CGFloat = 16
    /// The pill's room around "Now", both ends together.
    private static let pillPadding: CGFloat = 11

    let ringDiameter: CGFloat
    /// The city's clock hour for each of the ring's hours, from now.
    let hours: [Int]
    let isVisible: Bool
    let lineWidth: CGFloat
    let lineOpacity: Double

    @AppStorage(WatchTimeFormat.use24HourFormatKey) private var use24HourFormat = WatchTimeFormat.systemUses24HourFormat

    var body: some View {
        let bandWidth = isVisible ? Self.bandWidth : 0
        let diameter = ringDiameter + bandWidth * 2
        // Halfway between the ring's edge and the line around the hours.
        let radius = (ringDiameter + bandWidth - lineWidth) / 2
        let nowSlot = WeatherRing.slot(hoursAhead: 0)

        ZStack {
            Circle()
                .strokeBorder(.white.opacity(lineOpacity), lineWidth: lineWidth)
                .blendMode(.plusLighter)
                .frame(width: diameter, height: diameter)
                .opacity(isVisible ? 1 : 0)

            // Transitioning inside the placement scales each hour, and the
            // pill, about itself rather than the ring's center.
            ZStack {
                if isVisible {
                    // Cut out of its pill, so the sky shows through.
                    Text("Now")
                        .blendMode(.destinationOut)
                        .background {
                            GeometryReader { label in
                                HourPill(
                                    radius: radius,
                                    length: label.size.width + Self.pillPadding,
                                    // From the ring's edge to the line, overlapping
                                    // each a little so no seam shows between them.
                                    thickness: Self.bandWidth - lineWidth + 1,
                                    isTurnedOver: WeatherRing.isTurnedOver(slot: nowSlot)
                                )
                                .fill(.white)
                            }
                        }
                        .compositingGroup()
                        .transition(.blurReplace)
                }
            }
            .placed(slot: nowSlot, radius: radius, turnsAlong: true)

            ForEach(1..<hours.count, id: \.self) { hoursAhead in
                ZStack {
                    if isVisible {
                        Text(WatchTimeFormat.dialHour(hours[hoursAhead], use24HourFormat: use24HourFormat))
                            .transition(.blurReplace)
                    }
                }
                .placed(slot: WeatherRing.slot(hoursAhead: hoursAhead), radius: radius, turnsAlong: true)
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(.primary)
    }
}

/// The ring's edges, and between them each slot's symbol, and while the days
/// show, a dot like the daylight ring's sun on the chosen day.
private struct WeatherRingConditions: View {
    let diameter: CGFloat
    let ringWidth: CGFloat
    /// Each slot's symbol from the top, or nil where none shows, or until its
    /// weather comes in.
    let symbols: [String?]
    /// The chosen day, in days after today, where the dot waits while hidden.
    let dotDay: Int
    /// Whether the days, and with them the dot, show.
    let showsDays: Bool
    let lineWidth: CGFloat
    let lineOpacity: Double

    var body: some View {
        // Through the middle of the ring.
        let radius = (diameter - ringWidth) / 2

        ZStack {
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(lineOpacity), lineWidth: lineWidth)
                Circle()
                    .inset(by: ringWidth)
                    .stroke(.white.opacity(lineOpacity), lineWidth: lineWidth)
            }
            .blendMode(.plusLighter)

            ForEach(symbols.indices, id: \.self) { slot in
                ZStack {
                    // Sized even while empty, so an arriving symbol comes in
                    // where it sits rather than sliding from the empty
                    // stack's center.
                    Color.clear
                    if let symbol = symbols[slot] {
                        ZStack {
                            Image(systemName: symbol)
                                // Sized here rather than around the ring, so a
                                // symbol going away keeps its size as it goes
                                // rather than taking the ring's next.
                                .font(.system(size: ringWidth * 0.5))
                                .contentTransition(.symbolEffect(.replace))
                                // A new symbol between the hours and the days,
                                // even where it's the same one, so each turns
                                // over with the others rather than only
                                // growing or shrinking with the ring.
                                .id(showsDays)
                                .transition(.symbolEffect)
                        }
                        .transition(.blurReplace)
                    }
                }
                .frame(width: ringWidth, height: ringWidth)
                .placed(slot: slot, radius: radius, turnsAlong: false)
            }
            .symbolRenderingMode(.multicolor)
            .foregroundStyle(.primary)

            // Placed even while hidden, so the dot comes and goes on its slot
            // as the ring grows and shrinks, scaling about itself rather than
            // the ring's center.
            let angle = WeatherRing.angle(daysAhead: dotDay)
            ZStack {
                if showsDays {
                    Circle()
                        .fill(.white)
                        .background {
                            // As under the daylight ring's sun.
                            Circle()
                                .fill(.black.opacity(0.05))
                                .blur(radius: 5)
                                .offset(y: 2.5)
                                .blendMode(.plusDarker)
                        }
                        .transition(.scale(scale: 0.4).combined(with: AnyTransition(.blurReplace)))
                }
            }
            .frame(width: ringWidth * 0.60, height: ringWidth * 0.60)
            // Carried around the ring by turning, so it follows the ring from
            // day to day, and turned back as it goes so its shadow keeps
            // falling downward.
            .rotationEffect(-angle)
            .offset(y: -radius)
            .rotationEffect(angle)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// The temperature over the conditions now, in the middle of the ring, or
/// while the days show, the chosen day's high and low over its conditions.
private struct WeatherRingCenter: View {
    let conditions: CityWeather.Conditions?
    let day: CityWeather.Day?
    let isLoading: Bool
    let useCelsius: Bool

    var body: some View {
        ZStack {
            // One view for now and the days, so going between them resizes
            // and moves the text rather than replacing it.
            if let temperature = day?.highTemperature ?? conditions?.temperature,
               let condition = day?.condition ?? conditions?.condition {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text(Self.temperature(temperature, useCelsius: useCelsius))
                        // As the footer's date, blended outside the
                        // transition, and spaced inside the stack so the empty
                        // stack takes no room.
                        ZStack {
                            if let day {
                                Text(Self.temperature(day.lowTemperature, useCelsius: useCelsius))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                                    .transition(.blurReplace)
                            }
                        }
                        .blendMode(.plusLighter)
                    }
                    // The days in the daylight ring's time's font, now a size
                    // larger.
                    .font(.system(day == nil ? .title2 : .title3, design: .rounded, weight: .medium).monospacedDigit())
                    .contentTransition(.numericText())

                    conditionName(condition.displayName)
                }
                .transition(.blurReplace)
            } else if isLoading {
                ProgressView()
                    .transition(.blurReplace)
            } else {
                Text(verbatim: "--°")
                    .font(.system(.title2, design: .rounded, weight: .medium))
                    .transition(.blurReplace)
            }
        }
        .foregroundStyle(.primary)
        .lineLimit(1)
        // The temperature at the largest text sizes on the smallest watch.
        .minimumScaleFactor(0.4)
        .accessibilityElement(children: .combine)
    }

    private func conditionName(_ name: String) -> some View {
        ZStack {
            MarqueeText(name)
                .id(name)
                .transition(.blurReplace)
        }
        .font(.footnote.weight(.medium))
        // Lower in the ring than the temperature, where it's narrower.
        .padding(.horizontal, 4)
    }

    /// In whole degrees toward zero, without the unit's letter, as the iPhone
    /// app shows them.
    private static func temperature(_ temperature: Measurement<UnitTemperature>, useCelsius: Bool) -> String {
        let value = temperature.converted(to: useCelsius ? .celsius : .fahrenheit).value
        guard value.isFinite else { return "--°" }
        return "\(Int(value))°"
    }
}

private extension View {
    /// At a slot around a circle of `radius`, turned along it or upright.
    func placed(slot: Int, radius: CGFloat, turnsAlong: Bool) -> some View {
        let angle = WeatherRing.angle(slot: slot)
        let turn = WeatherRing.isTurnedOver(slot: slot) ? angle - .degrees(180) : angle
        return rotationEffect(turnsAlong ? turn : .zero)
            .offset(x: radius * sin(angle.radians), y: -radius * cos(angle.radians))
    }
}

#Preview {
    let date = Date.now
    let currentHour = WatchWeatherStore.hourStart(of: date)
    let forecast: [(Double, WeatherCondition)] = [
        (16, .cloudy), (15, .mostlyCloudy), (15, .partlyCloudy), (14, .mostlyClear),
        (13, .clear), (12, .clear), (12, .clear), (12, .partlyCloudy),
        (13, .drizzle), (14, .rain), (15, .rain), (16, .cloudy)
    ]
    let hours = Dictionary(uniqueKeysWithValues: forecast.enumerated().map { index, hour in
        let start = currentHour.addingTimeInterval(Double(index) * 3600)
        return (
            start,
            CityWeather.Conditions(
                temperature: Measurement(value: hour.0, unit: .celsius),
                condition: hour.1,
                isDaylight: (6..<18).contains(Calendar.current.component(.hour, from: start))
            )
        )
    })
    let dailyForecast: [(Double, Double, WeatherCondition)] = [
        (9, 3, .mostlyCloudy), (11, 5, .rain), (10, 4, .drizzle), (12, 6, .partlyCloudy), (14, 7, .clear),
        (13, 8, .mostlyClear), (11, 6, .cloudy), (9, 4, .rain), (6, 1, .snow), (8, 2, .partlyCloudy)
    ]
    let today = Calendar.current.startOfDay(for: date)
    let days = dailyForecast.enumerated().map { index, day in
        CityWeather.Day(
            date: Calendar.current.date(byAdding: .day, value: index, to: today)!,
            highTemperature: Measurement(value: day.0, unit: .celsius),
            lowTemperature: Measurement(value: day.1, unit: .celsius),
            condition: day.2
        )
    }
    let weather = CityWeather(current: hours[currentHour]!, hours: hours, days: days, fetchDate: date)

    NavigationStack {
        CityWeatherView(date: date, timeZone: .current, useCelsius: true, dateStyle: "Relative")
            .ignoresSafeArea(edges: .bottom)
            .containerBackground(for: .navigation) {
                CitySkyBackground(date: date, timeZone: .current)
            }
    }
    .environment(WatchWeatherStore(weather: [TimeZone.current.identifier: weather]))
}
