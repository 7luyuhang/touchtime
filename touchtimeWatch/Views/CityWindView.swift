//
//  CityWindView.swift
//  touchtimeWatch
//

import CoreLocation
import SwiftUI
import WeatherKit

/// The wind over the city now on Sun Position's compass, north up: its speed
/// on a glass disc in the middle, the way it comes from curved over the glass
/// and its gusts under it, and on the track a ring on the side it comes from
/// and an arrow on the side it blows to. On the watch's own clock, tapping the
/// glass goes live: the wind where the watch is, on a dial that turns with
/// the watch like a compass. Elsewhere, tapping it says so.
struct CityWindView: View {
    /// The glass's tint and the ring's and arrow's color while live, as in
    /// Sun Position.
    private static let liveColor = Color.yellow

    let date: Date
    let timeZone: TimeZone
    /// The iPhone app's wind speed unit.
    let windSpeedUnit: WindSpeedUnit
    /// Whether tapping the glass goes live. Only the watch's own clock does,
    /// as the live wind is where the watch is rather than the city's.
    let canGoLive: Bool
    /// Whether the view is live, which tapping the glass turns on and off.
    @Binding var isLive: Bool

    @Environment(WatchWeatherStore.self) private var weatherStore
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsWindCompassAlert = false
    /// Where the wind comes from, in degrees past north, counting whole turns
    /// so the ring and arrow always turn the shorter way around.
    @State private var displayedDirection: Double?
    /// Made the first time the view goes live.
    @State private var compass: LiveCompass?
    /// How far the dial is turned against the watch's heading, counting whole
    /// turns like `displayedDirection`. A whole number of turns with north up.
    @State private var displayedHeading: Double = 0
    @State private var flippedLabels = CompassDial.flippedLabels(atHeading: 0)

    /// Degrees clockwise from north that the top of the watch faces, while live.
    private var heading: Double? {
        isLive ? compass?.heading : nil
    }

    /// Where the watch is, while live, once it knows.
    private var liveLocation: CLLocation? {
        isLive ? compass?.location : nil
    }

    /// Live, the wind where the watch is once it's in, and otherwise the
    /// city's.
    private var wind: CityWeather.Wind? {
        let liveWind = liveLocation == nil ? nil : weatherStore.liveWind?.wind
        return liveWind ?? weatherStore.weather[timeZone.identifier]?.wind
    }

