//
//  CloudDrift.swift
//  touchtime
//
//  SwiftUI wrapper around the cloudDrift Metal shader, and the colors and
//  light the clouds take from the sky they drift across.
//

import SwiftUI

/// How the clouds in a sky are colored and lit. A vector, so that a change of
/// sky can animate from one lighting to the next.
nonisolated struct CloudLighting: VectorArithmetic {
    /// A cloud where the light falls on it, in OKLab.
    var lit: SIMD3<Double>
    /// A cloud where the light doesn't reach, in OKLab.
    var shade: SIMD3<Double>
    /// The way from a cloud to the light, in radians from straight up, turning
    /// left and on round toward the horizon.
    var lightAngle: Double

    static let zero = CloudLighting(lit: .zero, shade: .zero, lightAngle: 0)

    static func + (lhs: CloudLighting, rhs: CloudLighting) -> CloudLighting {
        CloudLighting(
            lit: lhs.lit + rhs.lit,
            shade: lhs.shade + rhs.shade,
            lightAngle: lhs.lightAngle + rhs.lightAngle
        )
    }

    static func - (lhs: CloudLighting, rhs: CloudLighting) -> CloudLighting {
        CloudLighting(
            lit: lhs.lit - rhs.lit,
            shade: lhs.shade - rhs.shade,
            lightAngle: lhs.lightAngle - rhs.lightAngle
        )
    }

    mutating func scale(by rhs: Double) {
        lit *= rhs
        shade *= rhs
        lightAngle *= rhs
    }

    var magnitudeSquared: Double {
        (lit * lit).sum() + (shade * shade).sum() + lightAngle * lightAngle
    }
}

extension SkyColorGradient {
    /// How clouds in this sky are colored and lit, with `cover` of it under
    /// cloud, in [0, 1]. Their lit faces take the horizon's color, close to
    /// white under a high sun and gold to coral around sunrise and sunset;
    /// their shade takes the sky overhead, grayed and lifted. The light comes
    /// from high on the left by day and swings down to the horizon with the
    /// sun, to catch the clouds from below.
    ///
    /// In the rain there's no glow of sunrise and sunset on the clouds, as
    /// there's none in the rainy sky behind them. Under a deck of cloud, as
    /// on an overcast day, the sun's colors don't get through either: the
    /// glow is gone and the clouds gray toward the colors' lightness alone.
    func cloudLighting(cover: Float) -> CloudLighting {
        let stops = oklabStops
        guard let zenith = stops.first, let horizon = stops.last else { return .zero }
        let white = SIMD3<Double>(1, 0, 0)

        // 0 under broken cloud, 1 under a deck that keeps the sun out
        let overcast = Self.cloudRamp(from: 0.6, to: 0.95, at: Double(cover))
        // 0 with the sun on the horizon, 1 once it is well up
        let day = Self.cloudRamp(from: -2, to: 22, at: solarAltitude)
        // 1 around sunrise and sunset, 0 well before and after, and none in
        // the rain or under a deck
        let isRaining = weatherCondition?.isRainy ?? false
        let glow = isRaining ? 0 : Self.cloudRamp(from: -7, to: -1, at: solarAltitude)
            * (1 - Self.cloudRamp(from: 2, to: 12, at: solarAltitude))
            * (1 - overcast)
        // 1 in the dark, 0 from civil twilight on
        let night = 1 - Self.cloudRamp(from: -18, to: -5, at: solarAltitude)

        var lit = horizon + (white - horizon) * (0.15 + 0.70 * day)
        // Faint as they are, clouds still stand out from a night sky
        lit.x += 0.05 * night
        // From the horizon's orange toward coral
        lit.y += 0.02 * glow
        lit.z -= 0.03 * glow

        var shade = zenith + (horizon - zenith) * 0.15
        let chroma = 0.75 - 0.40 * day
        shade.y *= chroma
        shade.z *= chroma
        shade.x += 0.24 * day + 0.11 * night + 0.08 * glow
        // Toward mauve
        shade.y += 0.025 * glow

        // A deck takes most of the color out of both, lit faces and shade
        let gray = 1 - 0.7 * overcast
        lit.y *= gray
        lit.z *= gray
        shade.y *= gray
        shade.z *= gray

        // 0 with the sun on the horizon or under it, 1 once it is high
        let high = Self.cloudRamp(from: 1, to: 14, at: solarAltitude)
        let lightDegrees = 125 - 105 * high

        return CloudLighting(lit: lit, shade: shade, lightAngle: lightDegrees * .pi / 180)
    }

