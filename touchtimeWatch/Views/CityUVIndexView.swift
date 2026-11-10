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
/// on a pill. In the middle, the index, and below, how high it is, over the
/// date.
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

        VStack(spacing: 8) {
            GeometryReader { geometry in
                // Laid out as the daylight ring is, so the gauge's border is
                // where the ring's edge is, and the arc as wide as the ring.
                let diameter = max(0, min(geometry.size.width - 16, geometry.size.height))
                let ringWidth = diameter * 0.20
                let holeDiameter = diameter - UVIndexGauge.bandWidth * 2 - ringWidth * 2

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
                // The full width rather than the date's own, for how high the
                // index is over it.
                .frame(maxWidth: .infinity)
                // Over the bottom of the gauge rather than in a row of its
                // own, which would shrink the gauge and its arc.
                .overlay(alignment: .top) {
                    UVIndexCategoryLabel(uvIndex: uvIndex)
                        .alignmentGuide(.top) { $0[.bottom] + 2 }
                }
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
/// Crown has turned to on a pill like the daylight ring's current hour's,
/// inside a border like the daylight ring's edge; the arc in the UV index's
/// colors from the gauge's start to its end; and on it, at the index, a sun
/// outlined like the daylight ring's by night. Below the arc's ends its edge
/// and the border fade away.
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
            days(radius: labelRadius, count: dayCount)
                .foregroundStyle(.primary)

            if !dayNumbers.isEmpty {
                pill(radius: labelRadius, angle: pillAngle)
                    .foregroundStyle(.white)

                // Dark wherever the pill is under them, as it passes from day
                // to day.
                days(radius: labelRadius, count: dayCount)
                    .foregroundStyle(.black)
                    .mask {
                        pill(radius: labelRadius, angle: pillAngle)
                    }
            }

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
            // bottom to how high the index is.
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

    /// With how high it is: the label above the date is hidden from
    /// VoiceOver.
    private func accessibilityValue(for uvIndex: Int?) -> String {
        guard let uvIndex else { return "" }
        return "\(uvIndex), \(UVIndex.ExposureCategory(index: uvIndex).displayName)"
    }
}

/// How high the index is, just above the date.
private struct UVIndexCategoryLabel: View {
    /// Nil until the weather comes in.
    let uvIndex: Int?

    var body: some View {
        ZStack {
            if let uvIndex {
                let category = UVIndex.ExposureCategory(index: uvIndex)
                Text(category.displayName)
                    .id(category)
                    .transition(.blurReplace)
            }
        }
        // As the date's under it.
        .font(.subheadline)
        .foregroundStyle(.primary)
        .blendMode(.plusLighter)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
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
            uvIndex: uvIndex
        )
    }
    let weather = CityWeather(
        current: CityWeather.Conditions(
            temperature: Measurement(value: 22, unit: .celsius),
            condition: .clear,
            isDaylight: true
        ),
        wind: CityWeather.Wind(
            direction: 200,
            speed: Measurement(value: 18, unit: .kilometersPerHour),
            gust: Measurement(value: 29, unit: .kilometersPerHour)
        ),
        uvIndex: 3,
        hours: [:],
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
