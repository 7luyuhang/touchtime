//
//  CityWeatherView.swift
//  touchtimeWatch
//

import SwiftUI
import WeatherKit

/// The city's days ahead around a ring, laid out like the daylight ring
/// without its hours: today at the bottom left, each day after it clockwise,
/// and a mark on the ring's inner edge that the Digital Crown moves from day
/// to day. In the middle, the chosen day's low and high over its conditions,
/// and between the days' ends at the bottom, an arc showing them.
/// Tapping the middle trades the days for the temperature and conditions now,
/// inside a ring of the next 12 hours' conditions, laid out like the daylight
/// ring with its hours showing: now at its hour, as on a clock's face, where
/// the ring is rounded off, and each hour after it clockwise.
struct CityWeatherView: View {
    let date: Date
    let timeZone: TimeZone
    /// The iPhone app's temperature unit: Celsius, or Fahrenheit when false.
    let useCelsius: Bool
    /// The iPhone app's date style, for `Date.formattedDate(style:)`.
    let dateStyle: String

    @Environment(WatchWeatherStore.self) private var weatherStore
    @Environment(\.isPresented) private var isPresented
    @State private var showsDays = true
    /// How many days after today the Digital Crown has turned to.
    @State private var crownDays: Double = 0
    @FocusState private var crownHolder: CrownHolder?

