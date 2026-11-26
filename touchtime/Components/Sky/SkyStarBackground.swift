//
//  SkyBackgroundView.swift
//  touchtime
//
//  Created for background usage
//

import SwiftUI
import WeatherKit

// The stars (StarsView, and StarParticle for each star) live in Shared/ so the
// widget's Daylight ring and the Apple Watch app render the same stars.

struct SkyBackgroundView: View {
    let date: Date
    let timeZoneIdentifier: String
    var weatherCondition: WeatherCondition? = nil
    /// When true, the weather shows in the sky: an animated rainy-glass
    /// shader is layered on top whenever `weatherCondition` is a rainy one.
    var showWeatherEffects: Bool = false
    /// When true, clouds drift across the sky whenever `weatherCondition` is
    /// a cloudy one. Only the sky behind the whole details sheet shows them;
    /// cards, Home's rows and the details' time card among them, stay clear.
    var showClouds: Bool = false
    /// When non-nil, the weather shaders are rendered as a single static frame
    /// at the given elapsed time. Used by `ImageRenderer` snapshots since
    /// `TimelineView` animations don't run during rendering.
    var staticWeatherElapsed: Float? = nil
    /// Tells this sky's clouds from another's: skies given the same text show
    /// the same clouds. Nil goes by the time zone, which cities can share.
    var cloudVariation: String? = nil
    /// How big the clouds are, as a share of the size they'd take from the
    /// sky's height. Below 1 they're smaller, and more of them show.
    var cloudScale: CGFloat = 1
    /// Where the clouds give out, in global coordinates, as the bottom edge of
    /// what sits over the top of the sky. The clouds are only drawn above it,
    /// fading out toward it. Nil leaves them to thin out down the top half.
    var cloudsBottom: CGFloat? = nil
    /// Set to false when the containing card already applies clipping and
    /// border chrome around the complete card.
    var appliesCardChrome: Bool = true
    /// Draws the sky opaque, as it looks over black.
    var drawsOverBlack: Bool = false
    /// How many stars show at night, and how they turn (nil keeps them still).
    var starCount: Int = 25
    var starsMotion: StarsView.Motion? = nil

    // Create sky color gradient instance
    private var skyColorGradient: SkyColorGradient {
        SkyColorGradient(date: date, timeZoneIdentifier: timeZoneIdentifier, weatherCondition: weatherCondition)
    }

    /// The sky is drawn this translucent, or as it looks this translucent
    /// over black.
    private static let skyOpacity = 0.65
    /// How far down the sky the clouds reach, as a share of its height, when
    /// nothing sets `cloudsBottom`.
    private static let cloudsDepth: CGFloat = 0.45

    private var rainIntensity: Float {
        guard showWeatherEffects, let condition = weatherCondition else { return 0 }
        return condition.rainIntensity
    }

    private var skyContent: some View {
        // Build the gradient once per body evaluation. `skyColorGradient` is a
        // computed property that constructs a new `SkyColorGradient` on every access
        // (each init does Calendar copies + dateComponents), and it was previously
        // read 5x per body. Reuse a single instance and its derived values.
        let gradient = skyColorGradient
        let starOpacity = gradient.starOpacity
        let cloudCover = weatherCondition?.cloudCover ?? 0
        return ZStack {
            // Fill the full bounding rectangle so the rain shader never samples
            // transparent pixels (which would show as black refractive halos
            // around drops near the rounded corners).
            Rectangle()
                .fill(drawsOverBlack ? gradient.linearGradientOverBlack(opacity: Self.skyOpacity) : gradient.linearGradient(opacity: Self.skyOpacity))
                .animation(.easeInOut(duration: 0.5), value: gradient.animationValue)

            // Stars overlay for nighttime
            if starOpacity > 0 {
                StarsView(starCount: starCount, motion: starsMotion)
                    .opacity(starOpacity)
                    .blendMode(.plusLighter)
                    .animation(.easeInOut(duration: 0.5), value: starOpacity)
                    .allowsHitTesting(false)
            }

            // Clouds for cloudy weather, over the stars they hide. Kept in
            // place under a clear sky too, so that they gather and clear
            // rather than cut in and out as the weather changes.
            if showClouds {
                let clouds = { (skyHeight: CGFloat?) in
                    CloudDriftView(
                        cover: cloudCover,
                        lighting: gradient.cloudLighting(cover: cloudCover),
                        skyOpacity: Self.skyOpacity,
                        variation: cloudVariation ?? timeZoneIdentifier,
                        scale: cloudScale,
                        skyHeight: skyHeight,
                        staticElapsed: staticWeatherElapsed
                    )
                    .animation(.easeInOut(duration: 0.5), value: gradient.animationValue)
                    .animation(.easeInOut(duration: 1.0), value: cloudCover)
                }

                if let cloudsBottom {
                    // Drawn only as far down as they show, so the shader and
                    // its blur cover no more of the sky than that. They're
                    // sized by the whole sky, so they're cut off, not resized,
                    // as that edge moves.
                    GeometryReader { proxy in
                        let height = max(cloudsBottom - proxy.frame(in: .global).minY, 0)
                        clouds(proxy.size.height)
                            .frame(height: height)
                            .mask {
                                LinearGradient(
                                    stops: [
                                        .init(color: .black, location: 0),
                                        .init(color: .black, location: 0.55),
                                        .init(color: .clear, location: 1),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            }
                    }
                    .allowsHitTesting(false)
                } else {
                    // Only the top of the sky is cloudy; they thin out and are
                    // gone before the cards further down. Drawn only that far
                    // down, so the shader covers no more of the sky than shows,
                    // and sized by the whole sky so they look as they would
                    // drawn over all of it.
                    GeometryReader { proxy in
                        clouds(proxy.size.height)
                            .frame(height: proxy.size.height * Self.cloudsDepth)
                            .mask {
                                LinearGradient(
                                    stops: [
                                        .init(color: .black, location: 0),
                                        .init(color: .black, location: 0.15 / Self.cloudsDepth),
                                        .init(color: .clear, location: 1),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            }
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .rainFallEffect(intensity: rainIntensity, staticElapsed: staticWeatherElapsed)
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
