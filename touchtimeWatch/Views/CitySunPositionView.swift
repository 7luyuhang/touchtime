//
//  CitySunPositionView.swift
//  touchtimeWatch
//

import CoreLocation
import SwiftUI

/// The sun's direction over the city on a compass, north up, and the shadow
/// it casts from a glass triangle in the middle: away from the sun, longer as
/// the sun sinks, and gone once it sets. On the watch's own clock, tapping the
/// triangle goes live: the sun where the watch is, on a dial that turns with
/// the watch like a compass. Elsewhere, tapping it says so.
struct CitySunPositionView: View {
    /// The triangle's tint and the sun's color while live.
    private static let liveColor = Color.yellow

    let date: Date
    let timeZone: TimeZone
    let dateLabel: String
    /// While the Digital Crown shows another time, the time shows under the
    /// triangle.
    let isAdjusting: Bool
    /// Whether tapping the triangle goes live. Only the watch's own clock
    /// does, as the live sun is where the watch is rather than the city's.
    let canGoLive: Bool
    /// Whether the view is live, which tapping the triangle turns on and off.
    @Binding var isLive: Bool

    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsSunCompassAlert = false
    /// The sun's azimuth, in degrees past north, counting whole turns so the
    /// sun and shadow always animate the shorter way around.
    @State private var displayedAzimuth: Double?
    /// Made the first time the view goes live.
    @State private var compass: LiveCompass?
    /// How far the dial is turned against the watch's heading, counting whole
    /// turns like `displayedAzimuth`. A whole number of turns with north up.
    @State private var displayedHeading: Double = 0
    @State private var flippedLabels = CompassDial.flippedLabels(atHeading: 0)
    /// Live, which half the sun is in, kept until it's well into the other
    /// half so a wavering heading can't flip the label back and forth.
    @State private var isLiveSunInTopHalf = false

    /// Degrees clockwise from north that the top of the watch faces, while live.
    private var heading: Double? {
        isLive ? compass?.heading : nil
    }

    private var sunPosition: SolarCalculator.Position {
        // Live, from where the watch is once it knows.
        let coordinate = (isLive ? compass?.location?.coordinate : nil)
            .map { (latitude: $0.latitude, longitude: $0.longitude) }
            ?? TimeZoneCoordinates.getCoordinate(for: timeZone.identifier)
            ?? (latitude: 51.5074, longitude: -0.1278)
        return SolarCalculator.position(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            date: date
        )
    }

