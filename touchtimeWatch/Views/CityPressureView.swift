//
//  CityPressureView.swift
//  touchtimeWatch
//

import CoreLocation
import SwiftUI
import WeatherKit

/// The city's sea-level pressure on a gauge laid out as UV Index's: a glass
/// arc as wide as the daylight ring, from deep lows at the bottom left,
/// clockwise over standard pressure at the top, to strong highs at the bottom
/// right, with a ring on it at the pressure, lit beside it for which way the
/// pressure's going, and around it the forecast's days, the chosen one on a
/// pill. In the middle, the pressure over its unit, and below the arc, over
/// the date, the chosen day's pressure hour by hour under which way it's
/// going.
/// Today's is the pressure now, and the Digital Crown moves the pill to each
/// day after it, as far as the forecast goes, for the day's average and which
/// way it goes over the day.
/// On the watch's own clock, tapping the arc turns on the barometer: in the
/// middle, the pressure where the watch is, at its elevation rather than at
/// sea level; the ring at that pressure brought down to sea level, to compare
/// with the forecast's; where the watch is over the top of the gauge, once it
/// knows; and the elevation in place of the date. Elsewhere, tapping it says
/// so.
struct CityPressureView: View {
    /// The least the chart spans, in hectopascals, so a calm spell's little
    /// ups and downs stay little.
    private static let leastChartSpan = 10.0
    /// Between the gauge's room and the date under it.
    private static let dateSpacing: CGFloat = 8
    /// The arc's tint while the barometer's on, as Wind's glass's while live.
    private static let liveColor = Color.yellow

    let date: Date
    let timeZone: TimeZone
    /// The iPhone app's pressure unit.
    let pressureUnit: PressureUnit
    /// The iPhone app's date style, for `Date.formattedDate(style:)`.
    let dateStyle: String
    /// How many days after today the Digital Crown has turned to.
    @Binding var crownDays: Double
    /// Whether tapping the arc turns on the barometer. Only the watch's own
    /// clock does, as the barometer reads the air where the watch is rather
    /// than the city's.
    let canGoLive: Bool
    /// Whether the barometer is on, which tapping the arc turns on and off.
    @Binding var isLive: Bool

    @Environment(WatchWeatherStore.self) private var weatherStore
    @Environment(\.isPresented) private var isPresented
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsBarometerAlert = false
    /// Made the first time the barometer turns on.
    @State private var barometer: LiveBarometer?
    @FocusState private var isCrownFocused: Bool

