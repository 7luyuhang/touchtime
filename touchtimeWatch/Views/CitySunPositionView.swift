//
//  CitySunPositionView.swift
//  touchtimeWatch
//

import SwiftUI

/// The sun's direction over the city on a compass, north up, and the shadow
/// it casts from a glass triangle in the middle: away from the sun, longer as
/// the sun sinks, and gone once it sets.
struct CitySunPositionView: View {
    let date: Date
    let timeZone: TimeZone
    let dateLabel: String
    /// While the Digital Crown shows another time, the time shows under the
    /// triangle.
    let isAdjusting: Bool

    @Environment(\.locale) private var locale
    /// The sun's azimuth, in degrees past north, counting whole turns so the
    /// sun and shadow always animate the shorter way around.
    @State private var displayedAzimuth: Double?

    private var sunPosition: SolarCalculator.Position {
        let coordinate = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier)
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

        GeometryReader { geometry in
            let layout = SunDialLayout(
                diameter: max(0, min(geometry.size.width - 16, geometry.size.height - 12))
            )

            ZStack {
                ZStack {
                    CompassDial(layout: layout)

                    SunOrbit(
                        azimuth: azimuth,
                        isSunFilled: position.altitude > SunDialLayout.civilTwilightAltitude,
                        layout: layout
                    )
                    .animation(.smooth, value: displayedAzimuth)

                    SunPositionLabel(
                        dateLabel: dateLabel,
                        azimuth: azimuth,
                        isSunInTopHalf: cos(position.azimuth * .pi / 180) > 0,
                        layout: layout
                    )
                    .animation(.smooth, value: displayedAzimuth)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sun Position")
                .accessibilityValue(accessibilityValue(for: position))

                // The triangle and the time, centered together.
                VStack(spacing: 6) {
                    Color.clear
                        .frame(width: layout.triangleFrame.width, height: layout.triangleFrame.height)
                        .glassEffect(.clear, in: RoundedTriangle(cornerRadius: layout.triangleCornerRadius))
                        .background {
                            TriangleShadow(azimuth: azimuth, altitude: position.altitude, layout: layout)
                                .animation(.smooth, value: displayedAzimuth)
                        }
                        // Alone, centered on its middle and lowered a little. With
                        // the time, laid out by the triangle itself: its rounded
                        // point is a corner radius below its frame's top, and its
                        // base halfway from the middle to the bottom.
                        .padding(.top, isAdjusting ? -layout.triangleCornerRadius : 0)
                        .padding(.bottom, isAdjusting ? -layout.triangleRadius / 2 : 0)
                        .offset(y: isAdjusting ? 0 : layout.triangleDrop)
                        .accessibilityHidden(true)

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
        return "\(dateLabel), \(sunPosition)"
    }
}

/// The dial's measurements. The labels' band keeps its width on every watch,
/// like the daylight ring's hours; the rest scales with the diameter.
private struct SunDialLayout {
    /// The sun's altitude at sunrise and sunset: its upper edge on the
    /// horizon, raised by refraction.
    static let horizonAltitude = -0.833
    /// The sun's altitude at civil dawn and dusk, below which the daylight
    /// ring outlines its sun.
    static let civilTwilightAltitude = -6.0
    static let labelBandWidth: CGFloat = 16
    static let lineWidth: CGFloat = 1

    let diameter: CGFloat

    var center: CGPoint { CGPoint(x: diameter / 2, y: diameter / 2) }
    /// The dial's edge, inset to keep its line inside.
    var edgeRadius: CGFloat { (diameter - Self.lineWidth) / 2 }
    /// Through the middle of the outer band, where the labels sit.
    var labelRadius: CGFloat { (diameter - Self.labelBandWidth) / 2 }
    /// As big as the daylight ring's sun, whose ring is a little smaller than
    /// this dial.
    var sunDiameter: CGFloat { diameter * 0.11 }
    /// The sun's track, inside the labels' band, which the sun fills.
    var trackOuterRadius: CGFloat { diameter / 2 - Self.labelBandWidth }
    var trackInnerRadius: CGFloat { trackOuterRadius - sunDiameter }
    var orbitRadius: CGFloat { trackOuterRadius - sunDiameter / 2 }

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

/// The dial's rings: N, E, S and W and the degrees between them around the
/// outside, and inside them the track the sun travels.
private struct CompassDial: View {
    let layout: SunDialLayout

    var body: some View {
        ZStack {
            Path { path in
                for radius in [layout.edgeRadius, layout.trackOuterRadius, layout.trackInnerRadius] {
                    path.addEllipse(in: CGRect(
                        x: layout.center.x - radius,
                        y: layout.center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))
                }
            }
            .stroke(.white.opacity(0.1), lineWidth: SunDialLayout.lineWidth)
            .blendMode(.plusLighter)

            ForEach(Array(stride(from: 0, to: 360, by: 30)), id: \.self) { degrees in
                Text(verbatim: degrees.isMultiple(of: 90) ? ["N", "E", "S", "W"][degrees / 90] : String(degrees))
                    .foregroundStyle(degrees == 0 ? .black : .white)
                    .background {
                        if degrees == 0 {
                            // Just clear of the lines either side of the labels.
                            Circle()
                                .fill(.white)
                                .frame(width: SunDialLayout.labelBandWidth - 2, height: SunDialLayout.labelBandWidth - 2)
                        }
                    }
                    // Turned along the dial, and over across its bottom half to
                    // read left to right, like the daylight ring's hours.
                    .rotationEffect(.degrees(Double(degrees > 90 && degrees < 270 ? degrees - 180 : degrees)))
                    .position(layout.point(atDegrees: Double(degrees), radius: layout.labelRadius))
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .frame(width: layout.diameter, height: layout.diameter)
    }
}

/// The sun on its track, as on the daylight ring: a disc while it's light out,
/// and an outline from civil dusk to dawn.
private struct SunOrbit: View, Animatable {
    /// Degrees clockwise from north.
    var azimuth: Double
    let isSunFilled: Bool
    let layout: SunDialLayout

    var animatableData: Double {
        get { azimuth }
        set { azimuth = newValue }
    }

    var body: some View {
        let fill: CGFloat = isSunFilled ? 1 : 0

        SunDisc(fill: fill, lineWidth: 2)
            .fill(.white, style: FillStyle(eoFill: true))
            .opacity(0.35 + 0.65 * fill)
            .blendMode(.plusLighter)
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
            .frame(width: layout.sunDiameter, height: layout.sunDiameter)
            .position(layout.point(atDegrees: azimuth, radius: layout.orbitRadius))
            .frame(width: layout.diameter, height: layout.diameter)
    }
}

/// The day and the sun's direction, in degrees and on the compass, along its
/// track: across the top while the sun is in the bottom half, and across the
/// bottom while it's in the top half. The degrees count along as the sun
/// moves.
private struct SunPositionLabel: View, Animatable {
    private static let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    private static let font = Font.system(.footnote, weight: .medium).monospacedDigit()
    /// Clear of the sun, which is always in the other half.
    private static let maxAngle = Angle.degrees(140)

    let dateLabel: String
    /// Degrees clockwise from north.
    var azimuth: Double
    /// Where the sun is headed, rather than where it is on the way, sets the
    /// side.
    let isSunInTopHalf: Bool
    let layout: SunDialLayout

    var animatableData: Double {
        get { azimuth }
        set { azimuth = newValue }
    }

    var body: some View {
        let degrees = (Int(azimuth.rounded()) % 360 + 360) % 360
        let text = "\(dateLabel) · \(degrees)°\(Self.directions[(degrees + 22) / 45 % 8])"

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
            radius: layout.orbitRadius,
            maxAngle: Self.maxAngle,
            isAtBottom: isAtBottom
        )
        .transition(.blurReplace)
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
    let layout: SunDialLayout

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

    /// Fading in as the sun's disc, about half a degree across, clears the
    /// horizon at sunrise, and out as it goes down at sunset.
    private var strength: Double {
        smoothstep(from: SunDialLayout.horizonAltitude, to: SunDialLayout.horizonAltitude + 0.53, value: altitude)
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
        .opacity(strength)
        .blendMode(.plusDarker)
    }
}

/// An equilateral triangle pointing north, centered on its middle, with
/// rounded corners.
private struct RoundedTriangle: Shape {
    var cornerRadius: CGFloat

    /// Its corners `radius` from `center`, clockwise from the top.
    static func vertices(center: CGPoint, radius: CGFloat) -> [CGPoint] {
        (0..<3).map { index in
            let angle = Double(index) * 2 * .pi / 3
            return CGPoint(x: center.x + radius * sin(angle), y: center.y - radius * cos(angle))
        }
    }

    func path(in rect: CGRect) -> Path {
        let vertices = Self.vertices(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2
        )
        var path = Path()
        path.move(to: CGPoint(x: (vertices[2].x + vertices[0].x) / 2, y: (vertices[2].y + vertices[0].y) / 2))
        for index in vertices.indices {
            path.addArc(
                tangent1End: vertices[index],
                tangent2End: vertices[(index + 1) % vertices.count],
                radius: cornerRadius
            )
        }
        path.closeSubpath()
        return path
    }
}

/// A line of text bent along a circle about the middle of its frame: across
/// the top reading clockwise, or across the bottom turned over to read left
/// to right, like the dial's labels there.
private struct CurvedText: View {
    let text: String
    let font: Font
    let radius: CGFloat
    /// The most of the circle the text spans, shrinking to fit beyond it.
    let maxAngle: Angle
    let isAtBottom: Bool

    var body: some View {
        Canvas { context, size in
            let characters = text.map { character in
                context.resolve(
                    Text(verbatim: String(character))
                        .font(font)
                        .foregroundStyle(.white)
                )
            }
            let widths = characters.map { $0.measure(in: size).width }
            let length = widths.reduce(0, +)
            let scale = min(1, radius * maxAngle.radians / length)

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // Along the circle from the text's middle to the character's.
            var distance = -length * scale / 2
            for (character, width) in zip(characters, widths) {
                let angle = (distance + width * scale / 2) / radius
                distance += width * scale
                // Clockwise from north: left to right runs clockwise across
                // the top, and counterclockwise across the bottom.
                let position = isAtBottom ? .pi - angle : angle
                var glyph = context
                glyph.translateBy(x: center.x + radius * sin(position), y: center.y - radius * cos(position))
                glyph.rotate(by: .radians(isAtBottom ? -angle : angle))
                glyph.scaleBy(x: scale, y: scale)
                glyph.draw(character, at: .zero)
            }
        }
    }
}

private extension SunDialLayout {
    /// `radius` from the center, `degrees` clockwise from north.
    func point(atDegrees degrees: Double, radius: CGFloat) -> CGPoint {
        let angle = degrees * .pi / 180
        return CGPoint(x: center.x + radius * sin(angle), y: center.y - radius * cos(angle))
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
            isAdjusting: false
        )
            .ignoresSafeArea(edges: .bottom)
            .containerBackground(for: .navigation) {
                CitySkyBackground(date: date, timeZone: .current)
            }
    }
}