    var body: some View {
        let position = sunPosition
        let azimuth = displayedAzimuth ?? position.azimuth
        // Where the sun is around the screen, with the dial turned.
        let screenAzimuth = azimuth - displayedHeading
        // From −1 at the bottom of the screen to 1 at the top.
        let sunHeight = cos(screenAzimuth * .pi / 180)

        GeometryReader { geometry in
            let layout = CompassDialLayout(
                diameter: max(0, min(geometry.size.width - 16, geometry.size.height - 12))
            )

            ZStack {
                ZStack {
                    CompassDial(
                        layout: layout,
                        heading: displayedHeading,
                        flippedLabels: flippedLabels
                    )

                    SunOrbit(
                        azimuth: screenAzimuth,
                        isSunFilled: position.altitude > CompassDialLayout.civilTwilightAltitude,
                        isLive: isLive,
                        liveColor: Self.liveColor,
                        layout: layout
                    )
                    .animation(.smooth, value: displayedAzimuth)

                    SunPositionLabel(
                        // Live, it's always now: the watch's heading leads
                        // instead, once it's known.
                        dateLabel: isLive ? nil : dateLabel,
                        heading: displayedHeading,
                        showsHeading: heading != nil,
                        azimuth: azimuth,
                        isSunInTopHalf: isLive ? isLiveSunInTopHalf : cos(position.azimuth * .pi / 180) > 0,
                        layout: layout
                    )
                    .animation(.smooth, value: displayedAzimuth)
                    // The compass's first heading comes in unanimated.
                    .animation(.smooth, value: heading != nil)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sun Position")
                .accessibilityValue(accessibilityValue(for: position))

                // The triangle and the time, centered together.
                VStack(spacing: 6) {
                    triangle(layout: layout, sunAzimuth: screenAzimuth, sunAltitude: position.altitude)
                        // Alone, centered on its middle and lowered a little. With
                        // the time, laid out by the triangle itself: its rounded
                        // point is a corner radius below its frame's top, and its
                        // base halfway from the middle to the bottom.
                        .padding(.top, isAdjusting ? -layout.triangleCornerRadius : 0)
                        .padding(.bottom, isAdjusting ? -layout.triangleRadius / 2 : 0)
                        .offset(y: isAdjusting ? 0 : layout.triangleDrop)

                    if isAdjusting {
                        ClockTimeText(date: date, timeZone: timeZone, size: .title)
                            .foregroundStyle(.white)
                            .transition(.blurReplace)
                    }
                }
            }
            .frame(width: layout.diameter, height: layout.diameter)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        // The circle's narrow top fits between the toolbar controls.
        .padding(.top, -24)
        .onChange(of: position.azimuth, initial: true) { oldAzimuth, newAzimuth in
            // At most half a turn either way, even when the time jumps by hours.
            let turn = (newAzimuth - oldAzimuth + 540).truncatingRemainder(dividingBy: 360) - 180
            displayedAzimuth = (displayedAzimuth ?? oldAzimuth) + turn
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
        .onChange(of: sunHeight) { _, height in
            if abs(height) > 0.25 {
                isLiveSunInTopHalf = height > 0
            }
        }
        .onChange(of: isLive) { _, isLive in
            if isLive {
                isLiveSunInTopHalf = sunHeight > 0
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
        // Untitled. Verbatim, so the string catalog doesn't gain an empty key
        .alert(Text(verbatim: ""), isPresented: $showsSunCompassAlert, actions: {}) {
            Text("Sun Compass is only available for Local.")
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: showsSunCompassAlert) { _, showsAlert in showsAlert }
    }

    /// The glass triangle and its shadow, which turn the live compass on and
    /// off, tinted while it's on.
    private func triangle(layout: CompassDialLayout, sunAzimuth: Double, sunAltitude: Double) -> some View {
        let shape = RoundedTriangle(cornerRadius: layout.triangleCornerRadius)
        let tint: Color? = isLive ? Self.liveColor : nil
        let traits: AccessibilityTraits = isLive ? [.isButton, .isSelected] : .isButton

        return Color.clear
            .frame(width: layout.triangleFrame.width, height: layout.triangleFrame.height)
            .glassEffect(.clear.tint(tint).interactive(), in: shape)
            .background {
                TriangleShadow(azimuth: sunAzimuth, altitude: sunAltitude, layout: layout)
                    .animation(.smooth, value: displayedAzimuth)
                    .allowsHitTesting(false)
            }
            .contentShape(shape)
            .onTapGesture(perform: tapTriangle)
            .sensoryFeedback(.start, trigger: isLive) { _, isLive in isLive }
            .accessibilityElement()
            .accessibilityLabel("Sun Compass")
            .accessibilityAddTraits(traits)
            .accessibilityAction {
                tapTriangle()
            }
    }

    private func tapTriangle() {
        if canGoLive {
            withAnimation(.smooth) {
                isLive.toggle()
            }
        } else {
            showsSunCompassAlert = true
        }
    }

    private func startCompass() {
        if compass == nil {
            compass = LiveCompass()
        }
        compass?.start()
    }

    private func accessibilityValue(for position: SolarCalculator.Position) -> String {
        let degrees = Measurement<UnitAngle>.FormatStyle(
            width: .narrow,
            locale: locale,
            usage: .asProvided,
            numberFormatStyle: .number.precision(.fractionLength(0))
        )
        let sunPosition = String(
            format: String(localized: "Azimuth %@, altitude %@", locale: locale),
            Measurement(value: position.azimuth, unit: UnitAngle.degrees).formatted(degrees),
            Measurement(value: position.altitude, unit: UnitAngle.degrees).formatted(degrees)
        )
        return isLive ? sunPosition : "\(dateLabel), \(sunPosition)"
    }
}

/// The sun's and the triangle's measurements on the dial.
private extension CompassDialLayout {
    /// The sun's altitude at sunrise and sunset: its upper edge on the
    /// horizon, raised by refraction.
    static let horizonAltitude = -0.833
    /// The sun's altitude at civil dawn and dusk, below which the daylight
    /// ring outlines its sun.
    static let civilTwilightAltitude = -6.0

    /// How much of the sun's light reaches the ground: rising from 0 to 1 as
    /// its disc, about half a degree across, clears the horizon at sunrise,
    /// and falling back as it goes down at sunset.
    static func sunlight(atAltitude altitude: Double) -> Double {
        smoothstep(from: horizonAltitude, to: horizonAltitude + 0.53, value: altitude)
    }

    /// From the triangle's center to where its sides would meet.
    var triangleRadius: CGFloat { diameter * 0.18 }
    var triangleCornerRadius: CGFloat { diameter * 0.025 }
    /// How far below the middle the triangle sits on its own to look centered:
    /// centered on its bounds it looks low under its wide base, and on its
    /// middle a little high.
    var triangleDrop: CGFloat { diameter * 0.0105 }
    var triangleFrame: CGRect {
        CGRect(
            x: center.x - triangleRadius,
            y: center.y - triangleRadius,
            width: triangleRadius * 2,
            height: triangleRadius * 2
        )
    }
    /// The triangle's outline, clockwise from its point, around each rounded
    /// corner in 20° steps.
    var triangleOutline: [CGPoint] {
        // A 60° corner's circle sits twice its radius in from the point.
        let corners = RoundedTriangle.vertices(center: center, radius: triangleRadius - triangleCornerRadius * 2)
        return corners.indices.flatMap { index in
            stride(from: -60.0, through: 60, by: 20).map { offset in
                let angle = (Double(index) * 120 + offset) * .pi / 180
                return CGPoint(
                    x: corners[index].x + triangleCornerRadius * sin(angle),
                    y: corners[index].y - triangleCornerRadius * cos(angle)
                )
            }
        }
    }
    /// How tall the triangle stands, which sets how far its shadow falls.
    var triangleHeight: CGFloat { triangleRadius * 0.78 }
    /// The shadow's length with the sun on the horizon. Off a corner it runs a
    /// little past the inside of the sun's track, faded out by then.
    var maxShadowLength: CGFloat { max(trackInnerRadius - triangleRadius, 1) * 1.3 }
}

/// The sun on its track, as on the daylight ring: a disc while it's light out,
/// and an outline from civil dusk to dawn.
private struct SunOrbit: View, Animatable {
    /// Degrees clockwise from north.
    var azimuth: Double
    let isSunFilled: Bool
    let isLive: Bool
    /// The sun's color while live, in place of white.
    let liveColor: Color
    let layout: CompassDialLayout

    var animatableData: Double {
        get { azimuth }
        set { azimuth = newValue }
    }

    var body: some View {
        let fill: CGFloat = isSunFilled ? 1 : 0
        let disc = SunDisc(fill: fill, lineWidth: 2)

        ZStack {
            disc
                .fill(.white, style: FillStyle(eoFill: true))
                .opacity(isLive ? 0 : 1)
                .blendMode(.plusLighter)

            // Unblended, as lightening the sky washes the color out, and over
            // the white rather than in its place, as switching blend modes
            // blinks
            disc
                .fill(liveColor, style: FillStyle(eoFill: true))
                .opacity(isLive ? 1 : 0)
        }
        .background {
            // A layer of its own: plusDarker on the white disc would make it vanish.
            Circle()
                .fill(.black.opacity(0.05))
                .blur(radius: 5)
                .offset(y: 2.5)
                .blendMode(.plusDarker)
                .opacity(fill)
        }
        .animation(.smooth, value: fill)
        .frame(width: layout.trackWidth, height: layout.trackWidth)
        .position(layout.point(atDegrees: azimuth, radius: layout.trackRadius))
        .frame(width: layout.diameter, height: layout.diameter)
    }
}

/// The sun's direction, in degrees and on the compass, after the day if
/// there is one, or live, after the watch's heading once it's known, along
/// its track: across the top while the sun is in the bottom half, and across
/// the bottom while it's in the top half. The degrees count along as the sun
/// moves and the dial turns.
private struct SunPositionLabel: View, Animatable {
    private static let font = Font.system(.footnote, weight: .medium).monospacedDigit()
    /// Clear of the sun, which is always in the other half.
    private static let maxAngle = Angle.degrees(140)

    let dateLabel: String?
    /// Degrees clockwise from north that the top of the watch faces, as far
    /// as the dial has turned. Set even while hidden, so it comes in where
    /// the dial is rather than counting from a stand-in.
    var heading: Double
    let showsHeading: Bool
    /// Degrees clockwise from north.
    var azimuth: Double
    /// Where the sun is headed, rather than where it is on the way, sets the
    /// side.
    let isSunInTopHalf: Bool
    let layout: CompassDialLayout

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(heading, azimuth) }
        set {
            heading = newValue.first
            azimuth = newValue.second
        }
    }

    var body: some View {
        let lead = dateLabel ?? (showsHeading ? CompassDial.bearing(heading) : nil)
        let direction = CompassDial.bearing(azimuth)
        let text = lead.map { "\($0) · \(direction)" } ?? direction

        ZStack {
            // Two views, so the label blurs from one side to the other.
            if isSunInTopHalf {
                curvedText(text, isAtBottom: true)
            } else {
                curvedText(text, isAtBottom: false)
            }
        }
        .frame(width: layout.diameter, height: layout.diameter)
        // Any larger and it spills out of the sun's track.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func curvedText(_ text: String, isAtBottom: Bool) -> some View {
        CurvedText(
            text: text,
            font: Self.font,
            radius: layout.trackRadius,
            maxAngle: Self.maxAngle,
            isAtBottom: isAtBottom
        )
        .transition(.blurReplace)
        // Blurs into the other as the day or the heading comes and goes, too.
        .id([dateLabel == nil, showsHeading])
    }
}

/// The triangle's shadow on the ground, as if it stood `triangleHeight` tall:
/// each side facing away from the sun swept along the shadow, darkest and
/// sharpest where it leaves the triangle. Short under a high sun, long and
/// fading under a low one, and gone once the sun sets.
private struct TriangleShadow: View, Animatable {
    private static let opacity = 0.24

    /// Degrees clockwise from north.
    var azimuth: Double
    /// Degrees above the horizon.
    var altitude: Double
    let layout: CompassDialLayout

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(azimuth, altitude) }
        set {
            azimuth = newValue.first
            altitude = newValue.second
        }
    }

    private var length: CGFloat {
        // Below the horizon the shadow holds its longest length as it fades.
        let elevation = max(altitude, 0.5) * .pi / 180
        let length = layout.triangleHeight / tan(elevation)
        // Ease toward the longest, rather than stopping there, so a low sun's
        // shadow keeps changing as it nears the horizon.
        return layout.maxShadowLength * tanh(length / layout.maxShadowLength)
    }

    var body: some View {
        let center = layout.center
        let radians = azimuth * .pi / 180
        // Away from the sun, with north up.
        let away = CGVector(dx: -sin(radians), dy: cos(radians))
        let length = max(length, 0.5)
        let outline = layout.triangleOutline

        // Along each side's sweep. The longer the shadow, the nearer its end
        // fades to nothing.
        let falloff = Gradient(colors: [
            .black.opacity(Self.opacity),
            .black.opacity(Self.opacity * pow(1 - Double(length / layout.maxShadowLength), 2))
        ])

        // From the triangle's farthest reach along the shadow to the shadow's end.
        let reach = outline.map { ($0.x - center.x) * away.dx + ($0.y - center.y) * away.dy }.max() ?? 0
        let blurStart = CGPoint(x: center.x + away.dx * reach, y: center.y + away.dy * reach)
        let blurEnd = CGPoint(x: blurStart.x + away.dx * length, y: blurStart.y + away.dy * length)

        return Canvas { context, size in
            func drawSweeps(in context: inout GraphicsContext) {
                for (index, start) in outline.enumerated() {
                    let end = outline[(index + 1) % outline.count]
                    let side = hypot(end.x - start.x, end.y - start.y)
                    guard side > 0 else { continue }
                    // Outward, as the outline runs clockwise.
                    let normal = CGVector(dx: (end.y - start.y) / side, dy: (start.x - end.x) / side)
                    let facing = normal.dx * away.dx + normal.dy * away.dy
                    guard facing > 0 else { continue }

                    var sweep = Path()
                    sweep.addLines([
                        start,
                        end,
                        CGPoint(x: end.x + away.dx * length, y: end.y + away.dy * length),
                        CGPoint(x: start.x + away.dx * length, y: start.y + away.dy * length)
                    ])
                    sweep.closeSubpath()
                    // Shaded by how far the shadow has fallen from this side.
                    let depth = length * facing
                    context.fill(sweep, with: .linearGradient(
                        falloff,
                        startPoint: start,
                        endPoint: CGPoint(x: start.x + normal.dx * depth, y: start.y + normal.dy * depth)
                    ))
                }
            }

            // Crisp where the shadow leaves the triangle and softer toward its
            // end: a sharp copy and a blurred one, crossfaded along its length.
            let bounds = Path(CGRect(origin: .zero, size: size))
            for (blur, colors) in [(0.6, [Color.black, .clear]), (0.6 + length * 0.16, [Color.clear, .black])] {
                var layer = context
                layer.addFilter(.blur(radius: blur))
                layer.blendMode = .plusLighter
                layer.drawLayer { content in
                    drawSweeps(in: &content)
                    content.blendMode = .destinationIn
                    content.fill(bounds, with: .linearGradient(
                        Gradient(colors: colors),
                        startPoint: blurStart,
                        endPoint: blurEnd
                    ))
                }
            }
        }
        .frame(width: layout.diameter, height: layout.diameter)
        .opacity(CompassDialLayout.sunlight(atAltitude: altitude))
        .blendMode(.plusDarker)
    }
}

private func smoothstep(from edge0: Double, to edge1: Double, value: Double) -> Double {
    let t = min(max((value - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}

#Preview {
    let date = Date.now
    NavigationStack {
        CitySunPositionView(
            date: date,
            timeZone: .current,
            dateLabel: date.formattedDate(style: "Relative", timeZone: .current, relativeTo: date),
            isAdjusting: false,
            canGoLive: true,
            isLive: .constant(false)
        )
            .ignoresSafeArea(edges: .bottom)
            .containerBackground(for: .navigation) {
                CitySkyBackground(date: date, timeZone: .current)
            }
    }
    .environment(WatchWeatherStore())
}
