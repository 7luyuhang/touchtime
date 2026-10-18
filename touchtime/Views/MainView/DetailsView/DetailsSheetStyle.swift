//
//  DetailsSheetStyle.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI

extension View {
    func detailsSheetCardChrome(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(.white.opacity(0.05))
            .blendMode(.plusLighter)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func detailsSheetCard(innerPadding: CGFloat = 16, cornerRadius: CGFloat = 20) -> some View {
        self
            .padding(innerPadding)
            .detailsSheetCardChrome(cornerRadius: cornerRadius)
    }

    func detailsSheetCardRow(horizontalPadding: CGFloat = 16, innerPadding: CGFloat = 16, cornerRadius: CGFloat = 20) -> some View {
        self
            .detailsSheetCard(innerPadding: innerPadding, cornerRadius: cornerRadius)
            .padding(.horizontal, horizontalPadding)
    }

    func horizontalScrollEdgeFade(width: CGFloat = 32) -> some View {
        modifier(HorizontalScrollEdgeFade(fadeWidth: width))
    }
}

/// Fades a horizontal scroll view out at an edge only while content is
/// scrolled past it, growing over the first `fadeWidth` points, so items
/// resting against either edge are never dimmed.
private struct HorizontalScrollEdgeFade: ViewModifier {
    let fadeWidth: CGFloat

    @State private var leadingFadeWidth: CGFloat = 0
    @State private var trailingFadeWidth: CGFloat = 0

    // Smoothstep opacity ramp: a linear one shows hard bands where the fade
    // starts and ends
    private static let fadeStops: [Gradient.Stop] = (0...8).map { step in
        let location = Double(step) / 8
        return .init(color: .black.opacity(location * location * (3 - 2 * location)), location: location)
    }

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                let hiddenLeadingWidth = geometry.contentOffset.x
                return min(max(hiddenLeadingWidth, 0), fadeWidth)
            } action: { _, width in
                leadingFadeWidth = width
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                let hiddenTrailingWidth = geometry.contentSize.width - geometry.containerSize.width - geometry.contentOffset.x
                return min(max(hiddenTrailingWidth, 0), fadeWidth)
            } action: { _, width in
                trailingFadeWidth = width
            }
            .mask {
                HStack(spacing: 0) {
                    LinearGradient(stops: Self.fadeStops, startPoint: .leading, endPoint: .trailing)
                        .frame(width: leadingFadeWidth)
                    Color.black
                    LinearGradient(stops: Self.fadeStops, startPoint: .trailing, endPoint: .leading)
                        .frame(width: trailingFadeWidth)
                }
            }
    }
}
