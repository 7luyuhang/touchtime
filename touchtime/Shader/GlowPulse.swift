//
//  GlowPulse.swift
//  touchtime
//
//  SwiftUI wrapper around the glowPulse Metal shader. Plays a single white
//  glow that rises from the bottom edge, pulses, and softens (its blur grows)
//  as it climbs — once each time the view appears.
//

import SwiftUI

struct GlowPulseView: View {
    /// Length of a single pulse, in seconds.
    var duration: TimeInterval = 1.25
    /// Overall strength of the glow, in [0, 1].
    var intensity: Float = 0.25

    @State private var runID = 0

    var body: some View {
        Rectangle()
            .fill(.white)
            .keyframeAnimator(initialValue: 0.0, trigger: runID) { view, progress in
                view.visualEffect { content, proxy in
                    content.colorEffect(
                        ShaderLibrary.glowPulse(
                            .float2(proxy.size),
                            .float(Float(progress)),
                            .float(intensity)
                        )
                    )
                }
            } keyframes: { _ in
                CubicKeyframe(1.0, duration: duration)
            }
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
            .onAppear { runID += 1 }
    }
}
