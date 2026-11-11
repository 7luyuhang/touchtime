//
//  CityPressureView.swift
//  touchtimeWatch
//

import SwiftUI
import WeatherKit

/// The city's sea-level pressure on a gauge laid out as UV Index's: an arc as
/// wide as the daylight ring, lighter where the sky is, from deep lows at the
/// bottom left, clockwise over standard pressure at the top, to strong highs
/// at the bottom right, with a ring on it at the pressure, lit beside it for
/// which way the pressure's going, and around it the forecast's days, the
/// chosen one on a pill. In the middle, the pressure over its unit, and below
/// the arc, over the date, the chosen day's pressure hour by hour under which
/// way it's going.
/// Today's is the pressure now, and the Digital Crown moves the pill to each
/// day after it, as far as the forecast goes, for the day's average and which
/// way it goes over the day.
struct CityPressureView: View {
    /// The least the chart spans, in hectopascals, so a calm spell's little
    /// ups and downs stay little.
    private static let leastChartSpan = 10.0

    let date: Date
    let timeZone: TimeZone
    /// The iPhone app's pressure unit.
    let pressureUnit: PressureUnit
    /// The iPhone app's date style, for `Date.formattedDate(style:)`.
    let dateStyle: String

    @Environment(WatchWeatherStore.self) private var weatherStore
    @Environment(\.isPresented) private var isPresented
    /// How many days after today the Digital Crown has turned to.
    @State private var crownDays: Double = 0
    @FocusState private var isCrownFocused: Bool

