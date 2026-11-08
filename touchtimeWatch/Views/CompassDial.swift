//
//  CompassDial.swift
//  touchtimeWatch
//

import SwiftUI

/// The compass dial's measurements, in Sun Position and Wind alike. The
/// labels' band keeps its width on every watch, like the daylight ring's
/// hours; the rest scales with the diameter.
struct CompassDialLayout {
    static let labelBandWidth: CGFloat = 16
    static let lineWidth: CGFloat = 1

    let diameter: CGFloat

    var center: CGPoint { CGPoint(x: diameter / 2, y: diameter / 2) }
    /// The dial's edge, inset to keep its line inside.
    var edgeRadius: CGFloat { (diameter - Self.lineWidth) / 2 }
    /// Through the middle of the outer band, where the labels sit.
    var labelRadius: CGFloat { (diameter - Self.labelBandWidth) / 2 }
    /// As wide as the daylight ring's sun, whose ring is a little smaller
    /// than this dial.
    var trackWidth: CGFloat { diameter * 0.11 }
    /// The track, inside the labels' band.
    var trackOuterRadius: CGFloat { diameter / 2 - Self.labelBandWidth }
    var trackInnerRadius: CGFloat { trackOuterRadius - trackWidth }
    /// Through the middle of the track.
    var trackRadius: CGFloat { trackOuterRadius - trackWidth / 2 }

    /// `radius` from the center, `degrees` clockwise from north.
    func point(atDegrees degrees: Double, radius: CGFloat) -> CGPoint {
        let angle = degrees * .pi / 180
        return CGPoint(x: center.x + radius * sin(angle), y: center.y - radius * cos(angle))
    }
}

/// The dial's rings: N, E, S and W and the degrees between them around the
/// outside, with a small tick between each two, and inside them the track
/// the sun travels in Sun Position, and the wind's marks in Wind. Live, it
/// turns against the watch's heading.
struct CompassDial: View, Animatable {
    private static let labelDegrees = Array(stride(from: 0, to: 360, by: 30))
    /// Halfway between each two labels.
    private static let tickDegrees = labelDegrees.map { $0 + 15 }
    private static let tickSize = CGSize(width: 1.5, height: 6)
    /// The rings' and the ticks', lightening the sky behind them.
    private static let lineColor = Color.white.opacity(0.1)
    private static let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

    let layout: CompassDialLayout
    /// How far the dial is turned counterclockwise, in degrees.
    var heading: Double
    /// The labels turned over to read left to right across the bottom.
    let flippedLabels: Set<Int>

    var animatableData: Double {
        get { heading }
        set { heading = newValue }
    }

    /// The labels below the sides of the dial turned to `heading`. Updated
    /// from `current`, a label on a side keeps its way up until it's well
    /// past, so a wavering heading can't flip it back and forth.
    static func flippedLabels(atHeading heading: Double, from current: Set<Int>? = nil) -> Set<Int> {
        Set(labelDegrees.filter { degrees in
            // Around the screen, clockwise from the top.
            var angle = (Double(degrees) - heading).truncatingRemainder(dividingBy: 360)
            if angle < 0 {
                angle += 360
            }
            guard let current else {
                // E and W, on the sides with north up, read along the top half.
                return angle > 90 && angle < 270
            }
            let height = cos(angle * .pi / 180)
            return abs(height) > 0.25 ? height < 0 : current.contains(degrees)
        })
    }

    /// `degrees` clockwise from north, in whole degrees and on the compass,
    /// as "114°SE".
    static func bearing(_ degrees: Double) -> String {
        let degrees = (Int(degrees.rounded()) % 360 + 360) % 360
        return "\(degrees)°\(directions[(degrees + 22) / 45 % 8])"
    }

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
            .stroke(Self.lineColor, lineWidth: CompassDialLayout.lineWidth)
            .blendMode(.plusLighter)

            ForEach(Self.tickDegrees, id: \.self) { degrees in
                Capsule()
                    .fill(Self.lineColor)
                    .blendMode(.plusLighter)
                    .frame(width: Self.tickSize.width, height: Self.tickSize.height)
                    .rotationEffect(.degrees(Double(degrees) - heading))
                    .position(layout.point(atDegrees: Double(degrees) - heading, radius: layout.labelRadius))
            }

            ForEach(Self.labelDegrees, id: \.self) { degrees in
                let label = Text(verbatim: degrees.isMultiple(of: 90) ? ["N", "E", "S", "W"][degrees / 90] : String(degrees))

                Group {
                    if degrees == 0 {
                        // Just clear of the lines either side of the labels,
                        // with the N cut out of it.
                        Circle()
                            .fill(.white)
                            .frame(width: CompassDialLayout.labelBandWidth - 2, height: CompassDialLayout.labelBandWidth - 2)
                            .overlay {
                                label.blendMode(.destinationOut)
                            }
                            .compositingGroup()
                    } else {
                        label.foregroundStyle(.white)
                    }
                }
                // Turned along the dial, and over across its bottom half to
                // read left to right, like the daylight ring's hours.
                .scaleEffect(flippedLabels.contains(degrees) ? -1 : 1)
                .rotationEffect(.degrees(Double(degrees) - heading))
                .position(layout.point(atDegrees: Double(degrees) - heading, radius: layout.labelRadius))
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .frame(width: layout.diameter, height: layout.diameter)
    }
}

/// An equilateral triangle pointing north, centered on its middle, with
/// rounded corners.
struct RoundedTriangle: Shape {
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
struct CurvedText: View {
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
