//
//  CityHumidityView.swift
//  touchtimeWatch
//

import SwiftUI
import WeatherKit

/// The city's relative humidity on a gauge laid out as Pressure's: an arc as
/// wide as the daylight ring, lighter where the sky is, from 0% at the bottom
/// left, clockwise over the top, to 100% at the bottom right, with a ring on
/// it at the humidity, and around it the forecast's days, the chosen one on a
/// pill. In the middle, the humidity, and below the arc, over the date, the
/// chosen day's humidity hour by hour in the Weather app's humidity color
/// under the dew point.
/// Today's is the humidity and dew point now, and the Digital Crown moves the
/// pill to each day after it, as far as the forecast goes, for the day's
/// averages.
struct CityHumidityView: View {
    /// Between the gauge's room and the date under it.
    private static let dateSpacing: CGFloat = 8

    let date: Date
    let timeZone: TimeZone
    /// The iPhone app's temperature unit: Celsius, or Fahrenheit when false.
    let useCelsius: Bool
    /// The iPhone app's date style, for `Date.formattedDate(style:)`.
    let dateStyle: String
    /// How many days after today the Digital Crown has turned to.
    @Binding var crownDays: Double

    @Environment(WatchWeatherStore.self) private var weatherStore
    @Environment(\.isPresented) private var isPresented
    @FocusState private var isCrownFocused: Bool