    var body: some View {
        let wind = wind
        let isLoading = wind == nil && !weatherStore.unavailableTimeZones.contains(timeZone.identifier)
        let direction = displayedDirection ?? wind?.direction

        GeometryReader { geometry in
            let layout = CompassDialLayout(
                diameter: max(0, min(geometry.size.width - 16, geometry.size.height - 12))
            )

            ZStack {
                ZStack {
                    CompassDial(layout: layout, heading: displayedHeading, flippedLabels: flippedLabels)

                    if let direction {
                        Group {
                            WindMarks(
                                // Around the screen, with the dial turned.
                                direction: direction - displayedHeading,
                                color: isLive ? Self.liveColor : .white,
                                layout: layout
                            )
                            WindDirectionLabel(direction: direction, layout: layout)
                        }
                        .animation(.smooth, value: displayedDirection)
                        .transition(.blurReplace)
                    }

                    if let gust = wind?.gust {
                        let gusts = String(localized: "Gusts: \(windSpeedUnit.number(gust))")
                        WindCurvedLabel(text: gusts, isAtBottom: true, layout: layout)
                            .id(gusts)
                            .transition(.blurReplace)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Wind")
                .accessibilityValue(wind.map { accessibilityValue(for: $0) } ?? "")

                glass(layout: layout, speed: wind?.speed, isLoading: isLoading)
            }
            .frame(width: layout.diameter, height: layout.diameter)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        // The circle's narrow top fits between the toolbar controls.
        .padding(.top, -24)
        .animation(.smooth, value: wind)
        .onChange(of: wind?.direction, initial: true) { oldDirection, newDirection in
            guard let newDirection else { return }
            // At most half a turn either way.
            let current = displayedDirection ?? oldDirection ?? newDirection
            displayedDirection = current + (newDirection - current).remainder(dividingBy: 360)
        }
        .onChange(of: heading) { _, heading in
            withAnimation(.smooth) {
                if let heading {
                    displayedHeading += (heading - displayedHeading).remainder(dividingBy: 360)
                    flippedLabels = CompassDial.flippedLabels(atHeading: displayedHeading, from: flippedLabels)
                } else {
                    // Back to north up by the nearer way.
                    displayedHeading = (displayedHeading / 360).rounded() * 360
                    flippedLabels = CompassDial.flippedLabels(atHeading: displayedHeading)
                }
            }
        }
        .onChange(of: isLive) { _, isLive in
            if isLive {
                startCompass()
            } else {
                compass?.stop()
            }
        }
        // Only while the watch is raised and the view is on screen.
        .onChange(of: scenePhase) { _, phase in
            guard isLive else { return }
            if phase == .active {
                startCompass()
            } else {
                compass?.stop()
            }
        }
        .onAppear {
            if isLive {
                startCompass()
            }
        }
        .onDisappear {
            compass?.stop()
        }
        // Every quarter hour, in case the weather has gone stale.
        .onChange(of: Int(date.timeIntervalSinceReferenceDate / 900), initial: true) {
            weatherStore.update(for: timeZone)
        }
        // Live, the wind where the watch is as soon as it knows, and each
        // minute after in case it's gone stale or the watch has moved.
        .onChange(of: liveLocation) {
            updateLiveWind()
        }
        .onChange(of: date) {
            updateLiveWind()
        }
        // Untitled. Verbatim, so the string catalog doesn't gain an empty key
        .alert(Text(verbatim: ""), isPresented: $showsWindCompassAlert, actions: {}) {
            Text("Wind Compass is only available for Local.")
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: showsWindCompassAlert) { _, showsAlert in showsAlert }
    }

    /// The glass in the middle, with the speed on it, which turns the live
    /// compass on and off, tinted while it's on.
    private func glass(layout: CompassDialLayout, speed: Measurement<UnitSpeed>?, isLoading: Bool) -> some View {
        let tint: Color? = isLive ? Self.liveColor : nil
        let traits: AccessibilityTraits = isLive ? [.isButton, .isSelected] : .isButton

        return WindSpeedLabel(speed: speed, isLoading: isLoading, unit: windSpeedUnit)
            // White would wash out on the tint.
            .foregroundStyle(isLive ? .black : .white)
            .frame(width: layout.glassDiameter * 0.8)
            .frame(width: layout.glassDiameter, height: layout.glassDiameter)
            .glassEffect(.clear.tint(tint).interactive(), in: .circle)
            .contentShape(.circle)
            .onTapGesture(perform: tapGlass)
            .sensoryFeedback(.start, trigger: isLive) { _, isLive in isLive }
            .accessibilityElement()
            .accessibilityLabel("Wind Compass")
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
            showsWindCompassAlert = true
        }
    }

    private func startCompass() {
        if compass == nil {
            compass = LiveCompass()
        }
        compass?.start()
    }

    private func updateLiveWind() {
        if let liveLocation {
            weatherStore.updateLiveWind(at: liveLocation)
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
        let formattedSpeed = wind.speed.converted(to: windSpeedUnit.unit).formatted(speed)
        let formattedDirection = Measurement(value: wind.direction, unit: UnitAngle.degrees).formatted(degrees)
        guard let gust = wind.gust else {
            return String(format: String(localized: "%@ from %@", locale: locale), formattedSpeed, formattedDirection)
        }
        return String(
            format: String(localized: "%@ from %@, gusts %@", locale: locale),
            formattedSpeed,
            formattedDirection,
            gust.converted(to: windSpeedUnit.unit).formatted(speed)
        )
    }
}

/// The wind's measurements on the dial.
private extension CompassDialLayout {
    /// The glass in the middle, with the speed on it.
    var glassDiameter: CGFloat { diameter * 0.3 }
    /// Through the middle of the labels over and under the glass, halfway from
    /// it to the track.
    var glassLabelRadius: CGFloat { (glassDiameter / 2 + trackInnerRadius) / 2 }
    var ringDiameter: CGFloat { trackWidth * 0.68 }
    /// From the arrow's point to its back corners: most of the way across the
    /// track, which makes it look as big as the ring, being slimmer.
    var arrowLength: CGFloat { trackWidth * 0.8 }
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
    /// The arrow, whose glyph fills its frame from its point at the top to its
    /// back corners at the bottom.
    private static let arrowSymbol = "location.north.fill"
    /// How far the notch between the arrow's back corners reaches in toward
    /// its point, as a share of its length.
    private static let arrowNotchShare: CGFloat = 0.29

    /// Where the wind comes from, in degrees clockwise from the top of the
    /// screen.
    var direction: Double
    let color: Color
    let layout: CompassDialLayout

    var animatableData: Double {
        get { direction }
        set { direction = newValue }
    }

    var body: some View {
        let arrow = Image(systemName: Self.arrowSymbol)
            .resizable()
            .scaledToFit()
            .frame(width: layout.arrowLength, height: layout.arrowLength)
            .rotationEffect(.degrees(direction + 180))

        ZStack {
            // From under the ring's line and the end of the arrow's notch,
            // leaving no seam.
            tail(
                atDegrees: direction,
                from: layout.trackRadius - layout.ringDiameter / 2 + Self.ringLineWidth / 2
            )
            tail(
                atDegrees: direction + 180,
                from: layout.trackRadius - layout.arrowLength * (0.5 - Self.arrowNotchShare) + 1
            )

            Circle()
                .strokeBorder(color, lineWidth: Self.ringLineWidth)
                .frame(width: layout.ringDiameter, height: layout.ringDiameter)
                .position(layout.point(atDegrees: direction, radius: layout.trackRadius))

            arrow
                .foregroundStyle(color)
                .background {
                    arrow
                        .foregroundStyle(.black.opacity(0.05))
                        .blur(radius: 5)
                        .offset(y: 2.5)
                        .blendMode(.plusDarker)
                }
                .position(layout.point(atDegrees: direction + 180, radius: layout.trackRadius))
        }
        .frame(width: layout.diameter, height: layout.diameter)
    }

    /// A line along the radius at `degrees`, from `radius` in to where it fades
    /// away.
    private func tail(atDegrees degrees: Double, from radius: CGFloat) -> some View {
        let length = max(0, radius - layout.tailEndRadius)

        return Rectangle()
            .fill(LinearGradient(colors: [color.opacity(0), color], startPoint: .leading, endPoint: .trailing))
            .frame(width: length, height: Self.tailWidth)
            // Its opaque end outward.
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

/// The wind's speed over `unit` in the middle of the glass.
private struct WindSpeedLabel: View {
    private static let numberFont = Font.system(.headline, design: .rounded, weight: .medium).monospacedDigit()

    let speed: Measurement<UnitSpeed>?
    let isLoading: Bool
    let unit: WindSpeedUnit

    var body: some View {
        ZStack {
            if let speed {
                // Into the room under the digits, which have no descenders.
                VStack(spacing: -3) {
                    Text(unit.number(speed))
                        .font(Self.numberFont)
                        .contentTransition(.numericText())
                    Text(unit.localizedSymbol)
                        .font(.footnote.weight(.medium))
                }
                // Raised to look centered: the lines leave more room over the
                // digits than under the unit.
                .offset(y: -1.5)
                .transition(.blurReplace)
            } else if isLoading {
                ProgressView()
                    .transition(.blurReplace)
            } else {
                Text(verbatim: "--")
                    .font(Self.numberFont)
                    .transition(.blurReplace)
            }
        }
        .lineLimit(1)
        // The speed at the largest text sizes on the smallest watch.
        .minimumScaleFactor(0.4)
    }
}

private extension WindSpeedUnit {
    /// A speed in this unit to the nearest whole number, without the unit.
    func number(_ speed: Measurement<UnitSpeed>) -> String {
        speed.converted(to: unit).value.formatted(.number.precision(.fractionLength(0)))
    }
}

#Preview {
    let date = Date.now
    let weather = CityWeather(
        current: CityWeather.Conditions(
            temperature: Measurement(value: 14, unit: .celsius),
            condition: .breezy,
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
        hours: [:],
        hourlyUVIndexes: [:],
        hourlyPressures: [:],
        days: [],
        fetchDate: date
    )

    NavigationStack {
        CityWindView(
            date: date,
            timeZone: .current,
            windSpeedUnit: .kilometersPerHour,
            canGoLive: true,
            isLive: .constant(false)
        )
            .ignoresSafeArea(edges: .bottom)
            .containerBackground(for: .navigation) {
                CitySkyBackground(date: date, timeZone: .current)
            }
    }
    .environment(WatchWeatherStore(weather: [TimeZone.current.identifier: weather]))
}