    var body: some View {
        let weather = weatherStore.weather[timeZone.identifier]
        let isLoading = weather == nil && !weatherStore.unavailableTimeZones.contains(timeZone.identifier)
        let days = days(in: weather)
        let chosenDayIndex = min(max(Int(crownDays.rounded()), 0), max(days.count - 1, 0))
        let chosenDay = days.indices.contains(chosenDayIndex) ? days[chosenDayIndex] : nil
        let reading = chosenDayIndex == 0
            ? weather.map { PressureReading(pressure: $0.pressure, trend: $0.pressureTrend) }
            : chosenDay.flatMap { day in weather.flatMap { reading(for: day, in: $0) } }
        let chartSamples = chosenDay.flatMap { day in
            weather.flatMap { weather in
                DayLineChart.Samples(hourly: weather.hourlyHectopascals, day: day.date, calendar: calendar)
                    .map { Self.fitted($0) }
            }
        }

        VStack(spacing: 8) {
            GeometryReader { geometry in
                // Laid out as UV Index's gauge, so going from one to the
                // other, the gauge stays where it is.
                let diameter = max(0, min(geometry.size.width - 16, geometry.size.height))
                let ringWidth = diameter * 0.20
                let holeDiameter = diameter - PressureGauge.bandWidth * 2 - ringWidth * 2
                let chartLineWidth = DayLineChart.lineWidth(ringWidth: ringWidth)
                // From the arc's ends down to the symbol's bottom, a line's
                // width over the chart in the bottom of the circle.
                let trendRoom = diameter * (0.5 - DayLineChart.heightShare) - chartLineWidth
                    - PressureGauge.endsDepth(diameter: diameter, ringWidth: ringWidth)

                ZStack {
                    PressureGauge(
                        diameter: diameter,
                        ringWidth: ringWidth,
                        reading: reading,
                        dayNumbers: days.map { calendar.component(.day, from: $0.date) },
                        chosenDayIndex: chosenDayIndex
                    )
                    .accessibilityHidden(true)

                    PressureCenter(reading: reading, unit: pressureUnit, isLoading: isLoading)
                        .frame(width: holeDiameter * 0.80)
                        .frame(width: holeDiameter, height: holeDiameter)

                    // Which way the pressure is going over the chart, under the
                    // arc's ends, as UV Index's label and chart are: in the
                    // bottom of the gauge's circle rather than in a row of
                    // their own, which would shrink the gauge and its arc.
                    VStack(spacing: chartLineWidth) {
                        PressureTrendSymbol(trend: reading?.trend)
                            .frame(maxHeight: max(trendRoom, 0), alignment: .bottom)
                        ZStack {
                            if let chartSamples {
                                DayLineChart(
                                    samples: chartSamples,
                                    scale: 0...1,
                                    colors: [.purple],
                                    nowFraction: nowFraction,
                                    isToday: chosenDayIndex == 0,
                                    lineWidth: chartLineWidth
                                )
                                .transition(.blurReplace)
                            }
                        }
                        .frame(height: diameter * DayLineChart.heightShare)
                        .accessibilityHidden(true)
                    }
                    .frame(width: diameter - PressureGauge.bandWidth * 2, height: diameter, alignment: .bottom)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }

            // Today's until the days come in.
            Text(dayLabel(chosenDay?.date ?? date))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .blendMode(.plusLighter)
                .contentTransition(.numericText())
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
                .scenePadding(.navigationBar, edges: .horizontal)
        }
        // The circle's narrow top fits between the toolbar controls, as the
        // daylight ring's does.
        .padding(.top, -20)
        .padding(.bottom, 8)
        .animation(.smooth, value: weather?.fetchDate)
        .animation(.smooth, value: chosenDayIndex)
        // As on the details, not while sliding back to the list, so a quick
        // turn scrolls the list rather than the days.
        .background {
            Color.clear
                .focusable(isPresented)
                .focused($isCrownFocused)
                .digitalCrownRotation(
                    $crownDays,
                    from: 0,
                    // Never an empty range, even with a day or none.
                    through: Double(max(days.count - 1, 1)),
                    by: 1,
                    // As Weather's days, each takes a turn of its own rather
                    // than a flick passing several.
                    sensitivity: .low,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
        }
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

    /// The city's, which the forecast's days are midnights in.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// The forecast's days from today in the city, every one it has.
    private func days(in weather: CityWeather?) -> [CityWeather.Day] {
        guard let weather else { return [] }
        let today = calendar.startOfDay(for: date)
        return weather.days.filter { $0.date >= today }
    }

    /// How far through the city's day now is.
    private var nowFraction: Double {
        let today = calendar.startOfDay(for: date)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), tomorrow > today else { return 0 }
        return min(max(date.timeIntervalSince(today) / tomorrow.timeIntervalSince(today), 0), 1)
    }

    /// In the iPhone app's date style, weekday and all, as under the details'
    /// other views.
    private func dayLabel(_ day: Date) -> String {
        day.formattedDate(style: dateStyle, timeZone: timeZone, relativeTo: date)
    }

    /// A day's pressures as shares of the chart's height, from the day's
    /// lowest to its highest widened to the least span about their middle,
    /// as the chart's too short for a day's rise and fall to show on the
    /// whole forecast's range. On all but the stormiest days, the same
    /// hectopascals take the same height, so from one day to the next the
    /// line reshapes rather than jumping.
    private static func fitted(_ samples: DayLineChart.Samples) -> DayLineChart.Samples {
        let lowest = samples.values.min() ?? 0
        let highest = samples.values.max() ?? 0
        let span = max(highest - lowest, leastChartSpan)
        let bottom = (lowest + highest - span) / 2
        return DayLineChart.Samples(values: samples.values.map { ($0 - bottom) / span })
    }

    /// `day`'s pressure averaged over its hours, and which way it goes from
    /// the day's first hour to the next day's, or to its own last on the
    /// forecast's last day, or nil unless the hours cover the day.
    private func reading(for day: CityWeather.Day, in weather: CityWeather) -> PressureReading? {
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: day.date) else { return nil }
        let dayHours = dayEnd.timeIntervalSince(day.date) / 3600
        // The next day's first hour too: a day apart, the rise and fall the
        // pressure goes through twice a day of its own accord, most of all
        // in the tropics, cancels out.
        let points = weather.hourlyHectopascals
            .map { (x: $0.key.timeIntervalSince(day.date) / 3600, hectopascals: $0.value) }
            .filter { $0.x >= 0 && $0.x < dayHours + 1 }
            .sorted { $0.x < $1.x }
        let dayPoints = points.filter { $0.x < dayHours }
        // Within an hour, as hours start off a half-hour city's midnight.
        guard let first = dayPoints.first, let last = dayPoints.last, let end = points.last,
              first.x < 1, last.x >= dayHours - 1 else {
            return nil
        }
        let average = dayPoints.reduce(0) { $0 + $1.hectopascals } / Double(dayPoints.count)
        return PressureReading(
            pressure: Measurement(value: average, unit: .hectopascals),
            trend: PressureTrend(dayChange: end.hectopascals - first.hectopascals)
        )
    }
}

/// A pressure, and which way it's going.
private struct PressureReading {
    let pressure: Measurement<UnitPressure>
    let trend: PressureTrend
}

/// Where things go around the gauge, as on UV Index's: from the bottom left,
/// where 8 is on a clock's face, clockwise over the top, to the bottom right,
/// where 4 is. Pressures run from deep lows at the start, through standard
/// pressure at the top, to strong highs at the end, as on the iPhone app's
/// pressure complication, and the forecast's days from today at the start to
/// its last at the end.
private enum PressureScale {
    /// At the top, in hectopascals.
    static let standardPressure = 1013.25
    /// From standard pressure to either end, in hectopascals, where any
    /// further sits too.
    static let range = 40.0
    /// The days WeatherKit forecasts. The gauge has room for as many even
    /// once the first has gone by, so the others keep their places.
    static let forecastDays = 10
    /// From the top, clockwise.
    static let startAngle = Angle.degrees(240)
    static let sweep = Angle.degrees(240)
    /// Where the lines around the gauge have faded away below its start, and
    /// as far below its end.
    static let fadeEndAngle = Angle.degrees(225)

