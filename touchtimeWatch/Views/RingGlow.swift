//
//  RingGlow.swift
//  touchtimeWatch
//

import SwiftUI

/// Light along a band `bandWidth` wide inside its frame's edge, brightest at
/// the top and fading either way along a bell curve to nothing at its reach,
/// and ending a length either way from the top, rounded off as a band's round
/// ends are, so where it ends at the top, it rounds off around the top's
/// middle: around Pressure's ring, or at the weather ring's now.
/// From one reach or length to another, the light slides around the band
/// rather than fading from one to the other.
struct RingGlow: View, Animatable {
    /// Either side of the top, for the light to fade smoothly.
    private static let stopCount = 12

    var bandWidth: CGFloat
    /// At the top, where it's brightest.
    let opacity: Double
    /// How far the light would reach from the top either way before it's
    /// faded away, in degrees around the band.
    var reach: Double
    /// How far it goes from the top counterclockwise before it ends, in
    /// degrees around the band.
    var counterclockwiseLength: Double
    /// And clockwise.
    var clockwiseLength: Double

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, Double>, AnimatablePair<Double, Double>> {
        get {
            AnimatablePair(
                AnimatablePair(bandWidth, reach),
                AnimatablePair(counterclockwiseLength, clockwiseLength)
            )
        }
        set {
            (bandWidth, reach) = (newValue.first.first, newValue.first.second)
            (counterclockwiseLength, clockwiseLength) = (newValue.second.first, newValue.second.second)
        }
    }

    var body: some View {
        AngularGradient(
            stops: stops,
            center: .center,
            // A gradient's angles start at its right, a quarter turn past
            // the top.
            startAngle: .degrees(-90 - reach),
            endAngle: .degrees(-90 + reach)
        )
        .mask {
            Circle()
                .inset(by: bandWidth / 2)
                // A circle's path starts at its right too.
                .rotation(.degrees(-90 - counterclockwiseLength))
                .trim(from: 0, to: (counterclockwiseLength + clockwiseLength) / 360)
                .stroke(style: StrokeStyle(lineWidth: bandWidth, lineCap: .round))
        }
    }

    /// From nothing at the reach one way up to the top, and on to nothing at
    /// the reach the other way.
    private var stops: [Gradient.Stop] {
        (-Self.stopCount...Self.stopCount).map { step in
            let distance = Double(step) / Double(Self.stopCount)
            return Gradient.Stop(
                color: .white.opacity(opacity * Self.brightness(abs(distance))),
                location: (distance + 1) / 2
            )
        }
    }

    /// `distance` of the way from the top to the reach, from all of it to
    /// none along a bell curve: level at the top, so the light fades off
    /// anything there, such as Pressure's ring, without a crease.
    private static func brightness(_ distance: Double) -> Double {
        distance < 1 ? exp(-6 * distance * distance) : 0
    }
}
