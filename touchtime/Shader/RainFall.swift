//
//  RainFall.swift
//  touchtime
//
//  SwiftUI wrapper around the rainFall Metal shader.
//

import SwiftUI

private struct RainFallEffect: ViewModifier {
    let intensity: Float

    @State private var startDate = Date()

    func body(content: Content) -> some View {
        if intensity > 0 {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                let elapsed = Float(context.date.timeIntervalSince(startDate))
                content
                    .visualEffect { view, proxy in
                        view.layerEffect(
                            ShaderLibrary.rainFall(
                                .float2(proxy.size),
                                .float(elapsed),
                                .float(intensity)
                            ),
                            maxSampleOffset: CGSize(width: 30, height: 30)
                        )
                    }
            }
        } else {
            content
        }
    }
}

extension View {
    /// Applies an animated rain-on-glass effect on top of the view.
    /// Pass an `intensity` of 0 to disable.
    func rainFallEffect(intensity: Float) -> some View {
        modifier(RainFallEffect(intensity: intensity))
    }
}
