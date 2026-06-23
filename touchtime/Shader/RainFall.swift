//
//  RainFall.swift
//  touchtime
//
//  SwiftUI wrapper around the rainFall Metal shader.
//

import SwiftUI

private struct RainFallEffect: ViewModifier {
    let intensity: Float
    /// Relative drop size. 1.0 keeps the default size; smaller values (e.g. 0.6)
    /// produce smaller, denser drops.
    let dropScale: Float
    /// When non-nil, the shader is rendered as a single static frame at the
    /// given elapsed time instead of being driven by `TimelineView`. Used for
    /// `ImageRenderer` snapshots where animations don't run.
    let staticElapsed: Float?

    @State private var startDate = Date()
    @State private var isVisible = false
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        if intensity > 0 {
            if let staticElapsed {
                content
                    .visualEffect { view, proxy in
                        view.layerEffect(
                            ShaderLibrary.rainFall(
                                .float2(proxy.size),
                                .float(staticElapsed),
                                .float(intensity),
                                .float(dropScale)
                            ),
                            maxSampleOffset: CGSize(width: 30, height: 30)
                        )
                    }
            } else {
                // Only drive the per-frame shader while the view is on-screen and the
                // app is in the foreground; otherwise freeze it so we don't re-render
                // the shader every frame for an invisible/background view.
                TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                        paused: !isVisible || scenePhase != .active)) { context in
                    let elapsed = Float(context.date.timeIntervalSince(startDate))
                    content
                        .visualEffect { view, proxy in
                            view.layerEffect(
                                ShaderLibrary.rainFall(
                                    .float2(proxy.size),
                                    .float(elapsed),
                                    .float(intensity),
                                    .float(dropScale)
                                ),
                                maxSampleOffset: CGSize(width: 30, height: 30)
                            )
                        }
                }
                .onAppear { isVisible = true }
                .onDisappear { isVisible = false }
            }
        } else {
            content
        }
    }
}

extension View {
    /// Applies an animated rain-on-glass effect on top of the view.
    /// Pass an `intensity` of 0 to disable. `dropScale` scales the drop size
    /// (1.0 = default, smaller = smaller drops). When `staticElapsed` is
    /// non-nil, the shader is rendered once at that elapsed time (for snapshots).
    func rainFallEffect(intensity: Float, dropScale: Float = 1.0, staticElapsed: Float? = nil) -> some View {
        modifier(RainFallEffect(intensity: intensity, dropScale: dropScale, staticElapsed: staticElapsed))
    }
}
