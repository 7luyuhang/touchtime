//
//  ChromaticEntrance.swift
//  touchtime
//
//  SwiftUI wrapper around the ChromaticDispersion Metal shader, bringing a
//  view in with its outline split into a rainbow.
//

import SwiftUI

/// Grows the view in from small, blurred and faint as it rises from below,
/// while a white outline of `rim` over it is split into a rainbow that gathers
/// back into one line and fades as the view settles. The outline takes the
/// shader rather than the view, as Liquid Glass drawn into a shader's layer
/// turns opaque. With Reduce Motion the view only fades in.
private struct ChromaticEntranceEffect: ViewModifier, Animatable {
    /// 0 before the view comes in, 1 once it has settled.
    var progress: Double
    let rim: AnyShape

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let initialScale: CGFloat = 0.50
    /// How far, in points, below its place the view starts.
    private static let initialOffset: CGFloat = 50
    private static let maximumBlurRadius: CGFloat = 50
    /// How far, in points, red and violet part from the outline at the
    /// view's edge as the view starts to come in.
    private static let maximumShift: CGFloat = 10

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let progress = min(max(progress, 0), 1)
        let remaining = reduceMotion ? 0 : 1 - progress
        // Clears ahead of the rainbow, which reads best on a sharp view
        let blurRadius = Self.maximumBlurRadius * pow(remaining, 1.5)
        // Trails the rest of the entrance, so the rainbow gathers and fades
        // gradually rather than snapping shut
        let dispersion = pow(remaining, 2.0 / 3.0)
        let maximumShift = Self.maximumShift

        content
            .blur(radius: blurRadius)
            .overlay {
                if remaining > 0 {
                    rim
                        .stroke(.white, lineWidth: 1.5)
                        .visualEffect { content, proxy in
                            content.layerEffect(
                                ShaderLibrary.ChromaticDispersion(
                                    .float2(proxy.size),
                                    .float(dispersion),
                                    .float(maximumShift)
                                ),
                                maxSampleOffset: CGSize(width: maximumShift * 1.5, height: maximumShift * 1.5)
                            )
                        }
                        .blur(radius: blurRadius / 4)
                        .opacity(dispersion)
                        .blendMode(.plusLighter)
                }
            }
            .scaleEffect(1 - (1 - Self.initialScale) * remaining)
            .offset(y: Self.initialOffset * remaining)
            .opacity(reduceMotion ? progress : min(progress * 3, 1))
    }
}

extension View {
    /// Brings the view in as `progress` animates from 0 to 1: it rises from
    /// below and grows in from small and blurred, with `rim`, the view's
    /// outline, split into a rainbow that gathers into its edge.
    func chromaticEntrance(progress: Double, rim: some Shape) -> some View {
        modifier(ChromaticEntranceEffect(progress: progress, rim: AnyShape(rim)))
    }
}