    var body: some View {
        let weather = weatherStore.weather[timeZone.identifier]
        let days = days(in: weather)
        let chosenDayIndex = min(max(Int(crownDays.rounded()), 0), max(days.count - 1, 0))
        let chosenDay = days.indices.contains(chosenDayIndex) ? days[chosenDayIndex] : nil
        let forecastReading = chosenDayIndex == 0
            ? weather.map { PressureReading(pressure: $0.pressure, trend: $0.pressureTrend) }
            : chosenDay.flatMap { day in weather.flatMap { reading(for: day, in: $0) } }
        let reading = isLive ? barometer?.pressure.map { PressureReading(pressure: $0) } : forecastReading
        // At sea level, as the forecast's is: the barometer's once the watch
        // knows its elevation, and the forecast's until then. Live, without
        // which way it's going, as the barometer has no hours to go by.
        let ringReading = isLive
            ? (barometer?.seaLevelPressure ?? forecastReading?.pressure).map { PressureReading(pressure: $0) }
            : forecastReading
        let isLoading = isLive
            ? reading == nil && barometer?.isUnavailable != true
            : weather == nil && !weatherStore.unavailableTimeZones.contains(timeZone.identifier)
        // The barometer has no hours to chart.
        let chartSamples = isLive ? nil : chosenDay.flatMap { day in
            weather.flatMap { weather in
                DayLineChart.Samples(hourly: weather.hourlyHectopascals, day: day.date, calendar: calendar)
                    .map { Self.fitted($0) }
            }
        }

        VStack(spacing: Self.dateSpacing) {
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
                // Under the circle, which is centered in the room, to the date.
                let chartOffset = DayLineChart.offset(
                    lineWidth: chartLineWidth,
                    spaceBelow: (geometry.size.height - diameter) / 2 + Self.dateSpacing
                )

                ZStack {
                    glass(diameter: diameter, ringWidth: ringWidth)

                    PressureGauge(
                        diameter: diameter,
                        ringWidth: ringWidth,
                        reading: ringReading,
                        dayNumbers: days.map { calendar.component(.day, from: $0.date) },
                        chosenDayIndex: chosenDayIndex,
                        isLive: isLive,
                        coordinate: barometer?.coordinate
                    )
                    // So taps on the ring reach the glass under it.
                    .allowsHitTesting(false)
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
                        DayLineChart(
                            samples: chartSamples,
                            scale: 0...1,
                            colors: [.purple],
                            nowFraction: nowFraction,
                            isToday: chosenDayIndex == 0,
                            lineWidth: chartLineWidth
                        )
                        .frame(height: diameter * DayLineChart.heightShare)
                        .offset(y: chartOffset)
                        .accessibilityHidden(true)
                    }
                    .frame(width: diameter - PressureGauge.bandWidth * 2, height: diameter, alignment: .bottom)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }

            // Today's until the days come in, and the watch's elevation while
            // the barometer's on.
            Text(isLive ? elevationLabel : dayLabel(chosenDay?.date ?? date))
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
        .animation(.smooth, value: barometer?.pressure)
        .animation(.smooth, value: barometer?.elevation)
        // As on the details, not while sliding back to the list, so a quick
        // turn scrolls the list rather than the days. Nor while the
        // barometer's on, as it reads only now.
        .background {
            Color.clear
                .focusable(isPresented && !isLive)
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
        .onAppear {
            // A sheet takes the Digital Crown, and doesn't give it back.
            isCrownFocused = !isLive
            if isLive {
                startBarometer()
            }
        }
        .onDisappear {
            isCrownFocused = false
            barometer?.stop()
        }
        .onChange(of: isLive) { _, isLive in
            isCrownFocused = !isLive
            if isLive {
                startBarometer()
            } else {
                barometer?.stop()
            }
        }
        // Only while the watch is raised and the view is on screen.
        .onChange(of: scenePhase) { _, phase in
            guard isLive else { return }
            if phase == .active {
                startBarometer()
            } else {
                barometer?.stop()
            }
        }
        // Every quarter hour, in case the weather has gone stale.
        .onChange(of: Int(date.timeIntervalSinceReferenceDate / 900), initial: true) {
            weatherStore.update(for: timeZone)
        }
        // Untitled. Verbatim, so the string catalog doesn't gain an empty key
        .alert(Text(verbatim: ""), isPresented: $showsBarometerAlert, actions: {}) {
            Text("Barometer is only available for Local.")
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: showsBarometerAlert) { _, showsAlert in showsAlert }
    }

    /// The barometer's elevation, in whole feet where the watch's region
    /// measures in US units and in whole meters elsewhere, or dashes until
    /// it's known.
    private var elevationLabel: String {
        let style = Measurement<UnitLength>.FormatStyle(
            width: .abbreviated,
            locale: locale,
            usage: .asProvided,
            numberFormatStyle: .number.precision(.fractionLength(0))
        )
        let elevation = barometer?.elevation.map { elevation in
            let converted = elevation.converted(to: locale.measurementSystem == .us ? .feet : .meters)
            let rounded = converted.value.rounded()
            // Just under sea level reads 0 rather than -0.
            return Measurement(value: rounded == 0 ? 0 : rounded, unit: converted.unit).formatted(style)
        }
        return String(localized: "Elevation \(elevation ?? "--")")
    }

    /// The arc, glass, which turns the barometer on and off, tinted while
    /// it's on.
    private func glass(diameter: CGFloat, ringWidth: CGFloat) -> some View {
        let arcDiameter = diameter - PressureGauge.bandWidth * 2
        let band = PressureGauge.band(ringWidth: ringWidth)
        let tint: Color? = isLive ? Self.liveColor : nil
        let traits: AccessibilityTraits = isLive ? [.isButton, .isSelected] : .isButton

        return Color.clear
            .frame(width: arcDiameter, height: arcDiameter)
            .glassEffect(.clear.tint(tint).interactive(), in: band)
            .contentShape(band)
            .onTapGesture(perform: tapGlass)
            .sensoryFeedback(.start, trigger: isLive) { _, isLive in isLive }
            .accessibilityElement()
            .accessibilityLabel("Barometer")
            .accessibilityAddTraits(traits)
            .accessibilityAction {
                tapGlass()
            }
    }

    private func tapGlass() {
        if canGoLive {
            withAnimation(.smooth) {
                isLive.toggle()
            }
        } else {
            showsBarometerAlert = true
        }
    }

    private func startBarometer() {
        if barometer == nil {
            barometer = LiveBarometer()
        }
        barometer?.start()
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
    /// Nil for the barometer's, which has no hours to go by.
    var trend: PressureTrend?
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

/// UV Index's gauge with its arc left to the glass under it: the forecast's
/// days around the outside of the arc, the one the Digital Crown has turned
/// to cut out of a pill like the daylight ring's current hour's, inside a
/// border like the daylight ring's edge; and on the arc, at the pressure, a
/// ring like UV Index's sun, with light along the arc beside it. Below the
/// arc's ends its edge and the border fade away. While the barometer's on,
/// they go all the way around, with where the watch is over the top in place
/// of the days (the app's name until it knows), the barometer's name under
/// the bottom, and a dot out from each end of the arc.
private struct PressureGauge: View {
    /// How far past the arc the days and their border reach, as the daylight
    /// ring's hours do.
    static let bandWidth: CGFloat = 16
    /// The days', and what's printed in their place.
    private static let labelFont = Font.system(size: 11, weight: .semibold, design: .rounded)
    /// Over the top while the barometer's on, until the watch knows where it
    /// is, as a barometer's maker is printed on its dial.
    private static let makerName = "TOUCH TIME"
    /// Under the bottom while the barometer's on. Both are in English whatever
    /// the watch's language, as is where the watch is.
    private static let instrumentName = "BAROMETER"
    /// The dots out from the arc's ends while the barometer's on, marking the
    /// lowest and highest pressures it shows.
    private static let endDotDiameter: CGFloat = 5
    /// The arc's edge and the border around the days, as the daylight ring's.
    private static let lineWidth: CGFloat = 1.5
    /// Theirs.
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
    /// At sea level, the barometer's too. Nil until the weather comes in, and
    /// on a day the forecast's hours don't cover.
    let reading: PressureReading?
    /// Each of the forecast's days from today, by its day of the month.
    let dayNumbers: [Int]
    /// The day the Digital Crown has turned to.
    let chosenDayIndex: Int
    /// Whether the barometer's on, which tints the glass under the arc, closes
    /// the border, and prints where the watch is, the barometer's name and the
    /// arc's ends around it in place of the days.
    let isLive: Bool
    /// Where the watch is. Nil until it knows.
    let coordinate: CLLocationCoordinate2D?

    /// Where the ring was last, so that when the pressure goes, the ring and
    /// the light beside it fade away there rather than at the top.
    @State private var lastMarkerAngle = Angle.zero

    var body: some View {
        let arcDiameter = diameter - Self.bandWidth * 2
        // Halfway between the arc's edge and the border.
        let labelRadius = (arcDiameter + Self.bandWidth - Self.lineWidth) / 2
        // Through the middle of the arc.
        let arcRadius = (arcDiameter - ringWidth) / 2
        let pressure = reading?.pressure
        let markerAngle = pressure.map { PressureScale.angle(pressure: $0) } ?? lastMarkerAngle
        // As big as the daylight ring's sun.
        let markerDiameter = ringWidth * 0.60
        let dayCount = max(dayNumbers.count, PressureScale.forecastDays)
        let pillAngle = PressureScale.angle(day: chosenDayIndex, of: dayCount)
        let coordinateText = Self.coordinateText(coordinate)

        ZStack {
            if isLive {
                ZStack {
                    printed(coordinateText, radius: labelRadius, isAtBottom: false)
                        .id(coordinateText)
                        .transition(.blurReplace)
                    printed(Self.instrumentName, radius: labelRadius, isAtBottom: true)
                }
                // From the app's name to where the watch is, and on as it moves.
                .animation(.smooth, value: coordinateText)
                .transition(.blurReplace)
            } else {
                // The days it covers cut out of the pill, so the sky shows
                // through them as it moves from day to day.
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
                .transition(.blurReplace)
            }

            // Blended outside the transition, so the dots blend with the sky
            // as they blur in and out too, rather than only once they're in.
            ZStack {
                if isLive {
                    ForEach([PressureScale.startAngle, PressureScale.startAngle + PressureScale.sweep], id: \.degrees) { angle in
                        Circle()
                            .fill(.white)
                            .opacity(0.25)
                            .frame(width: Self.endDotDiameter, height: Self.endDotDiameter)
                            .placed(at: angle, radius: labelRadius)
                            .transition(.blurReplace)
                    }
                }
            }
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
                Self.band(ringWidth: ringWidth)
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
            // bottom to the chart, which the barometer doesn't have.
            .mask {
                ZStack {
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: height(at: PressureScale.startAngle, radius: arcDiameter / 2)),
                            .init(color: .clear, location: height(at: PressureScale.fadeEndAngle, radius: arcDiameter / 2))
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    Color.white
                        .opacity(isLive ? 1 : 0)
                }
            }
            .blendMode(.plusLighter)

            // Transitioning inside the placement scales the ring about itself
            // rather than the gauge's center.
            ZStack {
                if pressure != nil {
                    Circle()
                        // White would wash out on the glass's tint.
                        .strokeBorder(isLive ? .black : .white, lineWidth: Self.markerLineWidth)
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
            // …rather than travelling there from where it last was.
            .animation(nil, value: pressure != nil)
        }
        .frame(width: diameter, height: diameter)
        .onChange(of: markerAngle, initial: true) { _, angle in
            lastMarkerAngle = angle
        }
    }

    /// The arc `ringWidth` wide, from its start to its end, its ends round,
    /// in a frame as wide as it is.
    static func band(ringWidth: CGFloat) -> some Shape {
        Circle()
            .inset(by: ringWidth / 2)
            // A circle's path starts at its right, a quarter turn past the
            // top.
            .rotation(PressureScale.startAngle - .degrees(90))
            .trim(from: 0, to: PressureScale.sweep.degrees / 360)
            .stroke(style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
    }

    /// Each day at its place around a circle of `radius`, spaced for `count`.
    private func days(radius: CGFloat, count: Int) -> some View {
        ZStack {
            ForEach(dayNumbers.indices, id: \.self) { index in
                Text(dayNumbers[index], format: .number)
                    .placed(at: PressureScale.angle(day: index, of: count), radius: radius)
            }
        }
        .font(Self.labelFont)
        // The whole gauge's, for the pill to mask.
        .frame(width: diameter, height: diameter)
    }

    /// `text` bent along a circle of `radius`, over the top, or under the
    /// bottom turned to read left to right.
    private func printed(_ text: String, radius: CGFloat, isAtBottom: Bool) -> some View {
        CurvedText(
            text: text,
            font: Self.labelFont,
            radius: radius,
            maxAngle: PressureScale.sweep,
            isAtBottom: isAtBottom
        )
    }

    /// Like 51°30′N · 0°08′W, to the nearest minute of arc, or the app's name
    /// until the watch knows where it is.
    private static func coordinateText(_ coordinate: CLLocationCoordinate2D?) -> String {
        guard let coordinate else { return makerName }
        let latitude = degreesAndMinutes(coordinate.latitude, positive: "N", negative: "S")
        let longitude = degreesAndMinutes(coordinate.longitude, positive: "E", negative: "W")
        return "\(latitude) · \(longitude)"
    }

    /// `degrees` to the nearest minute of arc, then which side of the equator
    /// or prime meridian it's on.
    private static func degreesAndMinutes(_ degrees: Double, positive: String, negative: String) -> String {
        let minutes = Int((abs(degrees) * 60).rounded())
        // Just south or west of either reads as on it rather than 0°00′S.
        let side = degrees < 0 && minutes > 0 ? negative : positive
        return "\(minutes / 60)°" + String(format: "%02d′", minutes % 60) + side
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
        guard let trend = reading.trend else { return pressure }
        return "\(pressure), \(trend.displayName)"
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
    @Previewable @State var crownDays: Double = 0
    @Previewable @State var isLive = false
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
        humidity: CityWeather.Humidity(relative: 0.85, dewPoint: Measurement(value: 9, unit: .celsius)),
        hours: [:],
        hourlyUVIndexes: [:],
        hourlyPressures: hourlyPressures,
        hourlyHumidities: [:],
        days: days,
        fetchDate: date
    )

    NavigationStack {
        CityPressureView(
            date: date,
            timeZone: .current,
            pressureUnit: .millibars,
            dateStyle: "Relative",
            crownDays: $crownDays,
            canGoLive: true,
            isLive: $isLive
        )
        .ignoresSafeArea(edges: .bottom)
        .containerBackground(for: .navigation) {
            CitySkyBackground(date: date, timeZone: .current)
        }
    }
    .environment(WatchWeatherStore(weather: [TimeZone.current.identifier: weather]))
}