    static func angle(pressure: Measurement<UnitPressure>) -> Angle {
        let offset = (pressure.converted(to: .hectopascals).value - standardPressure) / range
        return angle(along: (min(max(offset, -1), 1) + 1) / 2)
    }

    /// The `day`th of `count` days from the start.
    static func angle(day: Int, of count: Int) -> Angle {
        angle(along: count > 1 ? Double(day) / Double(count - 1) : 0)
    }

    private static func angle(along fraction: Double) -> Angle {
        .degrees(startAngle.degrees + sweep.degrees * fraction)
    }
}

/// UV Index's gauge with its arc uncolored: the forecast's days around the
/// outside of the arc, the one the Digital Crown has turned to cut out of a
/// pill like the daylight ring's current hour's, inside a border like the
/// daylight ring's edge; the arc, lighter where the sky is, as the border is;
/// and on it, at the pressure, a ring like UV Index's sun, with light along
/// the arc beside it. Below the arc's ends its edge and the border fade away.
private struct PressureGauge: View {
    /// How far past the arc the days and their border reach, as the daylight
    /// ring's hours do.
    static let bandWidth: CGFloat = 16
    /// The arc's edge and the border around the days, as the daylight ring's.
    private static let lineWidth: CGFloat = 1.5
    /// Theirs, and the arc's too.
    private static let lineOpacity = 0.10
    /// The chosen day's pill, end to end along the gauge, as long as the
    /// daylight ring's current hour's.
    private static let pillLength: CGFloat = 24
    /// As wide as the daylight ring's sun's outline by night.
    private static let markerLineWidth: CGFloat = 2

    /// The border's, where the daylight ring's edge is.
    let diameter: CGFloat
    /// The arc's, as wide as the daylight ring.
    let ringWidth: CGFloat
    /// Nil until the weather comes in, and on a day the forecast's hours
    /// don't cover.
    let reading: PressureReading?
    /// Each of the forecast's days from today, by its day of the month.
    let dayNumbers: [Int]
    /// The day the Digital Crown has turned to.
    let chosenDayIndex: Int

