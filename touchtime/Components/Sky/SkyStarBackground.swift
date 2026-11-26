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
    /// When true, the weather shows in the sky: clouds drift across it
    /// whenever `weatherCondition` is a cloudy one, and an animated
    /// rainy-glass shader is layered on top whenever it's a rainy one.
    var showWeatherEffects: Bool = false
    /// When non-nil, the weather shaders are rendered as a single static frame
    /// at the given elapsed time. Used by `ImageRenderer` snapshots since
    /// `TimelineView` animations don't run during rendering.
    var staticWeatherElapsed: Float? = nil
    /// Tells this sky's clouds from another's: skies given the same text show
    /// the same clouds. Nil goes by the time zone, which cities can share.
    var cloudVariation: String? = nil
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
            if showWeatherEffects {
                CloudDriftView(
                    cover: cloudCover,
                    lighting: gradient.cloudLighting,
                    skyOpacity: Self.skyOpacity,
                    variation: cloudVariation ?? timeZoneIdentifier,
                    staticElapsed: staticWeatherElapsed
                )
                .animation(.easeInOut(duration: 0.5), value: gradient.animationValue)
                .animation(.easeInOut(duration: 1.0), value: cloudCover)
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
