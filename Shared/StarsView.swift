//
//  StarsView.swift
//  touchtime
//
//  The stars in a night sky. Lives in Shared/ so the Apple Watch app's skies
//  show the same stars as the iPhone app's.
//

import SwiftUI

// Container for multiple stars
struct StarsView: View {
    /// Turns the stars around the celestial pole like the real night sky: at the
    /// sidereal rate (~15° an hour) in real time, plus however far the displayed
    /// time has been moved away from now.
    struct Motion {
        /// Displayed time minus now.
        var timeOffset: TimeInterval
        /// The sky turns clockwise south of the equator and counterclockwise
        /// north of it.
        var turnsClockwise: Bool
    }

    var starCount: Int = 25  // Number of stars (configurable)
    var motion: Motion? = nil  // nil keeps the stars still
    // Unit-disc positions, laid out at the current size when drawn: the size
    // seen in onAppear can be a transient one.
    @State private var stars: [StarFieldCanvas.Star] = []
    @State private var generatedAt = Date()
    // Retaken whenever the turning direction flips, so the stars carry on from
    // where they are instead of swinging over to mirror the new direction.
    @State private var turnAnchor = StarFieldCanvas.TurnAnchor()

    private static let siderealDegreesPerSecond = 360.98564736629 / 86_400

    private var direction: Double {
        guard let motion else { return 0 }
        return motion.turnsClockwise ? 1 : -1
    }

    private var offsetDegrees: Double {
        ((motion?.timeOffset ?? 0) * Self.siderealDegreesPerSecond).remainder(dividingBy: 360)
    }

    var body: some View {
        Group {
            if motion != nil {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let offsetRadians = offsetDegrees * .pi / 180
                    StarFieldCanvas(
                        stars: stars,
                        starCount: starCount,
                        driftDegrees: driftDegrees(at: timeline.date),
                        offset: AnimatablePair(cos(offsetRadians), sin(offsetRadians)),
                        turnAnchor: turnAnchor
                    )
                }
            } else {
                StarFieldCanvas(stars: stars, starCount: starCount)
            }
        }
        .drawingGroup()
        .onAppear {
            generateStars()
        }
        .onChange(of: direction) {
            let turn = driftDegrees(at: Date()) + offsetDegrees
            turnAnchor = StarFieldCanvas.TurnAnchor(
                angle: turnAnchor.angle(atTurn: turn),
                turn: turn,
                direction: direction
            )
        }
    }

    // Real-time turn since the stars were generated.
    private func driftDegrees(at date: Date) -> Double {
        date.timeIntervalSince(generatedAt) * Self.siderealDegreesPerSecond
    }

    private func generateStars() {
        stars = (0..<starCount * StarFieldCanvas.discStarsPerVisibleStar).map { _ in
            // The square root spreads the stars evenly over the disc's area
            let distance = Double.random(in: 0...1).squareRoot()
            let bearing = Double.random(in: 0..<(2 * .pi))
            return StarFieldCanvas.Star(
                x: distance * cos(bearing),
                y: distance * sin(bearing),
                spriteIndex: Self.randomSpriteIndex()
            )
        }
        generatedAt = Date()
        turnAnchor = StarFieldCanvas.TurnAnchor(turn: offsetDegrees, direction: direction)
    }

    private static func randomSpriteIndex() -> Int {
        // Create different star types
        let starType = Double.random(in: 0...1)
        let starSize: CGFloat

        if starType < 0.75 {  // 75% small dim stars
            starSize = CGFloat.random(in: 0.4...0.8)
        } else if starType < 0.97 {  // 22% medium stars
            starSize = CGFloat.random(in: 0.8...1.4)
        } else {  // 3% bright stars
            starSize = CGFloat.random(in: 1.5...2.5)
        }

        let index = Int((starSize * 10).rounded()) - 4
        return min(max(index, 0), StarFieldCanvas.spriteSizes.count - 1)
    }
}

extension StarsView.Motion {
    /// The sky over the city of `timeZoneIdentifier`, or over London for a zone
    /// without one.
    init(timeOffset: TimeInterval, timeZoneIdentifier: String) {
        let latitude = TimeZoneCoordinates.getCoordinate(for: timeZoneIdentifier)?.latitude ?? 51.5074
        self.init(timeOffset: timeOffset, turnsClockwise: latitude < 0)
    }
}

// The stars are scattered over a disc around the celestial pole as wide as the
// view's diagonal, so the view stays covered however far the disc turns; only
// the stars that land on the view are drawn.
private struct StarFieldCanvas: View, Animatable {
    struct Star {
        let x: Double  // position in the unit disc
        let y: Double
        let spriteIndex: Int
    }

    /// Pins the field's screen angle to one point of the sky's turn, from which
    /// it turns on in `direction`: -1 counterclockwise, 1 clockwise, 0 still.
    struct TurnAnchor {
        var angle = 0.0  // screen angle, in degrees
        var turn = 0.0  // the sky's turn (drift + offset) at that point, in degrees
        var direction = 0.0

        func angle(atTurn turn: Double) -> Double {
            angle + direction * (turn - self.turn)
        }
    }

    // Star sizes are rounded to 0.1pt so every star draws from a shared symbol.
    static let spriteSizes: [CGFloat] = (4...25).map { CGFloat($0) / 10 }
    // Keeps `starCount` stars on views up to about 4:1.
    static let discStarsPerVisibleStar = 14
    // Fraction of the view height, from the top. The same for every city so
    // switching cities never shifts the stars.
    private static let poleHeight = 0.4

    let stars: [Star]
    let starCount: Int
    // Real-time turn. Not animatable on purpose: its per-second updates must not
    // cut short an animated swing of `offset`.
    var driftDegrees: Double = 0
    // The time-offset turn as a point on the unit circle, like
    // `SunAlongCurveModifier`: animating it always sweeps the shorter way round.
    var offset = AnimatablePair(1.0, 0.0)
    var turnAnchor = TurnAnchor()

    var animatableData: AnimatablePair<Double, Double> {
        get { offset }
        set { offset = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let width = Double(size.width)
            let height = Double(size.height)
            guard width > 0, height > 0 else { return }

            let radius = hypot(width, height)
            let discToViewArea = Double.pi * radius * radius / (width * height)
            let count = min(stars.count, Int((Double(starCount) * discToViewArea).rounded(.up)))

            let offsetDegrees = atan2(offset.second, offset.first) * 180 / .pi
            let angle = turnAnchor.angle(atTurn: driftDegrees + offsetDegrees) * .pi / 180
            let cosAngle = cos(angle)
            let sinAngle = sin(angle)
            let poleX = width / 2
            let poleY = height * Self.poleHeight
            let bounds = CGRect(origin: .zero, size: size).insetBy(dx: -8, dy: -8)
            let sprites = Self.spriteSizes.indices.map { context.resolveSymbol(id: $0) }

            for star in stars.prefix(count) {
                let point = CGPoint(
                    x: poleX + radius * (star.x * cosAngle - star.y * sinAngle),
                    y: poleY + radius * (star.x * sinAngle + star.y * cosAngle)
                )
                guard bounds.contains(point), let sprite = sprites[star.spriteIndex] else { continue }
                context.draw(sprite, at: point)
            }
        } symbols: {
            ForEach(Self.spriteSizes.indices, id: \.self) { index in
                // The padding keeps the glow inside the symbol
                StarParticle(size: Self.spriteSizes[index])
                    .padding(6)
                    .tag(index)
            }
        }
    }
}