    var body: some View {
        let weather = weatherStore.weather[timeZone.identifier]
        let isLoading = weather == nil && !weatherStore.unavailableTimeZones.contains(timeZone.identifier)
        let days = days(in: weather)
        let chosenDayIndex = min(max(Int(crownDays.rounded()), 0), max(days.count - 1, 0))
        let chosenDay = days.indices.contains(chosenDayIndex) ? days[chosenDayIndex] : nil
        let humidity = chosenDayIndex == 0
            ? weather?.humidity
            : chosenDay.flatMap { day in weather.flatMap { averageHumidity(on: day, in: $0) } }
        let chartSamples = chosenDay.flatMap { day in
            weather.flatMap { weather in
                DayLineChart.Samples(
                    hourly: weather.hourlyHumidities.mapValues(\.relative),
                    day: day.date,
                    calendar: calendar
                )
            }
        }

        VStack(spacing: Self.dateSpacing) {
            GeometryReader { geometry in
                // Laid out as UV Index's and Pressure's gauges, so going from
                // one to another, the gauge stays where it is.
                let diameter = max(0, min(geometry.size.width - 16, geometry.size.height))
                let ringWidth = diameter * 0.20
                let holeDiameter = diameter - HumidityGauge.bandWidth * 2 - ringWidth * 2
                let chartLineWidth = DayLineChart.lineWidth(ringWidth: ringWidth)
                // From the arc's ends down to the label's bottom, a line's
                // width over the chart in the bottom of the circle.
                let labelRoom = diameter * (0.5 - DayLineChart.heightShare) - chartLineWidth
                    - HumidityGauge.endsDepth(diameter: diameter, ringWidth: ringWidth)
                let labelWidth = HumidityGauge.widthBelowEnds(diameter: diameter, ringWidth: ringWidth)
                // Under the circle, which is centered in the room, to the date.
                let chartOffset = DayLineChart.offset(
                    lineWidth: chartLineWidth,
                    spaceBelow: (geometry.size.height - diameter) / 2 + Self.dateSpacing
                )

                ZStack {
                    HumidityGauge(
                        diameter: diameter,
                        ringWidth: ringWidth,
                        humidity: humidity?.relative,
                        dayNumbers: days.map { calendar.component(.day, from: $0.date) },
                        chosenDayIndex: chosenDayIndex
                    )
                    .accessibilityHidden(true)

                    HumidityCenter(humidity: humidity, useCelsius: useCelsius, isLoading: isLoading)
                        .frame(width: holeDiameter * 0.80)
                        .frame(width: holeDiameter, height: holeDiameter)

                    // The dew point over the chart, under the arc's ends, as
                    // UV Index's label and chart are: in the bottom of the
                    // gauge's circle rather than in a row of their own, which
                    // would shrink the gauge and its arc.
                    VStack(spacing: chartLineWidth) {
                        DewPointLabel(dewPoint: humidity?.dewPoint, useCelsius: useCelsius)
                            // Smaller rather than running into the arc's ends,
                            // or on the smaller watches the days beside them,
                            // at the largest text sizes.
                            .frame(maxWidth: labelWidth, maxHeight: max(labelRoom, 0), alignment: .bottom)
                        DayLineChart(
                            samples: chartSamples,
                            // The gauge's.
                            scale: 0...1,
                            colors: HumidityScale.colors,
                            nowFraction: nowFraction,
                            isToday: chosenDayIndex == 0,
                            lineWidth: chartLineWidth
                        )
                        .frame(height: diameter * DayLineChart.heightShare)
                        .offset(y: chartOffset)
                        .accessibilityHidden(true)
                    }
                    .frame(width: diameter - HumidityGauge.bandWidth * 2, height: diameter, alignment: .bottom)
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

    /// `day`'s humidity and dew point, each averaged over its hours, as the
    /// Weather app sums up a day's humidity, or nil unless the hours cover
    /// the day.
    private func averageHumidity(on day: CityWeather.Day, in weather: CityWeather) -> CityWeather.Humidity? {
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: day.date) else { return nil }
        let dayHours = dayEnd.timeIntervalSince(day.date) / 3600
        let points = weather.hourlyHumidities
            .map { (x: $0.key.timeIntervalSince(day.date) / 3600, humidity: $0.value) }
            .filter { $0.x >= 0 && $0.x < dayHours }
            .sorted { $0.x < $1.x }
        // Within an hour, as hours start off a half-hour city's midnight.
        guard let first = points.first, let last = points.last, first.x < 1, last.x >= dayHours - 1 else {
            return nil
        }
        let count = Double(points.count)
        return CityWeather.Humidity(
            relative: points.reduce(0) { $0 + $1.humidity.relative } / count,
            dewPoint: Measurement(
                value: points.reduce(0) { $0 + $1.humidity.dewPoint.converted(to: .celsius).value } / count,
                unit: .celsius
            )
        )
    }
}

/// Where things go around the gauge, as on Pressure's: from the bottom left,
/// where 8 is on a clock's face, clockwise over the top, to the bottom right,
/// where 4 is. Humidities run from 0% at the start, through 50% at the top,
/// to 100% at the end, and the forecast's days from today at the start to
/// its last at the end.
private enum HumidityScale {
    /// The days WeatherKit forecasts. The gauge has room for as many even
    /// once the first has gone by, so the others keep their places.
    static let forecastDays = 10
    /// From the top, clockwise.
    static let startAngle = Angle.degrees(240)
    static let sweep = Angle.degrees(240)
    /// Where the lines around the gauge have faded away below its start, and
    /// as far below its end.
    static let fadeEndAngle = Angle.degrees(225)
    /// The Weather app's humidity chart's.
    static let colors: [Color] = [.green]

    /// `humidity` from 0 to 1.
    static func angle(humidity: Double) -> Angle {
        angle(along: min(max(humidity, 0), 1))
    }

    /// The `day`th of `count` days from the start.
    static func angle(day: Int, of count: Int) -> Angle {
        angle(along: count > 1 ? Double(day) / Double(count - 1) : 0)
    }

    private static func angle(along fraction: Double) -> Angle {
        .degrees(startAngle.degrees + sweep.degrees * fraction)
    }
}

/// Pressure's gauge, its ring at the humidity: the forecast's days around the
/// outside of the arc, the one the Digital Crown has turned to cut out of a
/// pill like the daylight ring's current hour's, inside a border like the
/// daylight ring's edge; the arc, lighter where the sky is, as the border is;
/// and on it, at the humidity, a ring like UV Index's sun. Below the arc's
/// ends its edge and the border fade away.
private struct HumidityGauge: View {
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
    /// From 0 to 1. Nil until the weather comes in, and on a day the
    /// forecast's hours don't cover.
    let humidity: Double?
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
        let markerAngle = humidity.map { HumidityScale.angle(humidity: $0) } ?? .zero
        // As big as the daylight ring's sun.
        let markerDiameter = ringWidth * 0.60
        let dayCount = max(dayNumbers.count, HumidityScale.forecastDays)
        let pillAngle = HumidityScale.angle(day: chosenDayIndex, of: dayCount)

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
                        .init(color: .white, location: height(at: HumidityScale.startAngle, radius: arcDiameter / 2)),
                        .init(color: .clear, location: height(at: HumidityScale.fadeEndAngle, radius: arcDiameter / 2))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .blendMode(.plusLighter)

            // Transitioning inside the placement scales the ring about itself
            // rather than the gauge's center.
            ZStack {
                if humidity != nil {
                    Circle()
                        .strokeBorder(.white, lineWidth: Self.markerLineWidth)
                        .transition(.blurReplace)
                }
            }
            .frame(width: markerDiameter, height: markerDiameter)
            // Coming in where it is…
            .animation(.smooth, value: humidity != nil)
            // Turned around the gauge's middle, from humidity to humidity
            // along the arc rather than across the gauge.
            .offset(y: -arcRadius)
            .rotationEffect(markerAngle)
            // …rather than travelling there from the gauge's top.
            .animation(nil, value: humidity != nil)
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
            .rotation(HumidityScale.startAngle - .degrees(90))
            .trim(from: 0, to: HumidityScale.sweep.degrees / 360)
    }

    private var arcStyle: StrokeStyle {
        StrokeStyle(lineWidth: ringWidth, lineCap: .round)
    }

    /// Each day at its place around a circle of `radius`, spaced for `count`.
    private func days(radius: CGFloat, count: Int) -> some View {
        ZStack {
            ForEach(dayNumbers.indices, id: \.self) { index in
                Text(dayNumbers[index], format: .number)
                    .placed(at: HumidityScale.angle(day: index, of: count), radius: radius)
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
        return -arcRadius * cos(HumidityScale.startAngle.radians) + ringWidth / 2
    }

    /// How wide the arc's outer edge is as far down as its round ends reach,
    /// where what's just below them is clear of the days beside them.
    static func widthBelowEnds(diameter: CGFloat, ringWidth: CGFloat) -> CGFloat {
        let radius = (diameter - bandWidth * 2) / 2
        let depth = endsDepth(diameter: diameter, ringWidth: ringWidth)
        return 2 * sqrt(max(radius * radius - depth * depth, 0))
    }

    /// How far down the gauge a circle of `radius` around its middle is at
    /// `angle`, from the top, clockwise, as a share of the gauge's height.
    private func height(at angle: Angle, radius: CGFloat) -> CGFloat {
        guard diameter > 0 else { return 0 }
        return 0.5 - radius * cos(angle.radians) / diameter
    }
}

/// The humidity, in the middle of the gauge.
private struct HumidityCenter: View {
    /// Pressure's pressure's: the daylight ring's time's font.
    private static let humidityFont = Font.system(.title3, design: .rounded, weight: .medium).monospacedDigit()

    /// Nil until the weather comes in, and on a day the forecast's hours
    /// don't cover.
    let humidity: CityWeather.Humidity?
    let useCelsius: Bool
    let isLoading: Bool

    var body: some View {
        ZStack {
            if let humidity {
                Text(humidity.relative.formattedPercent)
                    .font(Self.humidityFont)
                    .contentTransition(.numericText(value: humidity.relative))
                    .transition(.blurReplace)
            } else if isLoading {
                ProgressView()
                    .transition(.blurReplace)
            } else {
                Text(verbatim: "--")
                    .font(Self.humidityFont)
                    .transition(.blurReplace)
            }
        }
        .foregroundStyle(.primary)
        .lineLimit(1)
        // At the largest text sizes on the smallest watch.
        .minimumScaleFactor(0.4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Humidity")
        .accessibilityValue(accessibilityValue)
    }

    /// With the dew point: the label under the arc is hidden from VoiceOver.
    private var accessibilityValue: String {
        guard let humidity else { return "" }
        let dewPoint = humidity.dewPoint.degrees(useCelsius: useCelsius)
        return "\(humidity.relative.formattedPercent), \(String(localized: "Dew Point \(dewPoint)"))"
    }
}

/// The dew point after a drop, just above the chart.
private struct DewPointLabel: View {
    /// Nil until the weather comes in, and on a day the forecast's hours
    /// don't cover.
    let dewPoint: Measurement<UnitTemperature>?
    let useCelsius: Bool

    var body: some View {
        ZStack {
            if let dewPoint {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Image(systemName: "drop.fill")
                    Text(dewPoint.degrees(useCelsius: useCelsius))
                        .contentTransition(.numericText(value: dewPoint.converted(to: .celsius).value))
                }
                .transition(.blurReplace)
            }
        }
        // As the date's under the chart.
        .font(.subheadline)
        .monospacedDigit()
        .foregroundStyle(.primary)
        .blendMode(.plusLighter)
        .lineLimit(1)
        // At the largest text sizes on the smallest watch.
        .minimumScaleFactor(0.4)
        .accessibilityHidden(true)
    }
}

private extension Double {
    /// A humidity from 0 to 1 in whole percent, as the Weather app shows it.
    var formattedPercent: String {
        formatted(.percent.precision(.fractionLength(0)))
    }
}

private extension Measurement<UnitTemperature> {
    /// In whole degrees toward zero, without the unit's letter, as Conditions
    /// and the iPhone app show temperatures.
    func degrees(useCelsius: Bool) -> String {
        let value = converted(to: useCelsius ? .celsius : .fahrenheit).value
        guard value.isFinite else { return "--°" }
        return "\(Int(value))°"
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
    let date = Date.now
    let today = Calendar.current.startOfDay(for: date)
    let days = (0..<10).map { index in
        CityWeather.Day(
            date: Calendar.current.date(byAdding: .day, value: index, to: today)!,
            highTemperature: Measurement(value: 18, unit: .celsius),
            lowTemperature: Measurement(value: 10, unit: .celsius),
            condition: .partlyCloudy,
            precipitationChance: 0.1,
            precipitationAmount: Measurement(value: 0, unit: .millimeters),
            uvIndex: 3
        )
    }
    let hourlyHumidities = Dictionary(uniqueKeysWithValues: (0..<(days.count * 24)).map { index in
        // Most humid before dawn and driest mid-afternoon, and damper all
        // day on the third, as rain passes over.
        let day = Double(index) / 24
        let rain = exp(-pow(day - 2.5, 2))
        let relative = min(0.68 + 0.18 * cos((Double(index % 24) - 4) / 24 * 2 * .pi) + 0.15 * rain, 1)
        return (
            today.addingTimeInterval(Double(index) * 3600),
            CityWeather.Humidity(relative: relative, dewPoint: Measurement(value: 9 + 4 * rain, unit: .celsius))
        )
    })
    let weather = CityWeather(
        current: CityWeather.Conditions(
            temperature: Measurement(value: 15, unit: .celsius),
            condition: .partlyCloudy,
            isDaylight: true,
            precipitationChance: 0.1
        ),
        wind: CityWeather.Wind(
            direction: 200,
            speed: Measurement(value: 18, unit: .kilometersPerHour),
            gust: Measurement(value: 29, unit: .kilometersPerHour)
        ),
        uvIndex: 3,
        pressure: Measurement(value: 1013, unit: .hectopascals),
        pressureTrend: .steady,
        humidity: CityWeather.Humidity(relative: 0.72, dewPoint: Measurement(value: 10, unit: .celsius)),
        hours: [:],
        hourlyUVIndexes: [:],
        hourlyPressures: [:],
        hourlyHumidities: hourlyHumidities,
        days: days,
        fetchDate: date
    )

    NavigationStack {
        CityHumidityView(
            date: date,
            timeZone: .current,
            useCelsius: true,
            dateStyle: "Relative",
            crownDays: $crownDays
        )
        .ignoresSafeArea(edges: .bottom)
        .containerBackground(for: .navigation) {
            CitySkyBackground(date: date, timeZone: .current)
        }
    }
    .environment(WatchWeatherStore(weather: [TimeZone.current.identifier: weather]))
}