    var body: some View {
        let arcDiameter = diameter - Self.bandWidth * 2
        // Halfway between the arc's edge and the border.
        let labelRadius = (arcDiameter + Self.bandWidth - Self.lineWidth) / 2
        // Through the middle of the arc.
        let arcRadius = (arcDiameter - ringWidth) / 2
        let pressure = reading?.pressure
        let markerAngle = pressure.map { PressureScale.angle(pressure: $0) } ?? .zero
        // As big as the daylight ring's sun.
        let markerDiameter = ringWidth * 0.60
        let dayCount = max(dayNumbers.count, PressureScale.forecastDays)
        let pillAngle = PressureScale.angle(day: chosenDayIndex, of: dayCount)

        ZStack {
            // The days it covers cut out of the pill, so the sky shows through
            // them as it moves from day to day.
            ZStack {
                // Clear of the pill, so as not to fill its cutouts back in.
                ZStack {
                    days(radius: labelRadius, count: dayCount)
                    pill(radius: labelRadius, angle: pillAngle)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()

                if !dayNumbers.isEmpty {
                    ZStack {
                        pill(radius: labelRadius, angle: pillAngle)
                        days(radius: labelRadius, count: dayCount)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                }
            }
            .foregroundStyle(.white)

            arc
                .stroke(.white.opacity(Self.lineOpacity), style: arcStyle)
                .frame(width: arcDiameter, height: arcDiameter)
                .blendMode(.plusLighter)

            // Turned to the pressure as the ring is, and kept to the arc, so
            // near either end the light stops where the arc does.
            ZStack {
                if let trend = reading?.trend {
                    PressureGlow(
                        trend: trend,
                        arcRadius: arcRadius,
                        ringWidth: ringWidth,
                        markerDiameter: markerDiameter
                    )
                    .transition(.opacity)
                }
            }
            .frame(width: arcDiameter, height: arcDiameter)
            .animation(.smooth, value: pressure != nil)
            .rotationEffect(markerAngle)
            .animation(nil, value: pressure != nil)
            .mask {
                arc
                    .stroke(style: arcStyle)
                    .frame(width: arcDiameter, height: arcDiameter)
            }
            .blendMode(.plusLighter)

            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: Self.lineWidth)
                Circle()
                    .inset(by: Self.bandWidth)
                    .strokeBorder(.white, lineWidth: Self.lineWidth)
            }
            .opacity(Self.lineOpacity)
            // From the height of the arc's edge at its ends down, leaving the
            // bottom to the chart.
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: height(at: PressureScale.startAngle, radius: arcDiameter / 2)),
                        .init(color: .clear, location: height(at: PressureScale.fadeEndAngle, radius: arcDiameter / 2))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .blendMode(.plusLighter)

            // Transitioning inside the placement scales the ring about itself
            // rather than the gauge's center.
            ZStack {
                if pressure != nil {
                    Circle()
                        .strokeBorder(.white, lineWidth: Self.markerLineWidth)
                        .transition(.blurReplace)
                }
            }
            .frame(width: markerDiameter, height: markerDiameter)
            // Coming in where it is…
            .animation(.smooth, value: pressure != nil)
            // Turned around the gauge's middle, from pressure to pressure
            // along the arc rather than across the gauge.
            .offset(y: -arcRadius)
            .rotationEffect(markerAngle)
            // …rather than travelling there from the gauge's top.
            .animation(nil, value: pressure != nil)
        }
        .frame(width: diameter, height: diameter)
    }

    /// From its start to its end, through the middle of its width, in a frame
    /// as wide as it is.
    private var arc: some Shape {
        Circle()
            .inset(by: ringWidth / 2)
            // A circle's path starts at its right, a quarter turn past the
            // top.
            .rotation(PressureScale.startAngle - .degrees(90))
            .trim(from: 0, to: PressureScale.sweep.degrees / 360)
    }

    private var arcStyle: StrokeStyle {
        StrokeStyle(lineWidth: ringWidth, lineCap: .round)
    }

