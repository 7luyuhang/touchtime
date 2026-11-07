//
//  CityWeatherView.swift
//  touchtimeWatch
//

import SwiftUI
import WeatherKit

/// The city's temperature and conditions now, inside a ring of the next 12
/// hours' conditions, laid out like the daylight ring with its hours showing:
/// now at the top right, and each hour after it clockwise.
struct CityWeatherView: View {
    let date: Date
    let timeZone: TimeZone

    @Environment(WatchWeatherStore.self) private var weatherStore

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

        GeometryReader { geometry in
            // As big as the daylight ring with its hours showing.
            let diameter = max(0, min(geometry.size.width - 16, geometry.size.height) - WeatherRingHours.bandWidth * 2)
            // Narrower than the daylight ring, leaving the middle more room.
            let ringWidth = diameter * 0.17
            let holeDiameter = diameter - ringWidth * 2

            ZStack {
                WeatherRingHours(
                    ringDiameter: diameter,
                    hours: hours,
                    lineWidth: Self.lineWidth,
                    lineOpacity: Self.lineOpacity
                )
                .accessibilityHidden(true)

                WeatherRingConditions(
                    diameter: diameter,
                    ringWidth: ringWidth,
                    symbols: (0..<WeatherRing.hourCount).map { hoursAhead in
                        conditions(hoursAhead: hoursAhead, in: weather).map { $0.condition.icon(isDaylight: $0.isDaylight) }
                    },
                    lineWidth: Self.lineWidth,
                    lineOpacity: Self.lineOpacity
                )
                .accessibilityHidden(true)

                WeatherRingCenter(conditions: weather?.current, isLoading: isLoading)
                    .frame(width: holeDiameter * 0.80)
                    .frame(width: holeDiameter, height: holeDiameter)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        // The circle's narrow top fits between the toolbar controls, as the
        // daylight ring's does.
        .padding(.top, -20)
        .padding(.bottom, 8)
        .animation(.smooth, value: weather?.fetchDate)
        // Every quarter hour, in case the weather has gone stale.
        .onChange(of: Int(date.timeIntervalSinceReferenceDate / 900), initial: true) {
            weatherStore.update(for: timeZone)
        }
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
}

/// Where the ring's hours go around it.
private enum WeatherRing {
    static let hourCount = 12

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

    /// Clockwise from the top: now a twelfth of the way around, at the top
    /// right, and each hour after it a twelfth further.
    static func angle(hoursAhead: Int) -> Angle {
        .degrees(Double(hoursAhead + 1) * 360 / Double(hourCount))
    }

    /// Across the ring's bottom half, an hour turns over to read left to right
    /// rather than upside down, as on the daylight ring.
    static func isTurnedOver(_ hoursAhead: Int) -> Bool {
        let degrees = angle(hoursAhead: hoursAhead).degrees.truncatingRemainder(dividingBy: 360)
        return degrees > 90 && degrees < 270
    }
}

/// Each hour around the outside of the ring, inside a line like its edges,
/// with now on a pill like the daylight ring's current hour.
private struct WeatherRingHours: View {
    /// How far past the ring the hours and their line reach.
    static let bandWidth: CGFloat = 16
    /// The pill's room around "Now", both ends together.
    private static let pillPadding: CGFloat = 11

    let ringDiameter: CGFloat
    /// The city's clock hour for each of the ring's hours, from now.
    let hours: [Int]
    let lineWidth: CGFloat
    let lineOpacity: Double

    @AppStorage(WatchTimeFormat.use24HourFormatKey) private var use24HourFormat = WatchTimeFormat.systemUses24HourFormat

    var body: some View {
        let diameter = ringDiameter + Self.bandWidth * 2
        // Halfway between the ring's edge and the line around the hours.
        let radius = (ringDiameter + Self.bandWidth - lineWidth) / 2

        ZStack {
            Circle()
                .strokeBorder(.white.opacity(lineOpacity), lineWidth: lineWidth)
                .blendMode(.plusLighter)
                .frame(width: diameter, height: diameter)

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
                            isTurnedOver: WeatherRing.isTurnedOver(0)
                        )
                        .fill(.white)
                    }
                }
                .compositingGroup()
                .placed(hoursAhead: 0, radius: radius, turnsAlong: true)

            ForEach(1..<hours.count, id: \.self) { hoursAhead in
                Text(WatchTimeFormat.dialHour(hours[hoursAhead], use24HourFormat: use24HourFormat))
                    .placed(hoursAhead: hoursAhead, radius: radius, turnsAlong: true)
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(.primary)
    }
}

/// The ring's edges, and each hour's conditions between them.
private struct WeatherRingConditions: View {
    let diameter: CGFloat
    let ringWidth: CGFloat
    /// Each hour's symbol from now, or nil until its weather comes in.
    let symbols: [String?]
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

            ForEach(symbols.indices, id: \.self) { hoursAhead in
                ZStack {
                    // Sized even while empty, so an arriving symbol blurs in
                    // where it sits rather than sliding from the empty
                    // stack's center.
                    Color.clear
                    if let symbol = symbols[hoursAhead] {
                        Image(systemName: symbol)
                            .contentTransition(.symbolEffect(.replace))
                            .transition(.blurReplace)
                    }
                }
                .frame(width: ringWidth, height: ringWidth)
                .placed(hoursAhead: hoursAhead, radius: radius, turnsAlong: false)
            }
            .font(.system(size: ringWidth * 0.5))
            .symbolRenderingMode(.multicolor)
            .foregroundStyle(.primary)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// The temperature over the conditions now, in the middle of the ring.
private struct WeatherRingCenter: View {
    let conditions: CityWeather.Conditions?
    let isLoading: Bool

    var body: some View {
        ZStack {
            if let conditions {
                let name = conditions.condition.displayName

                VStack(spacing: 0) {
                    Text(Self.temperature(conditions.temperature))
                        .font(.system(.title2, design: .rounded, weight: .medium).monospacedDigit())
                        .contentTransition(.numericText())

                    ZStack {
                        MarqueeText(name)
                            .id(name)
                            .transition(.blurReplace)
                    }
                    .font(.footnote.weight(.medium))
                    // Lower in the ring than the temperature, where it's narrower.
                    .padding(.horizontal, 4)
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

    /// In the watch's preferred unit, without its letter, like the iPhone app's.
    private static func temperature(_ temperature: Measurement<UnitTemperature>) -> String {
        let value = temperature.converted(to: UnitTemperature(forLocale: .autoupdatingCurrent, usage: .weather)).value
        guard value.isFinite else { return "--°" }
        return "\(Int(value.rounded()))°"
    }
}

private extension View {
    /// At an hour around a circle of `radius`, turned along it or upright.
    func placed(hoursAhead: Int, radius: CGFloat, turnsAlong: Bool) -> some View {
        let angle = WeatherRing.angle(hoursAhead: hoursAhead)
        let turn = WeatherRing.isTurnedOver(hoursAhead) ? angle - .degrees(180) : angle
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
    let weather = CityWeather(current: hours[currentHour]!, hours: hours, fetchDate: date)

    NavigationStack {
        CityWeatherView(date: date, timeZone: .current)
            .ignoresSafeArea(edges: .bottom)
            .containerBackground(for: .navigation) {
                CitySkyBackground(date: date, timeZone: .current)
            }
    }
    .environment(WatchWeatherStore(weather: [TimeZone.current.identifier: weather]))
}
