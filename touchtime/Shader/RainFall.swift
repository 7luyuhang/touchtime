//
//  RainFall.swift
//  touchtime
//
//  SwiftUI wrapper around the rainFall Metal shader.
//

import SwiftUI

private struct RainFallEffect: ViewModifier {
    let intensity: Float
    /// When non-nil, the shader is rendered as a single static frame at the
    /// given elapsed time instead of being driven by `TimelineView`. Used for
    /// `ImageRenderer` snapshots where animations don't run.
    let staticElapsed: Float?

    @State private var startDate = Date()

    func body(content: Content) -> some View {
        if intensity > 0 {
            if let staticElapsed {
                content
                    .visualEffect { view, proxy in
                        view.layerEffect(
                            ShaderLibrary.rainFall(
                                .float2(proxy.size),
                                .float(staticElapsed),
                                .float(intensity)
                            ),
                            maxSampleOffset: CGSize(width: 30, height: 30)
                        )
                    }
            } else {
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
            }
        } else {
            content
        }
    }
}

extension View {
    /// Applies an animated rain-on-glass effect on top of the view.
    /// Pass an `intensity` of 0 to disable. When `staticElapsed` is non-nil,
    /// the shader is rendered once at that elapsed time (for snapshots).
    func rainFallEffect(intensity: Float, staticElapsed: Float? = nil) -> some View {
        modifier(RainFallEffect(intensity: intensity, staticElapsed: staticElapsed))
    }
}
