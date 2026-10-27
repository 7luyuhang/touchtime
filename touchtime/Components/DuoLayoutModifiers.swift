//
//  DuoLayoutModifiers.swift
//  touchtime
//

import SwiftUI

/// Next to a vertical bar (iPhone Duo) a list drops that side's section
/// margin down to the safe area, so its cards run wider than the rest of the
/// screen. Padding the safe area on that side gives the margin back.
@available(iOS 27.1, *)
struct VerticalBarListMargin: ViewModifier {
    let length: CGFloat
    @Environment(\.toolbarVerticalEdge) private var verticalBarEdge

    func body(content: Content) -> some View {
        content.safeAreaPadding(
            verticalBarEdge == .leading ? .leading : .trailing,
            verticalBarEdge == nil ? 0 : length
        )
    }
}

extension View {
    @ViewBuilder
    func verticalBarListMargin(_ length: CGFloat) -> some View {
        if #available(iOS 27.1, *) {
            modifier(VerticalBarListMargin(length: length))
        } else {
            self
        }
    }
}

/// Next to a vertical bar (iPhone Duo) only the home indicator sits at the
/// bottom edge, yet the tab you come back to from the Search tab keeps room
/// for the search field in its bottom safe area until it's shown again.
/// Taking the window's bottom inset instead keeps bottom controls in place.
/// Has to be inside the navigation stack, which takes its insets from UIKit.
@available(iOS 27.1, *)
struct VerticalBarBottomInset: ViewModifier {
    let isActive: Bool
    @Environment(\.toolbarVerticalEdge) private var verticalBarEdge
    @Environment(\.windowBottomInset) private var windowBottomInset

    func body(content: Content) -> some View {
        let applies = isActive && verticalBarEdge != nil
        content
            .safeAreaPadding(.bottom, applies ? windowBottomInset : 0)
            .ignoresSafeArea(.container, edges: applies ? .bottom : [])
    }
}

extension View {
    @ViewBuilder
    func verticalBarBottomInset(isActive: Bool = true) -> some View {
        if #available(iOS 27.1, *) {
            modifier(VerticalBarBottomInset(isActive: isActive))
        } else {
            self
        }
    }
}

/// Fades scrolling content out over its last stretch before the fold between
/// iPhone Duo's stacked panes, so it dissolves into the sky behind them
/// instead of ending in a hard edge. Inactive, the fade closes up and the
/// content shows in full.
struct FoldEdgeFade: ViewModifier {
    let edge: VerticalEdge
    let isActive: Bool

    private static let length: CGFloat = 40

    // Smoothstep opacity ramp: a linear one shows hard bands where the fade
    // starts and ends
    private static let stops: [Gradient.Stop] = (0...8).map { step in
        let location = Double(step) / 8
        return .init(color: .black.opacity(location * location * (3 - 2 * location)), location: location)
    }

    func body(content: Content) -> some View {
        content.mask {
            VStack(spacing: 0) {
                if edge == .top {
                    LinearGradient(stops: Self.stops, startPoint: .top, endPoint: .bottom)
                        .frame(height: isActive ? Self.length : 0)
                }
                Color.black
                if edge == .bottom {
                    LinearGradient(stops: Self.stops, startPoint: .bottom, endPoint: .top)
                        .frame(height: isActive ? Self.length : 0)
                }
            }
            // Also covers what the scroll view draws under its bars
            .ignoresSafeArea()
        }
    }
}

extension View {
    /// For a pane of a split along `splitAxis`: the fade shows while the
    /// panes are stacked, with the fold between them.
    @ViewBuilder
    func foldEdgeFade(_ edge: VerticalEdge, splitAxis: Axis?) -> some View {
        if splitAxis != nil {
            // Kept on either way the panes split: adding or removing it would
            // rebuild the content on every turn of the iPhone, which then
            // vanishes and fades back in during the rotation
            modifier(FoldEdgeFade(edge: edge, isActive: splitAxis == .vertical))
        } else {
            self
        }
    }
}