    /// Each day at its place around a circle of `radius`, spaced for `count`.
    private func days(radius: CGFloat, count: Int) -> some View {
        ZStack {
            ForEach(dayNumbers.indices, id: \.self) { index in
                Text(dayNumbers[index], format: .number)
                    .placed(at: PressureScale.angle(day: index, of: count), radius: radius)
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        // The whole gauge's, for the pill to mask.
        .frame(width: diameter, height: diameter)
    }

    /// The daylight ring's pill, bent along a circle of `radius` at `angle`.
    /// It turns around the gauge's middle, so from day to day it follows the
    /// circle rather than cutting across it.
    private func pill(radius: CGFloat, angle: Angle) -> some View {
        HourPill(
            radius: radius,
            length: Self.pillLength,
            // From the arc's edge to the border, overlapping each a little so
            // no seam shows between them.
            thickness: Self.bandWidth - Self.lineWidth + 1,
            isTurnedOver: false
        )
        // Up from the gauge's middle by the radius, so the circle it bends
        // around is centered on the gauge's.
        .offset(y: -radius)
        .rotationEffect(angle)
    }

    /// How far below the gauge's middle the arc's round ends reach.
    static func endsDepth(diameter: CGFloat, ringWidth: CGFloat) -> CGFloat {
        let arcRadius = (diameter - bandWidth * 2 - ringWidth) / 2
        return -arcRadius * cos(PressureScale.startAngle.radians) + ringWidth / 2
    }

    /// How far down the gauge a circle of `radius` around its middle is at
    /// `angle`, from the top, clockwise, as a share of the gauge's height.
    private func height(at angle: Angle, radius: CGFloat) -> CGFloat {
        guard diameter > 0 else { return 0 }
        return 0.5 - radius * cos(angle.radians) / diameter
    }
}

/// Light along the arc either side of the pressure's ring, as Weather lights
/// the ticks either side of its pressure's, at the top of a frame as wide as
/// the arc for the gauge to turn to the pressure. It shows which way the
/// pressure's going too: while it rises or falls, the light trails behind the
/// ring, back the way the pressure came, as a comet's tail does, and ends at
/// the ring's middle ahead, rounded around the ring as the arc's ends are;
/// while it holds steady, it fades away as far both ways.
private struct PressureGlow: View {
    /// At the ring's middle, where it's brightest, on top of the arc's own.
    private static let opacity = 0.10

    let trend: PressureTrend
    /// From the gauge's middle to the ring's.
    let arcRadius: CGFloat
    /// The arc's.
    let ringWidth: CGFloat
    let markerDiameter: CGFloat

    var body: some View {
        let glow = trend.glow

        ZStack {
            RingGlow(
                bandWidth: ringWidth,
                opacity: Self.opacity,
                reach: glow.reach,
                counterclockwiseLength: glow.lower,
                clockwiseLength: glow.higher
            )

            // The arc's own color inside the ring, so the ring stands out
            // from the light around it.
            Circle()
                .frame(width: markerDiameter, height: markerDiameter)
                .offset(y: -arcRadius)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

/// The pressure over its unit, in the middle of the gauge.
private struct PressureCenter: View {
    /// The daylight ring's time's font, a pressure being about as wide as a
    /// time.
    private static let pressureFont = Font.system(.title3, design: .rounded, weight: .medium).monospacedDigit()

    /// Nil until the weather comes in, and on a day the forecast's hours
    /// don't cover.
    let reading: PressureReading?
    let unit: PressureUnit
    let isLoading: Bool

    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            if let pressure = reading?.pressure {
                VStack(spacing: 0) {
                    Text(unit.number(pressure))
                        .font(Self.pressureFont)
                        .contentTransition(.numericText(value: pressure.converted(to: .hectopascals).value))
                    Text(unit.localizedSymbol)
                        .font(.footnote.weight(.medium))
                }
                .transition(.blurReplace)
            } else if isLoading {
                ProgressView()
                    .transition(.blurReplace)
            } else {
                Text(verbatim: "--")
                    .font(Self.pressureFont)
                    .transition(.blurReplace)
            }
        }
        .foregroundStyle(.primary)
        .lineLimit(1)
        // At the largest text sizes on the smallest watch.
        .minimumScaleFactor(0.4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pressure")
        .accessibilityValue(accessibilityValue)
    }

    /// With which way it's going: the symbol under the arc is hidden from
    /// VoiceOver.
    private var accessibilityValue: String {
        guard let reading else { return "" }
        let pressure = reading.pressure.converted(to: unit.unit).formatted(
            Measurement<UnitPressure>.FormatStyle(
                width: .wide,
                locale: locale,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(unit.fractionDigits))
            )
        )
        return "\(pressure), \(reading.trend.displayName)"
    }
}

/// Which way the pressure is going, just above the chart.
private struct PressureTrendSymbol: View {
    /// Nil until the weather comes in, and on a day the forecast's hours
    /// don't cover.
    let trend: PressureTrend?

    var body: some View {
        ZStack {
            // As tall as the arrows whichever shows, so the flatter equals
            // sign sits as far down as they do.
            Image(systemName: "arrow.up")
                .hidden()
            if let trend {
                Image(systemName: trend.symbolName)
                    .contentTransition(.symbolEffect(.replace))
                    .transition(.blurReplace)
            }
        }
        .font(.headline)
        .foregroundStyle(.primary)
        .blendMode(.plusLighter)
        .accessibilityHidden(true)
    }
}

private extension PressureTrend {
    /// How far a day's pressure goes either way, in hectopascals, and still
    /// holds steady.
    static let steadyDayChange = 1.0

    /// Which way a day's pressure goes, changing by `change` hectopascals
    /// over the day.
    init(dayChange change: Double) {
        if change > Self.steadyDayChange {
            self = .rising
        } else if change < -Self.steadyDayChange {
            self = .falling
        } else {
            self = .steady
        }
    }

    /// The light either side of the pressure's ring, in degrees around the
    /// gauge: how far from the ring's middle it would reach either way
    /// before it's faded away, and how far it goes toward lower pressures and
    /// toward higher ones before it ends. While the pressure rises or falls,
    /// a long way back the way it came, and ahead, only to the ring's middle;
    /// while it holds, as far both ways as it reaches.
    var glow: (reach: Double, lower: Double, higher: Double) {
        switch self {
        case .rising: (100, 100, 0)
        case .falling: (100, 0, 100)
        case .steady: (48, 48, 48)
        @unknown default: (48, 48, 48)
        }
    }

    /// As the iPhone app's pressure complication shows it.
    var symbolName: String {
        switch self {
        case .rising: "arrow.up"
        case .falling: "arrow.down"
        case .steady: "equal"
        @unknown default: "equal"
        }
    }

    /// As the iPhone app names it.
    var displayName: String {
        switch self {
        case .rising: String(localized: "Rising")
        case .falling: String(localized: "Falling")
        case .steady: String(localized: "Steady")
        @unknown default: description
        }
    }
}

private extension CityWeather {
    /// Each hour's pressure at sea level in hectopascals, by the start of the
    /// hour.
    var hourlyHectopascals: [Date: Double] {
        hourlyPressures.mapValues { $0.converted(to: .hectopascals).value }
    }
}

private extension PressureUnit {
    /// A pressure in this unit to its usual decimal places, without the unit.
    func number(_ pressure: Measurement<UnitPressure>) -> String {
        pressure.converted(to: unit).value.formatted(.number.precision(.fractionLength(fractionDigits)))
    }
}

private extension View {
    /// At `angle` around a circle of `radius`, its bottom toward the circle's
    /// middle, as UV Index's days are, so they read in order along the gauge,
    /// clockwise.
    func placed(at angle: Angle, radius: CGFloat) -> some View {
        rotationEffect(angle)
            .offset(x: radius * sin(angle.radians), y: -radius * cos(angle.radians))
    }
}

#Preview {
    let date = Date.now
    let today = Calendar.current.startOfDay(for: date)
    let days = (0..<10).map { index in
        CityWeather.Day(
            date: Calendar.current.date(byAdding: .day, value: index, to: today)!,
            highTemperature: Measurement(value: 14, unit: .celsius),
            lowTemperature: Measurement(value: 8, unit: .celsius),
            condition: .cloudy,
            precipitationChance: 0.2,
            uvIndex: 2
        )
    }
    let hourlyPressures = Dictionary(uniqueKeysWithValues: (0..<(days.count * 24)).map { index in
        // A low passing over on the third day, then a high building.
        let day = Double(index) / 24
        let hectopascals = 1012 - 16 * exp(-pow(day - 2.5, 2)) + 12 * exp(-pow((day - 7) / 2, 2))
        return (today.addingTimeInterval(Double(index) * 3600), Measurement(value: hectopascals, unit: UnitPressure.hectopascals))
    })
    let weather = CityWeather(
        current: CityWeather.Conditions(
            temperature: Measurement(value: 12, unit: .celsius),
            condition: .cloudy,
            isDaylight: true,
            precipitationChance: 0.2
        ),
        wind: CityWeather.Wind(
            direction: 200,
            speed: Measurement(value: 18, unit: .kilometersPerHour),
            gust: Measurement(value: 29, unit: .kilometersPerHour)
        ),
        uvIndex: 2,
        pressure: Measurement(value: 1005, unit: .hectopascals),
        pressureTrend: .falling,
        hours: [:],
        hourlyUVIndexes: [:],
        hourlyPressures: hourlyPressures,
        days: days,
        fetchDate: date
    )

    NavigationStack {
        CityPressureView(date: date, timeZone: .current, pressureUnit: .millibars, dateStyle: "Relative")
            .ignoresSafeArea(edges: .bottom)
            .containerBackground(for: .navigation) {
                CitySkyBackground(date: date, timeZone: .current)
            }
    }
    .environment(WatchWeatherStore(weather: [TimeZone.current.identifier: weather]))
}
