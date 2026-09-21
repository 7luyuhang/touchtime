//
//  ListDetailArrangement.swift
//  touchtime
//
//  Created on 21/09/2026.
//

import SwiftUI

/// Where a `ListDetailArrangement` put its columns, reported back to the
/// caller so chrome that lives outside the container (bottom controls,
/// backgrounds) can line up with the primary column.
struct ListDetailLayout: Equatable {
    /// Whether the secondary column is currently shown next to the primary.
    var showsSecondary = false
    /// Frame of the primary column in the global coordinate space.
    var primaryFrame: CGRect = .zero
}

/// Shows `primary` on its own, or `primary` and `secondary` side by side
/// when the container is regular width and wider than it is tall.
///
/// On iOS 27.1 the split is an `ArrangementView`, so on iPhone Duo the
/// divider follows the fold and both columns stay clear of it. Earlier
/// systems fall back to an `HStack` that applies the same rules.
struct ListDetailArrangement<Primary: View, Secondary: View>: View {
    /// Whether a second column may be shown at all. Pass `false` for
    /// compact width.
    let allowsSecondary: Bool
    /// Upper bound for the primary column when split. Ignored on displays
    /// with a fold, where the system splits at the hinge instead.
    let maximumPrimaryWidth: CGFloat
    @Binding var layout: ListDetailLayout
    @ViewBuilder let primary: () -> Primary
    @ViewBuilder let secondary: () -> Secondary

    var body: some View {
        if #available(iOS 27.1, *) {
            ArrangedColumns(
                allowsSecondary: allowsSecondary,
                maximumPrimaryWidth: maximumPrimaryWidth,
                layout: $layout,
                primary: primary,
                secondary: secondary
            )
        } else {
            StackedColumns(
                allowsSecondary: allowsSecondary,
                maximumPrimaryWidth: maximumPrimaryWidth,
                layout: $layout,
                primary: primary,
                secondary: secondary
            )
        }
    }
}

// MARK: - iOS 27.1: ArrangementView

/// What `ArrangedColumns` needs to know about its own container.
private nonisolated struct ContainerGeometry: Equatable {
    var width: CGFloat
    var hasFoldRegion: Bool
}

@available(iOS 27.1, *)
private struct ArrangedColumns<Primary: View, Secondary: View>: View {
    let allowsSecondary: Bool
    let maximumPrimaryWidth: CGFloat
    @Binding var layout: ListDetailLayout
    let primary: () -> Primary
    let secondary: () -> Secondary

    /// Width of the whole container, used to tell a split from a single
    /// column.
    @State private var containerWidth: CGFloat = 0
    /// Whether the display can fold (iPhone Duo), whether or not it is
    /// folded right now. Such displays split at the hinge, so the primary
    /// column is not capped there.
    @State private var hasFoldRegion = false

    /// Only ever split side by side: a taller-than-wide container shows the
    /// primary alone instead of stacking the columns. Compact width allows
    /// no axis at all, which also leaves just the primary.
    private var splitAxes: Axis.Set {
        allowsSecondary ? .horizontal : []
    }

    var body: some View {
        ArrangementView {
            primary()
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    layout.primaryFrame = frame
                    layout.showsSecondary = showsSecondary(
                        primaryWidth: frame.width,
                        containerWidth: containerWidth
                    )
                }
                // Must stay the outermost modifier on the primary: the split
                // reads it from its direct child.
                .splitArrangementLayoutSize(
                    maxWidth: hasFoldRegion ? nil : maximumPrimaryWidth
                )
        } secondary: {
            secondary()
        }
        .arrangementViewStyle(.split.axes(splitAxes))
        .onGeometryChange(for: ContainerGeometry.self) { proxy in
            ContainerGeometry(
                width: proxy.size.width,
                hasFoldRegion: !proxy.reservedRegions(
                    kind: .division,
                    options: .includeInactive
                ).isEmpty
            )
        } action: { geometry in
            containerWidth = geometry.width
            hasFoldRegion = geometry.hasFoldRegion
            layout.showsSecondary = showsSecondary(
                primaryWidth: layout.primaryFrame.width,
                containerWidth: geometry.width
            )
        }
    }

    private func showsSecondary(primaryWidth: CGFloat, containerWidth: CGFloat) -> Bool {
        allowsSecondary && primaryWidth > 0 && primaryWidth < containerWidth - 1
    }
}

// MARK: - Earlier systems: HStack

private struct StackedColumns<Primary: View, Secondary: View>: View {
    let allowsSecondary: Bool
    let maximumPrimaryWidth: CGFloat
    @Binding var layout: ListDetailLayout
    let primary: () -> Primary
    let secondary: () -> Secondary

    var body: some View {
        GeometryReader { geometry in
            let isSplit = allowsSecondary && geometry.size.width > geometry.size.height
            let primaryWidth = isSplit
                ? min(maximumPrimaryWidth, geometry.size.width / 2)
                : geometry.size.width

            HStack(spacing: 0) {
                primary()
                    .frame(width: primaryWidth)
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { frame in
                        layout.primaryFrame = frame
                    }

                if isSplit {
                    secondary()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: isSplit, initial: true) { _, isSplit in
                layout.showsSecondary = isSplit
            }
        }
    }
}
