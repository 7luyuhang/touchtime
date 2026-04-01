//
//  EdgeChromaticSwipeEffect.swift
//  touchtime
//
//  Created on 01/04/2026.
//

import SwiftUI

struct EdgeChromaticSwipeEffect: ViewModifier {
    let viewportMidX: CGFloat
    let coordinateSpaceName: String
    let blurStrength: CGFloat
    let edgeThreshold: CGFloat
    let maxSampleOffset: CGFloat

    nonisolated private static func normalizedDistanceToCenter(
        for proxy: GeometryProxy,
        viewportMidX: CGFloat,
        coordinateSpaceName: String
    ) -> CGFloat {
        let distanceToCenter = abs(
            proxy.frame(in: .named(coordinateSpaceName)).midX - viewportMidX
        )
        return min(distanceToCenter / max(proxy.size.width, 1), 1)
    }

    nonisolated private static func edgeChromaticProgress(
        normalizedDistance: CGFloat,
        edgeThreshold: CGFloat
    ) -> CGFloat {
        min(max((normalizedDistance - edgeThreshold) / max(1 - edgeThreshold, 0.001), 0), 1)
    }

    nonisolated private static func edgeDirection(
        for proxy: GeometryProxy,
        viewportMidX: CGFloat,
        coordinateSpaceName: String
    ) -> CGFloat {
        proxy.frame(in: .named(coordinateSpaceName)).midX >= viewportMidX ? 1 : -1
    }

    func body(content: Content) -> some View {
        content.visualEffect { content, proxy in
            let normalizedDistance = Self.normalizedDistanceToCenter(
                for: proxy,
                viewportMidX: viewportMidX,
                coordinateSpaceName: coordinateSpaceName
            )
            let chromaticProgress = Self.edgeChromaticProgress(
                normalizedDistance: normalizedDistance,
                edgeThreshold: edgeThreshold
            )
            let chromaticDirection = Self.edgeDirection(
                for: proxy,
                viewportMidX: viewportMidX,
                coordinateSpaceName: coordinateSpaceName
            )
            let edgeShader = ShaderLibrary.EdgeRGBSplit(
                .float2(proxy.size),
                .float(chromaticProgress),
                .float(chromaticDirection)
            )

            return content
                .layerEffect(
                    edgeShader,
                    maxSampleOffset: CGSize(width: maxSampleOffset, height: 0),
                    isEnabled: chromaticProgress > 0.001
                )
                .blur(radius: normalizedDistance * blurStrength)
        }
        .compositingGroup()
        .blendMode(.plusLighter)
    }
}

extension View {
    func edgeChromaticSwipeEffect(
        viewportMidX: CGFloat,
        coordinateSpaceName: String,
        blurStrength: CGFloat = 5.0,
        edgeThreshold: CGFloat = 0.28,
        maxSampleOffset: CGFloat = 12.0
    ) -> some View {
        modifier(
            EdgeChromaticSwipeEffect(
                viewportMidX: viewportMidX,
                coordinateSpaceName: coordinateSpaceName,
                blurStrength: blurStrength,
                edgeThreshold: edgeThreshold,
                maxSampleOffset: maxSampleOffset
            )
        )
    }
}
