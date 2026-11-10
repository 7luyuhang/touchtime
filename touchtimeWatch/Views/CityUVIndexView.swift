//
//  CityUVIndexView.swift
//  touchtimeWatch
//

import SwiftUI
import WeatherKit

/// The city's UV index on a gauge in the daylight ring's place: an arc as
/// wide as the daylight ring in the iPhone app's UV index colors, from 0 at
/// the bottom left, clockwise over the top, to 11 at the bottom right, with a
/// sun on it at the index, and around it the forecast's days, the chosen one
/// on a pill. In the middle, the index, and below the arc, over the date, the
/// chosen day's index hour by hour under how high the index is.
/// Today's index is the one now, and the Digital Crown moves the pill to each
/// day after it, as far as the forecast goes, for the highest it gets that
/// day.
struct CityUVIndexView: View {
    let date: Date
    let timeZone: TimeZone
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
        let uvIndex = chosenDayIndex == 0 ? weather?.uvIndex : chosenDay?.uvIndex
        let chartSamples = chosenDay.flatMap { day in weather.flatMap { chartSamples(for: day, in: $0) } }

        VStack(spacing: 8) {
            GeometryReader { geometry in
                // Laid out as the daylight ring is, so the gauge's border is
                // where the ring's edge is, and the arc as wide as the ring.
                let diameter = max(0, min(geometry.size.width - 16, geometry.size.height))
                let ringWidth = diameter * 0.20
                let holeDiameter = diameter - UVIndexGauge.bandWidth * 2 - ringWidth * 2
                let chartLineWidth = UVIndexChart.lineWidth(ringWidth: ringWidth)
                // From the arc's ends down to the label's bottom, a line's
                // width over the chart in the bottom of the circle.
                let labelRoom = diameter * (0.5 - UVIndexChart.heightShare) - chartLineWidth
                    - UVIndexGauge.endsDepth(diameter: diameter, ringWidth: ringWidth)

                ZStack {
                    UVIndexGauge(
                        diameter: diameter,
                        ringWidth: ringWidth,
                        uvIndex: uvIndex,
                        dayNumbers: days.map { calendar.component(.day, from: $0.date) },
                        chosenDayIndex: chosenDayIndex
                    )
                    .accessibilityHidden(true)

                    UVIndexCenter(uvIndex: uvIndex, isLoading: isLoading)
                        .frame(width: holeDiameter * 0.80)
                        .frame(width: holeDiameter, height: holeDiameter)

                    // How high the index is over the chart, under the arc's
                    // ends: in the bottom of the gauge's circle rather than in
                    // a row of their own, which would shrink the gauge and its
                    // arc.
                    VStack(spacing: chartLineWidth) {
                        UVIndexCategoryLabel(uvIndex: uvIndex)
                            // Smaller at the largest text sizes rather than
                            // running into the arc's ends.
                            .frame(maxHeight: max(labelRoom, 0), alignment: .bottom)
                        ZStack {
                            if let chartSamples {
                                UVIndexChart(
                                    samples: UVIndexSamples(values: chartSamples),
                                    nowFraction: nowFraction,
                                    isToday: chosenDayIndex == 0,
                                    lineWidth: chartLineWidth
                                )
                                .transition(.blurReplace)
                            }
                        }
                        .frame(height: diameter * UVIndexChart.heightShare)
                        .accessibilityHidden(true)
                    }
                    .frame(width: diameter - UVIndexGauge.bandWidth * 2, height: diameter, alignment: .bottom)
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

    /// `day`'s index hour by hour as a smooth line, sampled evenly from its
    /// midnight to the next, or nil unless the hours cover the day.
    private func chartSamples(for day: CityWeather.Day, in weather: CityWeather) -> [Double]? {
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: day.date) else { return nil }
        let dayHours = dayEnd.timeIntervalSince(day.date) / 3600
        // Hours past each end too, for the line to carry on as it would.
        let margin = UVIndexLine.reach + 1
        let points = weather.hourlyUVIndexes
            .map { (x: $0.key.timeIntervalSince(day.date) / 3600, y: Double($0.value)) }
            .filter { $0.x > -margin && $0.x < dayHours + margin }
            .sorted { $0.x < $1.x }
        // Within an hour, as hours start off a half-hour city's midnight.
        guard let first = points.first, let last = points.last, first.x <= 1, last.x >= dayHours - 1 else {
            return nil
        }
        return UVIndexLine(points: points).values(
            from: 0,
            every: dayHours / Double(UVIndexChart.sampleCount),
            count: UVIndexChart.sampleCount + 1
        )
    }
}

/// Where things go around the gauge: from the bottom left, where 8 is on a
/// clock's face, clockwise over the top, to the bottom right, where 4 is. The
/// indexes run from 0 at the start to 11 at the end, and the forecast's days
/// from today at the start to its last at the end.
private enum UVIndexScale {
    /// The gauge's last index, where any higher sits too.
    static let highestIndex = 11
    /// The days WeatherKit forecasts. The gauge has room for as many even
    /// once the first has gone by, so the others keep their places.
    static let forecastDays = 10
    /// From the top, clockwise.
    static let startAngle = Angle.degrees(240)
    static let sweep = Angle.degrees(240)
    /// Where the lines around the gauge have faded away below its start, and
    /// as far below its end.
    static let fadeEndAngle = Angle.degrees(225)
    /// The iPhone app's UV index colors, from the gauge's start to its end.
    static let colors: [Color] = [.green, .yellow, .orange, .red, .purple]

    static func angle(index: Int) -> Angle {
        angle(along: Double(min(max(index, 0), highestIndex)) / Double(highestIndex))
    }

    /// The `day`th of `count` days from the start.
    static func angle(day: Int, of count: Int) -> Angle {
        angle(along: count > 1 ? Double(day) / Double(count - 1) : 0)
    }

    /// Across the gauge's bottom half, a day turns over to read left to right
    /// rather than upside down, as on the daylight ring.
    static func isTurnedOver(_ angle: Angle) -> Bool {
        let degrees = angle.degrees.truncatingRemainder(dividingBy: 360)
        return degrees > 90 && degrees < 270
    }

    private static func angle(along fraction: Double) -> Angle {
        .degrees(startAngle.degrees + sweep.degrees * fraction)
    }
}

/// The forecast's days around the outside of the arc, the one the Digital
/// Crown has turned to cut out of a pill like the daylight ring's current
/// hour's, inside a border like the daylight ring's edge; the arc in the UV
/// index's colors from the gauge's start to its end; and on it, at the index,
/// a sun outlined like the daylight ring's by night. Below the arc's ends its
/// edge and the border fade away.
private struct UVIndexGauge: View {
    /// How far past the arc the days and their border reach, as the daylight
    /// ring's hours do.
    static let bandWidth: CGFloat = 16
    /// The arc's edge and the border around the days, as the daylight ring's.
    private static let lineWidth: CGFloat = 1.5
    private static let lineOpacity = 0.10
    /// The chosen day's pill, end to end along the gauge, as long as the
    /// daylight ring's current hour's.
    private static let pillLength: CGFloat = 24
    /// As wide as the daylight ring's sun's outline by night.
    private static let sunLineWidth: CGFloat = 2

    /// The border's, where the daylight ring's edge is.
    let diameter: CGFloat
    /// The arc's, as wide as the daylight ring.
    let ringWidth: CGFloat
    /// Nil until the weather comes in.
    let uvIndex: Int?
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
        let sunAngle = UVIndexScale.angle(index: uvIndex ?? 0)
        let dayCount = max(dayNumbers.count, UVIndexScale.forecastDays)
        let pillAngle = UVIndexScale.angle(day: chosenDayIndex, of: dayCount)

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

            Circle()
                .inset(by: ringWidth / 2)
                // A circle's path starts at its right, a quarter turn past
                // the top.
                .rotation(UVIndexScale.startAngle - .degrees(90))
                .trim(from: 0, to: UVIndexScale.sweep.degrees / 360)
                .stroke(
                    AngularGradient(
                        colors: UVIndexScale.colors,
                        center: .center,
                        startAngle: UVIndexScale.startAngle - .degrees(90),
                        endAngle: UVIndexScale.startAngle + UVIndexScale.sweep - .degrees(90)
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .frame(width: arcDiameter, height: arcDiameter)

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
                        .init(color: .white, location: height(at: UVIndexScale.startAngle, radius: arcDiameter / 2)),
                        .init(color: .clear, location: height(at: UVIndexScale.fadeEndAngle, radius: arcDiameter / 2))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .blendMode(.plusLighter)

            // Transitioning inside the placement scales the sun about itself
            // rather than the gauge's center.
            ZStack {
                if uvIndex != nil {
                    Circle()
                        .strokeBorder(.white, lineWidth: Self.sunLineWidth)
                        .transition(.blurReplace)
                }
            }
            // As big as the daylight ring's sun.
            .frame(width: ringWidth * 0.60, height: ringWidth * 0.60)
            // Coming in where it is…
            .animation(.smooth, value: uvIndex != nil)
            // Turned around the gauge's middle, from index to index along the
            // arc rather than across the gauge.
            .offset(y: -arcRadius)
            .rotationEffect(sunAngle)
            // …rather than travelling there from the gauge's start.
            .animation(nil, value: uvIndex != nil)
        }
        .frame(width: diameter, height: diameter)
    }

    /// Each day at its place around a circle of `radius`, spaced for `count`.
    private func days(radius: CGFloat, count: Int) -> some View {
        ZStack {
            ForEach(dayNumbers.indices, id: \.self) { index in
                Text(dayNumbers[index], format: .number)
                    .placed(at: UVIndexScale.angle(day: index, of: count), radius: radius)
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
        return -arcRadius * cos(UVIndexScale.startAngle.radians) + ringWidth / 2
    }

    /// How far down the gauge a circle of `radius` around its middle is at
    /// `angle`, from the top, clockwise, as a share of the gauge's height.
    private func height(at angle: Angle, radius: CGFloat) -> CGFloat {
        guard diameter > 0 else { return 0 }
        return 0.5 - radius * cos(angle.radians) / diameter
    }
}

/// The index, in the middle of the gauge.
private struct UVIndexCenter: View {
    /// The daylight ring's time's font a size larger, as the weather ring's
    /// temperature now.
    private static let indexFont = Font.system(.title2, design: .rounded, weight: .medium).monospacedDigit()

    let uvIndex: Int?
    let isLoading: Bool

    var body: some View {
        ZStack {
            if let uvIndex {
                Text(uvIndex, format: .number)
                    .font(Self.indexFont)
                    .contentTransition(.numericText(value: Double(uvIndex)))
                    .transition(.blurReplace)
            } else if isLoading {
                ProgressView()
                    .transition(.blurReplace)
            } else {
                Text(verbatim: "--")
                    .font(Self.indexFont)
                    .transition(.blurReplace)
            }
        }
        .foregroundStyle(.primary)
        .lineLimit(1)
        // At the largest text sizes on the smallest watch.
        .minimumScaleFactor(0.4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("UV Index")
        .accessibilityValue(accessibilityValue(for: uvIndex))
    }

    /// With how high it is: the label above the chart is hidden from
    /// VoiceOver.
    private func accessibilityValue(for uvIndex: Int?) -> String {
        guard let uvIndex else { return "" }
        return "\(uvIndex), \(UVIndex.ExposureCategory(index: uvIndex).displayName)"
    }
}

/// How high the index is, just above the chart.
private struct UVIndexCategoryLabel: View {
    /// Nil until the weather comes in.
    let uvIndex: Int?

    var body: some View {
        ZStack {
            if let uvIndex {
                Text(UVIndex.ExposureCategory(index: uvIndex).displayName)
                    .contentTransition(.numericText(value: Double(uvIndex)))
                    .transition(.blurReplace)
            }
        }
        // As the date's under the chart.
        .font(.subheadline)
        .foregroundStyle(.primary)
        .blendMode(.plusLighter)
        .lineLimit(1)
        // At the largest text sizes on the smallest watch.
        .minimumScaleFactor(0.4)
        .accessibilityHidden(true)
    }
}

/// The chosen day's index through the day, from midnight at the left to
/// midnight at the right, on the gauge's scale from 0 at the bottom to 11 at
/// the top: a line in the gauge's colors for how high it is at each point,
/// and on today's, a dot at now, both as on the weather ring's temperatures,
/// with the line before it uncolored, as the ring's track is.
/// From day to day, the line reshapes into the next day's rather than
/// replacing it.
private struct UVIndexChart: View, Animatable {
    /// Across the day, a quarter hour apart, as many for every day so one
    /// day's line can turn into another's.
    static let sampleCount = 96
    /// Of the gauge's diameter: room for the index to rise and fall, staying
    /// clear below the arc's ends and the days beside them.
    static let heightShare: CGFloat = 0.10
    /// How far the dot and the sky ringing it reach from its middle, in line
    /// widths.
    private static let dotReach: CGFloat = 1.125

    /// Evenly spaced through the day, from midnight to midnight.
    var samples: UVIndexSamples
    /// How far through today now is, where today's dot goes.
    let nowFraction: Double
    /// Whether the chosen day is today, the one with the dot.
    let isToday: Bool
    let lineWidth: CGFloat
    /// How much of the day has gone by: up to now on today, and none on the
    /// days ahead.
    private var pastFraction: Double

    init(samples: UVIndexSamples, nowFraction: Double, isToday: Bool, lineWidth: CGFloat) {
        self.samples = samples
        self.nowFraction = nowFraction
        self.isToday = isToday
        self.lineWidth = lineWidth
        pastFraction = isToday ? nowFraction : 0
    }

    var animatableData: AnimatablePair<UVIndexSamples, Double> {
        get { AnimatablePair(samples, pastFraction) }
        set { (samples, pastFraction) = (newValue.first, newValue.second) }
    }

    /// As thick as the weather ring's arc of temperatures.
    static func lineWidth(ringWidth: CGFloat) -> CGFloat {
        ringWidth * 0.10
    }

    var body: some View {
        GeometryReader { geometry in
            // In from the edges by the dot's reach, so neither it nor the line
            // is cut off at the day's ends or the scale's.
            let plot = CGRect(origin: .zero, size: geometry.size)
                .insetBy(dx: lineWidth * Self.dotReach, dy: lineWidth * Self.dotReach)
            let height = max(geometry.size.height, 1)
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            let dotPoint = point(at: nowFraction, value: value(at: nowFraction), in: plot)

            ZStack {
                // What's gone by, uncolored as the weather ring's track is:
                // lighter where the sky is, but on its own, since the color
                // on it would wash out.
                ZStack {
                    line(from: 0, to: pastFraction, in: plot)
                        .stroke(.white.opacity(0.10), style: style)
                    dot(isHole: true)
                        .position(dotPoint)
                }
                .compositingGroup()
                .blendMode(.plusLighter)

                ZStack {
                    line(from: pastFraction, to: 1, in: plot)
                        .stroke(
                            // Up the scale, so each point takes the gauge's
                            // color at its index.
                            LinearGradient(
                                colors: UVIndexScale.colors,
                                startPoint: UnitPoint(x: 0.5, y: plot.maxY / height),
                                endPoint: UnitPoint(x: 0.5, y: plot.minY / height)
                            ),
                            style: style
                        )
                    dot(isHole: false)
                        .position(dotPoint)
                }
                .compositingGroup()
            }
        }
    }

    /// From `start` to `end` of the way through the day.
    private func line(from start: Double, to end: Double, in plot: CGRect) -> Path {
        guard end > start else { return Path() }
        let last = max(samples.values.count - 1, 1)
        let between = (0...last).map { Double($0) / Double(last) }.filter { $0 > start && $0 < end }
        return Path { path in
            path.addLines(([start] + between + [end]).map { point(at: $0, value: value(at: $0), in: plot) })
        }
    }

    /// Today's, placed even while hidden so it comes and goes where it is, in
    /// a ring cut out of its layer so the sky rings it, or for the layer of
    /// what's gone by, only the hole, as on the weather ring.
    private func dot(isHole: Bool) -> some View {
        ZStack {
            if isToday {
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

    /// On the line, between the samples either side.
    private func value(at fraction: Double) -> Double {
        let values = samples.values
        guard values.count > 1 else { return values.first ?? 0 }
        let position = min(max(fraction, 0), 1) * Double(values.count - 1)
        let index = min(Int(position), values.count - 2)
        return values[index] + (values[index + 1] - values[index]) * (position - Double(index))
    }

    private func point(at fraction: Double, value: Double, in plot: CGRect) -> CGPoint {
        let highest = Double(UVIndexScale.highestIndex)
        return CGPoint(
            x: plot.minX + plot.width * fraction,
            y: plot.maxY - plot.height * min(max(value, 0), highest) / highest
        )
    }
}

/// A day's samples for the chart, which animate from one day's to the next
/// sample by sample.
private struct UVIndexSamples: VectorArithmetic {
    var values: [Double]

    static var zero: Self {
        Self(values: [])
    }

    var magnitudeSquared: Double {
        values.reduce(0) { $0 + $1 * $1 }
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        lhs.combined(with: rhs, by: +)
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        lhs.combined(with: rhs, by: -)
    }

    mutating func scale(by rhs: Double) {
        values = values.map { $0 * rhs }
    }

    /// Sample by sample, with zero for any the other lacks, as `zero` has
    /// none.
    private func combined(with other: Self, by operation: (Double, Double) -> Double) -> Self {
        Self(values: (0..<max(values.count, other.values.count)).map { index in
            operation(
                values.indices.contains(index) ? values[index] : 0,
                other.values.indices.contains(index) ? other.values[index] : 0
            )
        })
    }
}

/// Hourly indexes as a smooth line that never strays above or below them.
/// Whole numbers, they rise and fall in steps, which a curve through each one
/// would show; rather, they're joined straight, and each moment takes the line
/// around it, weighted by a bell curve an hour wide either side.
private struct UVIndexLine {
    /// How far either side of a moment it takes the line from, in hours: past
    /// three times the bell curve's width, it weighs next to nothing.
    static let reach = 3.0

    /// In order along x, in hours.
    let points: [(x: Double, y: Double)]

    /// `count` moments' values from `start`, `step` hours apart.
    func values(from start: Double, every step: Double, count: Int) -> [Double] {
        let stepsAnHour = 1 / step
        let reachSteps = Int((Self.reach * stepsAnHour).rounded(.up))
        let weights = (-reachSteps...reachSteps).map { offset in
            exp(-pow(Double(offset) / stepsAnHour, 2) / 2)
        }
        let totalWeight = weights.reduce(0, +)
        let straight = (-reachSteps..<(count + reachSteps)).map { offset in
            straightValue(at: start + Double(offset) * step)
        }
        return (0..<count).map { index in
            zip(weights, straight[index...]).reduce(0) { $0 + $1.0 * $1.1 } / totalWeight
        }
    }

    /// Joined straight from point to point, and level beyond the first and last.
    private func straightValue(at x: Double) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }
        guard x > first.x else { return first.y }
        guard let next = points.firstIndex(where: { $0.x >= x }) else { return last.y }
        let previous = points[next - 1]
        return previous.y + (points[next].y - previous.y) * (x - previous.x) / (points[next].x - previous.x)
    }
}

private extension UVIndex.ExposureCategory {
    /// The category WeatherKit puts `index` in.
    init(index: Int) {
        self = Self.allCases.first { $0.rangeValue.contains(index) } ?? .low
    }

    /// As the iPhone app names them.
    var displayName: String {
        switch self {
        case .low: String(localized: "Low")
        case .moderate: String(localized: "Moderate")
        case .high: String(localized: "High")
        case .veryHigh: String(localized: "Very High")
        case .extreme: String(localized: "Extreme")
        }
    }
}

private extension View {
    /// At `angle` around a circle of `radius`, turned along it.
    func placed(at angle: Angle, radius: CGFloat) -> some View {
        let turn = UVIndexScale.isTurnedOver(angle) ? angle - .degrees(180) : angle
        return rotationEffect(turn)
            .offset(x: radius * sin(angle.radians), y: -radius * cos(angle.radians))
    }
}

#Preview {
    let date = Date.now
    let today = Calendar.current.startOfDay(for: date)
    let days = [5, 7, 9, 11, 8, 6, 4, 2, 1, 3].enumerated().map { index, uvIndex in
        CityWeather.Day(
            date: Calendar.current.date(byAdding: .day, value: index, to: today)!,
            highTemperature: Measurement(value: 24, unit: .celsius),
            lowTemperature: Measurement(value: 16, unit: .celsius),
            condition: .clear,
            precipitationChance: 0,
            uvIndex: uvIndex
        )
    }
    let hourlyUVIndexes = Dictionary(uniqueKeysWithValues: (0..<(days.count * 24)).map { index in
        // Highest at 1 PM, and none at night.
        (today.addingTimeInterval(Double(index) * 3600), max(0, days[index / 24].uvIndex - abs(index % 24 - 13)))
    })
    let weather = CityWeather(
        current: CityWeather.Conditions(
            temperature: Measurement(value: 22, unit: .celsius),
            condition: .clear,
            isDaylight: true,
            precipitationChance: 0
        ),
        wind: CityWeather.Wind(
            direction: 200,
            speed: Measurement(value: 18, unit: .kilometersPerHour),
            gust: Measurement(value: 29, unit: .kilometersPerHour)
        ),
        uvIndex: 3,
        hours: [:],
        hourlyUVIndexes: hourlyUVIndexes,
        days: days,
        fetchDate: date
    )

    NavigationStack {
        CityUVIndexView(date: date, timeZone: .current, dateStyle: "Relative")
            .ignoresSafeArea(edges: .bottom)
            .containerBackground(for: .navigation) {
                CitySkyBackground(date: date, timeZone: .current)
            }
    }
    .environment(WatchWeatherStore(weather: [TimeZone.current.identifier: weather]))
}
