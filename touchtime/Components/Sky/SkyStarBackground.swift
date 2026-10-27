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
    /// Draws the sky opaque, as it looks over black.
    var drawsOverBlack: Bool = false
    /// How many stars show at night, and how they turn (nil keeps them still).
    var starCount: Int = 25
    var starsMotion: StarsView.Motion? = nil

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
                .fill(drawsOverBlack ? gradient.linearGradientOverBlack(opacity: 0.65) : gradient.linearGradient(opacity: 0.65))
                .animation(.easeInOut(duration: 0.5), value: gradient.animationValue)

            // Stars overlay for nighttime
            if starOpacity > 0 {
                StarsView(starCount: starCount, motion: starsMotion)
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
