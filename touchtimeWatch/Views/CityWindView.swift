//
//  CityWindView.swift
//  touchtimeWatch
//

import SwiftUI
import WeatherKit

/// The wind over the city now on Sun Position's compass, north up: its speed
/// on a glass disc in the middle, the way it comes from curved over the glass
/// and the speed's unit under it, and on the track a ring on the side it comes
/// from and an arrow on the side it blows to.
struct CityWindView: View {
    let date: Date
    let timeZone: TimeZone
    /// The iPhone app's wind speed unit.
    let windSpeedUnit: WindSpeedUnit

    @Environment(WatchWeatherStore.self) private var weatherStore
    @Environment(\.locale) private var locale
    /// Where the wind comes from, in degrees past north, counting whole turns
    /// so the ring and arrow always turn the shorter way around.
    @State private var displayedDirection: Double?

    var body: some View {
        let weather = weatherStore.weather[timeZone.identifier]
        let isLoading = weather == nil && !weatherStore.unavailableTimeZones.contains(timeZone.identifier)
        let direction = displayedDirection ?? weather?.wind.direction

        GeometryReader { geometry in
            let layout = CompassDialLayout(
                diameter: max(0, min(geometry.size.width - 16, geometry.size.height - 12))
            )

            ZStack {
                CompassDial(layout: layout, heading: 0, flippedLabels: CompassDial.flippedLabels(atHeading: 0))

                if let direction {
                    Group {
                        WindMarks(direction: direction, layout: layout)
                        WindDirectionLabel(direction: direction, layout: layout)
                    }
                    .animation(.smooth, value: displayedDirection)
                    .transition(.blurReplace)
                }

                if weather != nil {
                    WindCurvedLabel(text: windSpeedUnit.localizedSymbol, isAtBottom: true, layout: layout)
                        .transition(.blurReplace)
                }

                WindSpeedLabel(speed: weather?.wind.speed, isLoading: isLoading, unit: windSpeedUnit)
                    .frame(width: layout.glassDiameter * 0.8)
                    .frame(width: layout.glassDiameter, height: layout.glassDiameter)
                    .glassEffect(.clear, in: .circle)
            }
            .frame(width: layout.diameter, height: layout.diameter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Wind")
            .accessibilityValue(weather.map { accessibilityValue(for: $0.wind) } ?? "")
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        // The circle's narrow top fits between the toolbar controls.
        .padding(.top, -24)
        .animation(.smooth, value: weather?.fetchDate)
        .onChange(of: weather?.wind.direction, initial: true) { oldDirection, newDirection in
            guard let newDirection else { return }
            // At most half a turn either way.
            let current = displayedDirection ?? oldDirection ?? newDirection
            displayedDirection = current + (newDirection - current).remainder(dividingBy: 360)
        }
        // Every quarter hour, in case the weather has gone stale.
        .onChange(of: Int(date.timeIntervalSinceReferenceDate / 900), initial: true) {
            weatherStore.update(for: timeZone)
        }
    }

    private func accessibilityValue(for wind: CityWeather.Wind) -> String {
        let speed = Measurement<UnitSpeed>.FormatStyle(
            width: .wide,
            locale: locale,
            usage: .asProvided,
            numberFormatStyle: .number.precision(.fractionLength(0))
        )
        let degrees = Measurement<UnitAngle>.FormatStyle(
            width: .narrow,
            locale: locale,
            usage: .asProvided,
            numberFormatStyle: .number.precision(.fractionLength(0))
        )
        return String(
            format: String(localized: "%@ from %@", locale: locale),
            wind.speed.converted(to: windSpeedUnit.unit).formatted(speed),
            Measurement(value: wind.direction, unit: UnitAngle.degrees).formatted(degrees)
        )
    }
}

/// The wind's measurements on the dial.
private extension CompassDialLayout {
    /// The arrow's corners' radius, as a share of the arrow's.
    static let arrowCornerShare: CGFloat = 0.2

    /// The glass in the middle, with the speed on it.
    var glassDiameter: CGFloat { diameter * 0.3 }
    /// Through the middle of the labels over and under the glass, halfway from
    /// it to the track.
    var glassLabelRadius: CGFloat { (glassDiameter / 2 + trackInnerRadius) / 2 }
    var ringDiameter: CGFloat { trackWidth * 0.68 }
    /// From the arrow's middle to where its sides would meet, for the arrow to
    /// be as wide as the ring, which makes it look as big, being solid.
    var arrowRadius: CGFloat {
        // A 60° corner's circle sits twice its radius in from the corner, and
        // the base's corners √3/2 of the arrow's radius out to the sides.
        let halfWidth = sqrt(3) / 2 * (1 - 2 * Self.arrowCornerShare) + Self.arrowCornerShare
        return ringDiameter / 2 / halfWidth
    }
    var arrowCornerRadius: CGFloat { arrowRadius * Self.arrowCornerShare }
    /// Through the arrow's middle, set back from the track's so its rounded
    /// point and its base sit as far inside the track's lines.
    var arrowCenterRadius: CGFloat {
        // A 60° corner's circle sits twice its radius in from the point, and
        // the base half the arrow's radius in from its middle.
        let point = arrowRadius - arrowCornerRadius
        let base = arrowRadius / 2
        return trackRadius - (point - base) / 2
    }
    /// Where the lines in from the ring and the arrow fade away: just clear of
    /// the labels, even of the baseline of the unit's letters, turned outward
    /// under the glass.
    var tailEndRadius: CGFloat { glassLabelRadius + 5 }
}

/// On the track, a ring on the side the wind comes from, and an arrow on the
/// side it blows to, pointing the way it blows: outlined and solid like the
/// sun on its track by night and by day. From each, a line runs in toward the
/// middle, fading away.
private struct WindMarks: View, Animatable {
    /// As wide as the sun's outline.
    private static let ringLineWidth: CGFloat = 2
    /// As wide as the dial's ticks.
    private static let tailWidth: CGFloat = 1.5

    /// Where the wind comes from, in degrees clockwise from north.
    var direction: Double
    let layout: CompassDialLayout

    var animatableData: Double {
        get { direction }
        set { direction = newValue }
    }

    var body: some View {
        let arrow = RoundedTriangle(cornerRadius: layout.arrowCornerRadius).rotation(.degrees(direction + 180))

        ZStack {
            // From under the ring's line and the arrow's base, leaving no seam.
            tail(
                atDegrees: direction,
                from: layout.trackRadius - layout.ringDiameter / 2 + Self.ringLineWidth / 2
            )
            tail(atDegrees: direction + 180, from: layout.arrowCenterRadius - layout.arrowRadius / 2 + 1)

            Circle()
                .strokeBorder(.white, lineWidth: Self.ringLineWidth)
                .frame(width: layout.ringDiameter, height: layout.ringDiameter)
                .position(layout.point(atDegrees: direction, radius: layout.trackRadius))

            arrow
                .fill(.white)
                .background {
                    arrow
                        .fill(.black.opacity(0.05))
                        .blur(radius: 5)
                        .offset(y: 2.5)
                        .blendMode(.plusDarker)
                }
                .frame(width: layout.arrowRadius * 2, height: layout.arrowRadius * 2)
                .position(layout.point(atDegrees: direction + 180, radius: layout.arrowCenterRadius))
        }
        .frame(width: layout.diameter, height: layout.diameter)
    }

    /// A line along the radius at `degrees`, from `radius` in to where it fades
    /// away.
    private func tail(atDegrees degrees: Double, from radius: CGFloat) -> some View {
        let length = max(0, radius - layout.tailEndRadius)

        return Rectangle()
            .fill(LinearGradient(colors: [.white.opacity(0), .white], startPoint: .leading, endPoint: .trailing))
            .frame(width: length, height: Self.tailWidth)
            // Its white end outward.
            .rotationEffect(.degrees(degrees - 90))
            .position(layout.point(atDegrees: degrees, radius: radius - length / 2))
    }
}

/// Text curved over the glass, or under it turned to read left to right.
private struct WindCurvedLabel: View {
    private static let font = Font.system(.footnote, weight: .medium).monospacedDigit()
    private static let maxAngle = Angle.degrees(120)

    let text: String
    let isAtBottom: Bool
    let layout: CompassDialLayout

    var body: some View {
        CurvedText(
            text: text,
            font: Self.font,
            radius: layout.glassLabelRadius,
            maxAngle: Self.maxAngle,
            isAtBottom: isAtBottom
        )
        .frame(width: layout.diameter, height: layout.diameter)
        // Any larger and it runs into the glass or the track.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// Where the wind comes from, in degrees and on the compass, curved over the
/// glass. The degrees count along as the ring and arrow turn.
private struct WindDirectionLabel: View, Animatable {
    /// Degrees clockwise from north.
    var direction: Double
    let layout: CompassDialLayout

    var animatableData: Double {
        get { direction }
        set { direction = newValue }
    }

    var body: some View {
        WindCurvedLabel(text: CompassDial.bearing(direction), isAtBottom: false, layout: layout)
    }
}

/// The wind's speed in `unit`, alone in the middle of the glass.
private struct WindSpeedLabel: View {
    let speed: Measurement<UnitSpeed>?
    let isLoading: Bool
    let unit: WindSpeedUnit

    var body: some View {
        ZStack {
            if let speed {
                Text(speed.converted(to: unit.unit).value.formatted(.number.precision(.fractionLength(0))))
                    .contentTransition(.numericText())
                    .transition(.blurReplace)
            } else if isLoading {
                ProgressView()
                    .transition(.blurReplace)
            } else {
                Text(verbatim: "--")
                    .transition(.blurReplace)
            }
        }
        .font(.system(.title3, design: .rounded, weight: .medium).monospacedDigit())
        .foregroundStyle(.white)
        .lineLimit(1)
        // The speed at the largest text sizes on the smallest watch.
        .minimumScaleFactor(0.4)
    }
}

#Preview {
    let date = Date.now
    let weather = CityWeather(
        current: CityWeather.Conditions(
            temperature: Measurement(value: 14, unit: .celsius),
            condition: .breezy,
            isDaylight: true
        ),
        wind: CityWeather.Wind(direction: 200, speed: Measurement(value: 18, unit: .kilometersPerHour)),
        hours: [:],
        days: [],
        fetchDate: date
    )

    NavigationStack {
        CityWindView(date: date, timeZone: .current, windSpeedUnit: .kilometersPerHour)
            .ignoresSafeArea(edges: .bottom)
            .containerBackground(for: .navigation) {
                CitySkyBackground(date: date, timeZone: .current)
            }
    }
    .environment(WatchWeatherStore(weather: [TimeZone.current.identifier: weather]))
}
