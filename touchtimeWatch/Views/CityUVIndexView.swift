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
    /// Between the gauge's room and the date under it.
    private static let dateSpacing: CGFloat = 8

    let date: Date
    let timeZone: TimeZone
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
        let uvIndex = chosenDayIndex == 0 ? weather?.uvIndex : chosenDay?.uvIndex
        let chartSamples = chosenDay.flatMap { day in
            weather.flatMap { weather in
                DayLineChart.Samples(
                    hourly: weather.hourlyUVIndexes.mapValues { Double($0) },
                    day: day.date,
                    calendar: calendar
                )
            }
        }

        VStack(spacing: Self.dateSpacing) {
            GeometryReader { geometry in
                // Laid out as the daylight ring is, so the gauge's border is
                // where the ring's edge is, and the arc as wide as the ring.
                let diameter = max(0, min(geometry.size.width - 16, geometry.size.height))
                let ringWidth = diameter * 0.20
                let holeDiameter = diameter - UVIndexGauge.bandWidth * 2 - ringWidth * 2
                let chartLineWidth = DayLineChart.lineWidth(ringWidth: ringWidth)
                // From the arc's ends down to the label's bottom, a line's
                // width over the chart in the bottom of the circle.
                let labelRoom = diameter * (0.5 - DayLineChart.heightShare) - chartLineWidth
                    - UVIndexGauge.endsDepth(diameter: diameter, ringWidth: ringWidth)
                // Under the circle, which is centered in the room, to the date.
                let chartOffset = DayLineChart.offset(
                    lineWidth: chartLineWidth,
                    spaceBelow: (geometry.size.height - diameter) / 2 + Self.dateSpacing
                )

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
                        DayLineChart(
                            samples: chartSamples,
                            // The gauge's, in its colors.
                            scale: 0...Double(UVIndexScale.highestIndex),
                            colors: UVIndexScale.colors,
                            nowFraction: nowFraction,
                            isToday: chosenDayIndex == 0,
                            lineWidth: chartLineWidth
                        )
                        .frame(height: diameter * DayLineChart.heightShare)
                        .offset(y: chartOffset)
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
    /// At `angle` around a circle of `radius`, its bottom toward the circle's
    /// middle. Unlike the daylight ring's hours, none turns over across the
    /// bottom half, so the days read in order along the gauge, clockwise.
    func placed(at angle: Angle, radius: CGFloat) -> some View {
        rotationEffect(angle)
            .offset(x: radius * sin(angle.radians), y: -radius * cos(angle.radians))
    }
}

#Preview {
    @Previewable @State var crownDays: Double = 0
    let date = Date.now
    let today = Calendar.current.startOfDay(for: date)
    let days = [5, 7, 9, 11, 8, 6, 4, 2, 1, 3].enumerated().map { index, uvIndex in
        CityWeather.Day(
            date: Calendar.current.date(byAdding: .day, value: index, to: today)!,
            highTemperature: Measurement(value: 24, unit: .celsius),
            lowTemperature: Measurement(value: 16, unit: .celsius),
            condition: .clear,
            precipitationChance: 0,
            precipitationAmount: Measurement(value: 0, unit: .millimeters),
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
        pressure: Measurement(value: 1013, unit: .hectopascals),
        pressureTrend: .steady,
        humidity: CityWeather.Humidity(relative: 0.5, dewPoint: Measurement(value: 11, unit: .celsius)),
        hours: [:],
        hourlyUVIndexes: hourlyUVIndexes,
        hourlyPressures: [:],
        hourlyHumidities: [:],
        days: days,
        fetchDate: date
    )

    NavigationStack {
        CityUVIndexView(date: date, timeZone: .current, dateStyle: "Relative", crownDays: $crownDays)
            .ignoresSafeArea(edges: .bottom)
            .containerBackground(for: .navigation) {
                CitySkyBackground(date: date, timeZone: .current)
            }
    }
    .environment(WatchWeatherStore(weather: [TimeZone.current.identifier: weather]))
}
