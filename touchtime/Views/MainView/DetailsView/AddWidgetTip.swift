//
//  AddWidgetTip.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI

/// Suggests adding a widget: tap for the widget intro, or dismiss it for good.
struct AddWidgetTip: View {
    @Binding var isShown: Bool
    @Binding var showsIntroSheet: Bool

    @AppStorage("hapticEnabled") private var hapticEnabled = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "widget.small")
                .font(.headline)
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
                .frame(width: 24, height: 24)

            Text(String(localized: "Add widgets to see the city on Home Screen"))
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "xmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring()) {
                        isShown = false
                    }
                    if hapticEnabled {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(0.10))
                .glassEffect(.clear.interactive(),
                             in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if hapticEnabled {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            showsIntroSheet = true
        }
    }
}