    /// Eases from 0 at `start` to 1 at `end`.
    private static func cloudRamp(from start: Double, to end: Double, at value: Double) -> Double {
        let t = min(max((value - start) / (end - start), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

/// Clouds drifting across a sky, for cloudy weather. Goes above the sky and
/// its stars, which show through the gaps, and spans the sky's whole height:
/// the clouds thin out toward the bottom edge, the horizon.
struct CloudDriftView: View {
    /// How much of the sky is under cloud, in [0, 1]. Nothing is drawn at 0.
    var cover: Float
    var lighting: CloudLighting
    /// Opacity of the sky the clouds drift across, which they take on too.
    var skyOpacity: Double = 1
    /// Tells one sky from another: skies given the same text show the same
    /// clouds, others different ones.
    var variation: String = ""
    /// How big the clouds are, as a share of the size they take from the
    /// view's height. Below 1 they're smaller, and more of them show.
    var scale: CGFloat = 1
    /// The height of the whole sky, when the view covers only its top. The
    /// clouds take their size, and how they thin out toward the horizon, from
    /// it rather than from the view, so they're cut off as the view's height
    /// changes rather than growing and shrinking with it. Nil goes by the
    /// view's own height.
    var skyHeight: CGFloat? = nil
    /// When non-nil, the clouds hold still as they are this many seconds in,
    /// rather than drifting. Used for `ImageRenderer` snapshots, where
    /// animations don't run.
    var staticElapsed: Float? = nil

    @State private var isVisible = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seconds between frames. The clouds move a pixel a frame at most at
    /// this rate, so a higher one wouldn't show.
    private static let frameInterval: TimeInterval = 1.0 / 20.0
    /// Seconds after which the clouds' time starts over, as the shader's
    /// arithmetic gets coarser the larger the time is.
    private static let timePeriod: TimeInterval = 6 * 60 * 60
    /// Where the clouds hold still with Reduce Motion, in seconds.
    private static let stillElapsed: Float = 30
    /// The clouds grow with the view's height, within these limits, so a
    /// short row and a tall card both hold a few.
    nonisolated fileprivate static let unitRange: ClosedRange<CGFloat> = 72...200
    /// How far the clouds are blurred, as a share of their size, so they're
    /// as soft whatever size they are.
    nonisolated fileprivate static let blurPerUnit: CGFloat = 0.0175
    /// How many pixels the clouds are drawn with to their blur's radius. The
    /// blur leaves no detail that more would show, so they're drawn smaller
    /// than the view, with only this many, and scaled up to fill it.
    nonisolated fileprivate static let pixelsPerBlur: CGFloat = 2

    var body: some View {
        let seed = Self.seed(for: variation)

        Group {
            if let elapsed = staticElapsed ?? (reduceMotion ? Self.stillElapsed : nil) {
                CloudDriftFrame(
                    cover: cover,
                    lighting: lighting,
                    skyOpacity: skyOpacity,
                    seed: seed,
                    scale: scale,
                    skyHeight: skyHeight,
                    elapsed: elapsed
                )
            } else {
                // Only drive the shader while there are clouds to draw, the
                // view is on-screen and the app is in the foreground
                TimelineView(.animation(minimumInterval: Self.frameInterval,
                                        paused: cover <= 0 || !isVisible || scenePhase != .active)) { context in
                    CloudDriftFrame(
                        cover: cover,
                        lighting: lighting,
                        skyOpacity: skyOpacity,
                        seed: seed,
                        scale: scale,
                        skyHeight: skyHeight,
                        elapsed: Self.elapsed(at: context.date)
                    )
                }
                .onAppear { isVisible = true }
                .onDisappear { isVisible = false }
            }
        }
        .allowsHitTesting(false)
    }

    /// The clouds' time, read off the clock rather than counted from when the
    /// view appeared, so a sky's clouds carry on from where they had got to
    /// and are the same wherever that sky shows.
    private static func elapsed(at date: Date) -> Float {
        Float(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: timePeriod))
    }

    /// A number in [0, 1) that stays the same for the same text, from one
    /// launch to the next.
    private static func seed(for variation: String) -> Float {
        // FNV-1a
        var hash: UInt32 = 2_166_136_261
        for byte in variation.utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        return Float(hash >> 8) / Float(1 << 24)
    }
}

/// The clouds at one moment. The cover and the lighting animate; the time is
/// left out on purpose, so its steady updates don't cut an animation of the
/// others short.
private struct CloudDriftFrame: View, Animatable {
    var cover: Float
    var lighting: CloudLighting
    let skyOpacity: Double
    let seed: Float
    let scale: CGFloat
    let skyHeight: CGFloat?
    let elapsed: Float

    @Environment(\.displayScale) private var displayScale

    var animatableData: AnimatablePair<Float, CloudLighting> {
        get { AnimatablePair(cover, lighting) }
        set {
            cover = newValue.first
            lighting = newValue.second
        }
    }

    var body: some View {
        if cover > 0 {
            // Premultiplied by the sky's opacity on their way to the shader
            let lit = SkyColorGradient.color(fromOKLab: lighting.lit).opacity(skyOpacity)
            let shade = SkyColorGradient.color(fromOKLab: lighting.shade).opacity(skyOpacity)
            // y runs down
            let toLight = CGPoint(x: -sin(lighting.lightAngle), y: -cos(lighting.lightAngle))
            let unitRange = CloudDriftView.unitRange
            let blurPerUnit = CloudDriftView.blurPerUnit
            // The blur thins the clouds out toward the edges it runs into, so
            // they're drawn that far past the view's edges, out of sight
            let overdraw = (3 * unitRange.upperBound * scale * blurPerUnit).rounded(.up)

            GeometryReader { proxy in
                let height = skyHeight ?? (proxy.size.height - 2 * overdraw)
                let unit = min(max(height, unitRange.lowerBound), unitRange.upperBound) * scale
                let blur = unit * blurPerUnit
                let reduction = max(displayScale * blur / CloudDriftView.pixelsPerBlur, 1)
                // As tall as the sky, overdraw included, however much of it
                // the view covers
                let size = CGSize(width: proxy.size.width, height: height + 2 * overdraw)

                // The shader runs once for each of the smaller view's
                // pixels, and is given its sizes in that view's points
                Rectangle()
                    .fill(.white)
                    .frame(width: proxy.size.width / reduction, height: proxy.size.height / reduction)
                    .colorEffect(
                        ShaderLibrary.cloudDrift(
                            .float2(size.width / reduction, size.height / reduction),
                            .float(unit / reduction),
                            .float(elapsed),
                            .float(cover),
                            .float(seed),
                            .color(lit),
                            .color(shade),
                            .float2(toLight)
                        )
                    )
                    .blur(radius: blur / reduction)
                    .scaleEffect(reduction, anchor: .topLeading)
            }
            .padding(-overdraw)
        }
    }
}
