//
//  ChromaticOrbit.swift
//  touchtime
//
//  SwiftUI wrapper around the ChromaticDispersion Metal shader, splitting a
//  view's outline into a rainbow that runs around it.
//

import SwiftUI

/// Splits a white outline of `rim` over the view into a rainbow, red out
/// and violet in, just around a point circling the view clockwise, so the
/// split runs around the outline. The rest of the outline doesn't show, and
/// the view itself stays as it is. The outline takes the shader rather than
/// the view, as Liquid Glass drawn into a shader's layer turns opaque. With
/// Reduce Motion there's no split.
private struct ChromaticOrbitEffect: ViewModifier {
    let rim: AnyShape

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seconds for the split to go once around.
    private static let period: TimeInterval = 5
    /// How far from the view's center the point circles, as a fraction of
    /// the view's shorter side.
    private static let orbitRadius: CGFloat = 0.44
    /// How far, in points, the split reaches from the point.
    private static let reach: CGFloat = 44
    /// How far, in points, red and violet part from the outline at the
    /// view's edge right by the point.
    private static let maximumShift: CGFloat = 5
    /// How soft the split is, so its bands blend into one another rather
    /// than reading as separate lines.
    private static let blurRadius: CGFloat = 2.5

    func body(content: Content) -> some View {
        let period = Self.period
        let orbitRadius = Self.orbitRadius
        let reach = Self.reach
        let maximumShift = Self.maximumShift

        content
            .overlay {
                if !reduceMotion {
                    TimelineView(.animation) { context in
                        let turn = context.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: period) / period
                        // From the top; with y running down, a growing angle turns clockwise
                        let angle = turn * 2 * .pi - .pi / 2

                        rim
                            .stroke(.white, lineWidth: 1.5)
                            .visualEffect { content, proxy in
                                let radius = min(proxy.size.width, proxy.size.height) * orbitRadius
                                let spot = CGPoint(
                                    x: proxy.size.width / 2 + radius * cos(angle),
                                    y: proxy.size.height / 2 + radius * sin(angle)
                                )

                                return content.layerEffect(
                                    ShaderLibrary.ChromaticSpot(
                                        .float2(proxy.size),
                                        .float2(spot),
                                        .float(reach),
                                        .float(maximumShift)
                                    ),
                                    maxSampleOffset: CGSize(width: maximumShift * 1.5, height: maximumShift * 1.5)
                                )
                            }
                            .blur(radius: Self.blurRadius)
                            .blendMode(.plusLighter)
                    }
                    .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    /// Splits `rim`, the view's outline, into a rainbow that runs around it
    /// clockwise.
    func chromaticOrbit(rim: some Shape) -> some View {
        modifier(ChromaticOrbitEffect(rim: AnyShape(rim)))
    }
}