    /// Who has the Digital Crown: the hours, doing nothing with it, or the
    /// days, turning from one to the next.
    private enum CrownHolder {
        case hours
        case days
    }

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
                        symbols: showsDays
                            ? daySymbols(days)
                            : hourSymbols(in: weather, nowHour: hours[0]),
                        nowSlot: WeatherRing.slot(hoursAhead: 0, nowHour: hours[0]),
                        chosenDay: chosenDayIndex,
                        showsDays: showsDays,
                        lineWidth: Self.lineWidth,
                        lineOpacity: Self.lineOpacity
                    )
                    .accessibilityHidden(true)

                    WeatherRingTemperatures(
                        diameter: diameter,
                        ringWidth: ringWidth,
                        days: days,
                        chosenDay: chosenDayIndex,
                        temperature: weather?.current.temperature,
                        isVisible: chosenDay != nil
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
                        if !showsDays {
                            // From today each time the days show, the mark
                            // appearing there rather than travelling there
                            // from the day it left, however soon it's back.
                            var reset = Transaction()
                            reset.disablesAnimations = true
                            withTransaction(reset) {
                                crownDays = 0
                            }
                        }
                        withAnimation(.smooth) {
                            showsDays.toggle()
                        }
                        crownHolder = showsDays ? .days : .hours
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }

            // Blended outside the transition, so the date blends with the sky
            // as it blurs in and out too, rather than only once it's in.
            ZStack {
                if showsDays {
                    // Today's until the days come in, so the ring needn't
                    // shrink to make room for the date once they do.
                    Text(dayLabel(chosenDay?.date ?? date))
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
        // A holder each for the hours and the days rather than one changing
        // between them, since a Digital Crown whose haptics have been on
        // keeps clicking with them off again. Both can take it for as long
        // as the weather shows, since the days can't the moment they appear.
        // As on the details, not while sliding back to the list, so a quick
        // turn scrolls the list rather than the days.
        .background {
            Color.clear
                .focusable(isPresented)
                .focused($crownHolder, equals: .hours)
                .digitalCrownRotation(.constant(0), from: 0, through: 1, isHapticFeedbackEnabled: false)
            Color.clear
                .focusable(isPresented)
                .focused($crownHolder, equals: .days)
                .digitalCrownRotation(
                    $crownDays,
                    from: 0,
                    // Never an empty range, even with a day or none.
                    through: Double(max(days.count - 1, 1)),
                    by: 1,
                    // Less than the time's, so each day takes a turn of its
                    // own rather than a flick passing several.
                    sensitivity: .low,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
        }
        .scrollIndicators(.hidden)
        // A sheet takes the Digital Crown, and doesn't give it back.
        .onAppear {
            crownHolder = showsDays ? .days : .hours
        }
        .onDisappear {
            crownHolder = nil
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
    private func hourSymbols(in weather: CityWeather?, nowHour: Int) -> [String?] {
        var symbols = [String?](repeating: nil, count: WeatherRing.slotCount)
        for hoursAhead in 0..<WeatherRing.hourCount {
            symbols[WeatherRing.slot(hoursAhead: hoursAhead, nowHour: nowHour)] = conditions(hoursAhead: hoursAhead, in: weather)
                .map { $0.condition.icon(isDaylight: $0.isDaylight) }
        }
        return symbols
    }

    /// Each slot's symbol while the days show: each day's in its slot,
    /// leaving the bottom to the chosen day's temperatures.
    private func daySymbols(_ days: [CityWeather.Day]) -> [String?] {
        var symbols = [String?](repeating: nil, count: WeatherRing.slotCount)
        for (daysAhead, day) in days.enumerated() {
            symbols[WeatherRing.slot(daysAhead: daysAhead)] = day.condition.icon
        }
        return symbols
    }

    /// In the iPhone app's date style, weekday and all, as under the details'
    /// other views.
    private func dayLabel(_ day: Date) -> String {
        day.formattedDate(style: dateStyle, timeZone: timeZone, relativeTo: date)
    }
}

/// Where the ring's hours and days go around it: in twelve slots like a
/// clock's hours, clockwise from the one at the top.
private enum WeatherRing {
    static let slotCount = 12
    static let hourCount = 12
    /// Today's slot is at the bottom left, and each day after it a slot
    /// further clockwise, round to the bottom right, leaving the bottom
    /// between them to the chosen day's temperatures.
    static let dayCount = 9
    static let todaySlot = 8

    /// The days' ends, half a slot past the last day's and before today's,
    /// where dividers set them apart from the temperatures between them.
    static let dayEndAngles: [Angle] = [
        .degrees((Double(todaySlot + dayCount - 1) + 0.5) * 360 / Double(slotCount)),
        .degrees((Double(todaySlot) - 0.5) * 360 / Double(slotCount))
    ]

    /// How thick the chosen day's mark and the arc of its temperatures are.
    static func markWidth(ringWidth: CGFloat) -> CGFloat {
        ringWidth * 0.10
    }

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

    /// Now at its clock hour, `nowHour`, as on a clock's face, and each hour
    /// after it a twelfth further, even where a clock change repeats or skips
    /// an hour, so none share a slot.
    static func slot(hoursAhead: Int, nowHour: Int) -> Int {
        (nowHour + hoursAhead) % slotCount
    }

    static func slot(daysAhead: Int) -> Int {
        (todaySlot + daysAhead) % slotCount
    }

    static func angle(slot: Int) -> Angle {
        .degrees(Double(slot) * 360 / Double(slotCount))
    }

    /// The day's slot's angle, but on past the top rather than back around to
    /// it, so the mark keeps going clockwise from day to day.
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
        let nowSlot = WeatherRing.slot(hoursAhead: 0, nowHour: hours[0])

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
                .placed(slot: WeatherRing.slot(hoursAhead: hoursAhead, nowHour: hours[0]), radius: radius, turnsAlong: true)
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(.primary)
        // Cut off inside the ring's edge, as though under the ring like the
        // daylight ring's hours, so they don't blur across its symbols as it
        // grows over them. Clear of the pill, which reaches into the edge.
        .clipShape(WeatherRingOutside(diameter: ringDiameter - lineWidth * 2), style: FillStyle(eoFill: true))
    }
}

/// Everywhere around a circle of `diameter` in the middle, out past the
/// rect's edges to whatever blurs beyond them.
private struct WeatherRingOutside: Shape {
    var diameter: CGFloat

    var animatableData: CGFloat {
        get { diameter }
        set { diameter = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect.insetBy(dx: -rect.width, dy: -rect.height))
        path.addEllipse(in: CGRect(
            x: rect.midX - diameter / 2,
            y: rect.midY - diameter / 2,
            width: diameter,
            height: diameter
        ))
        return path
    }
}

/// The ring's edges, and between them each slot's symbol. While the hours
/// show, a half circle rounds the ring off at now, between it and the last
/// hour, lit as Pressure's arc is around its ring, the light fading over the
/// hours after now, and while the days show, dividers set off their ends and
/// a mark on the inner edge sits under the chosen day.
private struct WeatherRingConditions: View {
    /// At now, where the light's brightest.
    private static let glowOpacity = 0.10
    /// How far the light at now would reach over the hours after it before
    /// it's faded away, in degrees around the ring.
    private static let glowReach = 120.0

    let diameter: CGFloat
    let ringWidth: CGFloat
    /// Each slot's symbol from the top, or nil where none shows, or until its
    /// weather comes in.
    let symbols: [String?]
    /// Now's slot, where the hours start.
    let nowSlot: Int
    /// The chosen day, in days after today, where the mark waits while hidden.
    let chosenDay: Int
    /// Whether the days, and with them the mark, show.
    let showsDays: Bool
    let lineWidth: CGFloat
    let lineOpacity: Double

    var body: some View {
        // Through the middle of the ring.
        let radius = (diameter - ringWidth) / 2

        ZStack {
            // From the outer edge's line to the inner edge's, so it rounds
            // off along the half circle at now.
            RingGlow(
                bandWidth: ringWidth - lineWidth / 2,
                opacity: Self.glowOpacity,
                reach: Self.glowReach,
                counterclockwiseLength: 0,
                clockwiseLength: Self.glowReach
            )
            .frame(width: diameter - lineWidth, height: diameter - lineWidth)
            .rotationEffect(WeatherRing.angle(slot: nowSlot))
            .opacity(showsDays ? 0 : 1)
            .blendMode(.plusLighter)

            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: lineWidth)
                Circle()
                    .inset(by: ringWidth)
                    .stroke(.white, lineWidth: lineWidth)
                WeatherRingNowCap(angle: WeatherRing.angle(slot: nowSlot), ringWidth: ringWidth, lineWidth: lineWidth)
                    .stroke(.white, lineWidth: lineWidth)
                    .opacity(showsDays ? 0 : 1)
                WeatherRingDividers(angles: WeatherRing.dayEndAngles, ringWidth: ringWidth, lineWidth: lineWidth)
                    .stroke(.white, lineWidth: lineWidth)
                    .opacity(showsDays ? 1 : 0)
            }
            // Faded as one, so the lines show no brighter where they run
            // into each other.
            .compositingGroup()
            .opacity(lineOpacity)
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

            let markWidth = WeatherRing.markWidth(ringWidth: ringWidth)
            // A slot long from one edge to the other, caps and all, so today's
            // ends where the days' divider meets the inner edge.
            let markHalfLength = 1 / Double(WeatherRing.slotCount * 2)
                - markWidth / 2 / (.pi * max(diameter - ringWidth * 2, 1))
            Circle()
                .inset(by: ringWidth)
                // Around the top, where a circle's path is three quarters of
                // the way round.
                .trim(from: 0.75 - markHalfLength, to: 0.75 + markHalfLength)
                .stroke(.primary, style: StrokeStyle(lineWidth: markWidth, lineCap: .round))
                // Carried around the ring by turning, so it follows the ring
                // from day to day.
                .rotationEffect(WeatherRing.angle(daysAhead: chosenDay))
                // Out of sight rather than gone while the hours show, so it
                // comes and goes under its day as the ring grows and shrinks.
                .blur(radius: showsDays ? 0 : ringWidth * 0.2)
                .opacity(showsDays ? 1 : 0)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// A half circle across the ring, from its inner edge's line to its outer
/// edge's, round the middle of the slot at `angle`, from the top, clockwise,
/// on the slot's counterclockwise side, like the round end of a pill.
private struct WeatherRingNowCap: Shape {
    let angle: Angle
    var ringWidth: CGFloat
    let lineWidth: CGFloat

    var animatableData: CGFloat {
        get { ringWidth }
        set { ringWidth = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // The outer edge's line is stroked inside its circle, and the inner
        // edge's across its own.
        let outerRadius = min(rect.width, rect.height) / 2 - lineWidth / 2
        let innerRadius = min(rect.width, rect.height) / 2 - ringWidth
        let middle = (outerRadius + innerRadius) / 2
        var path = Path()
        // From the inner edge's line, round to the outer's.
        path.addRelativeArc(
            center: CGPoint(x: rect.midX + middle * sin(angle.radians), y: rect.midY - middle * cos(angle.radians)),
            radius: (outerRadius - innerRadius) / 2,
            startAngle: angle + .degrees(90),
            delta: .degrees(180)
        )
        return path
    }
}

/// Lines across the ring at each of `angles`, from the top, clockwise, from
/// its inner edge's line to its outer edge's, meeting them without
/// overlapping them.
private struct WeatherRingDividers: Shape {
    let angles: [Angle]
    var ringWidth: CGFloat
    let lineWidth: CGFloat

    var animatableData: CGFloat {
        get { ringWidth }
        set { ringWidth = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let outerRadius = min(rect.width, rect.height) / 2
        // The inner edge's line is stroked across its circle, and the outer
        // edge's inside it.
        let start = outerRadius - ringWidth + lineWidth / 2
        let end = outerRadius - lineWidth
        var path = Path()
        for angle in angles {
            let direction = CGVector(dx: sin(angle.radians), dy: -cos(angle.radians))
            path.move(to: CGPoint(x: rect.midX + direction.dx * start, y: rect.midY + direction.dy * start))
            path.addLine(to: CGPoint(x: rect.midX + direction.dx * end, y: rect.midY + direction.dy * end))
        }
        return path
    }
}

/// At the ring's bottom, between the days' ends, an arc from the days'
/// lowest temperature at its left to their highest at its right, colored from
/// the chosen day's low to its high in the Weather app's colors for each
/// temperature, and on today's, a dot at the temperature now. Every day shares
/// the arc, as the Weather app's bars do, so turning from day to day moves the
/// color along it.
private struct WeatherRingTemperatures: View {
    let diameter: CGFloat
    let ringWidth: CGFloat
    let days: [CityWeather.Day]
    /// The chosen day, in days after today, whose temperatures stay while
    /// hidden.
    let chosenDay: Int
    /// The temperature now, dotted on today's.
    let temperature: Measurement<UnitTemperature>?
    let isVisible: Bool

    var body: some View {
        // The temperature now too, so its dot is on the arc even where it's
        // past today's forecast.
        let celsius = (days.flatMap { [$0.lowTemperature, $0.highTemperature] } + [temperature].compactMap { $0 })
            .map { $0.converted(to: .celsius).value }
        let lowest = celsius.min() ?? 0
        // Never an empty span, even where every day's the same.
        let scale = Scale(lowest: lowest, highest: max(celsius.max() ?? 0, lowest + 1))
        let day = days.indices.contains(chosenDay) ? days[chosenDay] : nil
        let lineWidth = WeatherRing.markWidth(ringWidth: ringWidth)
        // Through the middle of the ring.
        let arc = Circle().inset(by: ringWidth / 2)
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        let dotAngle = Angle.degrees(360 * (temperature.map(scale.fraction) ?? Scale.lowEnd))
        let dotOffset = CGSize(
            width: (diameter - ringWidth) / 2 * cos(dotAngle.radians),
            height: (diameter - ringWidth) / 2 * sin(dotAngle.radians)
        )

        // Each layer fades out of sight rather than going while the hours
        // show, so it grows and shrinks with the ring as it comes and goes.
        ZStack {
            // Lighter where the sky is, as the ring's lines are, but on its
            // own, since the color on it would wash out.
            ZStack {
                arc
                    .trim(from: Scale.highEnd, to: Scale.lowEnd)
                    .stroke(.white.opacity(0.10), style: style)
                dot(lineWidth: lineWidth, isHole: true)
                    .offset(dotOffset)
            }
            .compositingGroup()
            .blur(radius: isVisible ? 0 : ringWidth * 0.2)
            .opacity(isVisible ? 1 : 0)
            .blendMode(.plusLighter)

            ZStack {
                if let day {
                    arc
                        .trim(from: scale.fraction(day.highTemperature), to: scale.fraction(day.lowTemperature))
                        .stroke(scale.gradient, style: style)
                }
                dot(lineWidth: lineWidth, isHole: false)
                    .offset(dotOffset)
            }
            .compositingGroup()
            .blur(radius: isVisible ? 0 : ringWidth * 0.2)
            .opacity(isVisible ? 1 : 0)
        }
        .frame(width: diameter, height: diameter)
    }

    /// Today's dot, placed even while hidden so it comes and goes where it
    /// is, in a ring cut out of its layer round the dot's own circle so the
    /// sky rings it evenly, or for the track's layer, only the hole.
    private func dot(lineWidth: CGFloat, isHole: Bool) -> some View {
        ZStack {
            if chosenDay == 0, temperature != nil {
                Circle()
                    .fill(.white)
                    .blendMode(isHole ? .destinationOut : .normal)
                    .background {
                        Circle()
                            .stroke(lineWidth: lineWidth * 0.75)
                            .blendMode(.destinationOut)
                    }
                    .frame(width: lineWidth * 1.5, height: lineWidth * 1.5)
                    .transition(.scale)
            }
        }
    }

    /// Where temperatures go along the arc, as fractions of the way around a
    /// circle's path, which starts at its right, a quarter turn past the
    /// ring's top, and goes clockwise.
    private struct Scale {
        /// The lowest temperature's end, on the slot before today's.
        static let lowEnd = (WeatherRing.angle(slot: WeatherRing.todaySlot - 1).degrees - 90) / 360
        /// The highest temperature's end, on the slot after the last day's.
        static let highEnd = (WeatherRing.angle(
            slot: (WeatherRing.todaySlot + WeatherRing.dayCount) % WeatherRing.slotCount
        ).degrees - 90) / 360

        let lowest: Double
        let highest: Double

        func fraction(_ temperature: Measurement<UnitTemperature>) -> Double {
            let celsius = temperature.converted(to: .celsius).value
            let along = min(max((celsius - lowest) / (highest - lowest), 0), 1)
            return Self.lowEnd + (Self.highEnd - Self.lowEnd) * along
        }

        /// Each temperature's color where it is along the arc, from the
        /// highest's end clockwise to the lowest's.
        var gradient: AngularGradient {
            let inside = TemperatureColors.stops.reversed().filter { lowest < $0.celsius && $0.celsius < highest }
            let stops = [Gradient.Stop(color: TemperatureColors.color(celsius: highest), location: 0)]
                + inside.map { Gradient.Stop(color: $0.color, location: (highest - $0.celsius) / (highest - lowest)) }
                + [Gradient.Stop(color: TemperatureColors.color(celsius: lowest), location: 1)]
            return AngularGradient(
                stops: stops,
                center: .center,
                startAngle: .degrees(360 * Self.highEnd),
                endAngle: .degrees(360 * Self.lowEnd)
            )
        }
    }

    /// The Weather app's colors for temperatures, which its bars blend from
    /// each day's low to its high: dark blue below 0°C, light blue to 15°,
    /// green to 20°, yellow to 25°, orange to 30° and red above. Each is at
    /// its band's middle, the open-ended bands taken as wide as the next.
    private enum TemperatureColors {
        static let stops: [(celsius: Double, color: Color)] = [
            (-7.5, .blue),
            (7.5, .cyan),
            (17.5, .green),
            (22.5, .yellow),
            (27.5, .orange),
            (32.5, .red)
        ]

        /// Blended as the gradient blends them.
        static func color(celsius: Double) -> Color {
            guard let next = stops.firstIndex(where: { $0.celsius > celsius }) else {
                return stops[stops.count - 1].color
            }
            guard next > 0 else { return stops[0].color }
            let (below, above) = (stops[next - 1], stops[next])
            return below.color.mix(
                with: above.color,
                by: (celsius - below.celsius) / (above.celsius - below.celsius),
                in: .device
            )
        }
    }
}

/// The temperature over the conditions now, in the middle of the ring, or
/// while the days show, the chosen day's low and high, left to right as on
/// the arc below, over its conditions. Under rain, how likely it is too.
private struct WeatherRingCenter: View {
    let conditions: CityWeather.Conditions?
    let day: CityWeather.Day?
    let isLoading: Bool
    let useCelsius: Bool

    var body: some View {
        ZStack {
            // One view for now and the days, so going between them resizes
            // and moves the text rather than replacing it.
            if let temperature = day?.lowTemperature ?? conditions?.temperature,
               let condition = day?.condition ?? conditions?.condition {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text(Self.temperature(temperature, useCelsius: useCelsius))
                            .foregroundStyle(day == nil ? .primary : .secondary)
                            .blendMode(.plusLighter)
                        // As the footer's date, blended outside the
                        // transition, and spaced inside the stack so the empty
                        // stack takes no room.
                        ZStack {
                            if let day {
                                Text(Self.temperature(day.highTemperature, useCelsius: useCelsius))
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

                    precipitationChance(
                        condition.isRainy ? day?.precipitationChance ?? conditions?.precipitationChance : nil
                    )
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

    /// In whole percent, as the iPhone app's hours show it, and only where
    /// there's any.
    private func precipitationChance(_ chance: Double?) -> some View {
        ZStack {
            if let chance, (chance * 100).rounded() >= 1 {
                Text(chance, format: .percent.precision(.fractionLength(0)))
                    .contentTransition(.numericText(value: chance))
                    .transition(.blurReplace)
            }
        }
        .font(.footnote.weight(.medium).monospacedDigit())
        .foregroundStyle(.cyan)
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
    let forecast: [(Double, WeatherCondition, Double)] = [
        (16, .cloudy, 0.2), (15, .mostlyCloudy, 0.1), (15, .partlyCloudy, 0), (14, .mostlyClear, 0),
        (13, .clear, 0), (12, .clear, 0), (12, .clear, 0), (12, .partlyCloudy, 0.1),
        (13, .drizzle, 0.4), (14, .rain, 0.7), (15, .rain, 0.8), (16, .cloudy, 0.3)
    ]
    let hours = Dictionary(uniqueKeysWithValues: forecast.enumerated().map { index, hour in
        let start = currentHour.addingTimeInterval(Double(index) * 3600)
        return (
            start,
            CityWeather.Conditions(
                temperature: Measurement(value: hour.0, unit: .celsius),
                condition: hour.1,
                isDaylight: (6..<18).contains(Calendar.current.component(.hour, from: start)),
                precipitationChance: hour.2
            )
        )
    })
    let dailyForecast: [(Double, Double, WeatherCondition, Double)] = [
        (9, 3, .mostlyCloudy, 0.2), (11, 5, .rain, 0.8), (10, 4, .drizzle, 0.5), (12, 6, .partlyCloudy, 0.1),
        (14, 7, .clear, 0), (13, 8, .mostlyClear, 0), (11, 6, .cloudy, 0.3), (9, 4, .rain, 0.9),
        (6, 1, .snow, 0.6), (8, 2, .partlyCloudy, 0.1)
    ]
    let today = Calendar.current.startOfDay(for: date)
    let days = dailyForecast.enumerated().map { index, day in
        CityWeather.Day(
            date: Calendar.current.date(byAdding: .day, value: index, to: today)!,
            highTemperature: Measurement(value: day.0, unit: .celsius),
            lowTemperature: Measurement(value: day.1, unit: .celsius),
            condition: day.2,
            precipitationChance: day.3,
            uvIndex: 4
        )
    }
    let weather = CityWeather(
        current: hours[currentHour]!,
        wind: CityWeather.Wind(
            direction: 200,
            speed: Measurement(value: 18, unit: .kilometersPerHour),
            gust: Measurement(value: 29, unit: .kilometersPerHour)
        ),
        uvIndex: 2,
        pressure: Measurement(value: 1013, unit: .hectopascals),
        pressureTrend: .steady,
        humidity: CityWeather.Humidity(relative: 0.8, dewPoint: Measurement(value: 13, unit: .celsius)),
        hours: hours,
        hourlyUVIndexes: [:],
        hourlyPressures: [:],
        hourlyHumidities: [:],
        days: days,
        fetchDate: date
    )

    NavigationStack {
        CityWeatherView(date: date, timeZone: .current, useCelsius: true, dateStyle: "Relative")
            .ignoresSafeArea(edges: .bottom)
            .containerBackground(for: .navigation) {
                CitySkyBackground(date: date, timeZone: .current)
            }
    }
    .environment(WatchWeatherStore(weather: [TimeZone.current.identifier: weather]))
}
