//
//  SkyBackgroundView.swift
//  touchtime
//
//  Created for background usage
//

import SwiftUI
import WeatherKit

// The star particle view (StarParticle) lives in Shared/ so the widget's
// Daylight ring can render the same stars.

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

struct SkyBackgroundView: View {
    let date: Date
    let timeZoneIdentifier: String
    var weatherCondition: WeatherCondition? = nil
    /// When true, an animated rainy-glass shader is layered on top of the sky
    /// background whenever `weatherCondition` represents a rainy condition.
    var showRainEffect: Bool = false
    /// When non-nil, the rain shader is rendered as a single static frame at
    /// the given elapsed time. Used by `ImageRenderer` snapshots since
    /// `TimelineView` animations don't run during rendering.
    var staticRainElapsed: Float? = nil
    /// Set to false when the containing card already applies clipping and
    /// border chrome around the complete card.
    var appliesCardChrome: Bool = true

    // Create sky color gradient instance
    private var skyColorGradient: SkyColorGradient {
        SkyColorGradient(date: date, timeZoneIdentifier: timeZoneIdentifier, weatherCondition: weatherCondition)
    }

    private var rainIntensity: Float {
        guard showRainEffect, let condition = weatherCondition else { return 0 }
        return condition.rainIntensity
    }

    private var skyContent: some View {
        // Build the gradient once per body evaluation. `skyColorGradient` is a
        // computed property that constructs a new `SkyColorGradient` on every access
        // (each init does Calendar copies + dateComponents), and it was previously
        // read 5x per body. Reuse a single instance and its derived values.
        let gradient = skyColorGradient
        let starOpacity = gradient.starOpacity
        return ZStack {
            // Fill the full bounding rectangle so the rain shader never samples
            // transparent pixels (which would show as black refractive halos
            // around drops near the rounded corners).
            Rectangle()
                .fill(gradient.linearGradient(opacity: 0.65))
                .animation(.easeInOut(duration: 0.5), value: gradient.animationValue)

            // Stars overlay for nighttime
            if starOpacity > 0 {
                StarsView()
                    .opacity(starOpacity)
                    .blendMode(.plusLighter)
                    .animation(.easeInOut(duration: 0.5), value: starOpacity)
                    .allowsHitTesting(false)
            }
        }
        .rainFallEffect(intensity: rainIntensity, staticElapsed: staticRainElapsed)
    }

    @ViewBuilder
    var body: some View {
        if appliesCardChrome {
            // Run effects on the full rectangle, then round the complete sky so
            // shaders keep enough sampling room near the corners.
            skyContent.skyBackgroundCardChrome()
        } else {
            skyContent
        }
    }
}

extension View {
    func skyBackgroundCardChrome(cornerRadius: CGFloat = 26) -> some View {
        clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1.0)
                .blendMode(.plusLighter)
        )
    }
}
