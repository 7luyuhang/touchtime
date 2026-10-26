//
//  LifetimePromoSheet.swift
//  touchtime
//

import SwiftUI

/// Home's occasional invitation to Lifetime, in a medium sheet: the app icon
/// emblem, light circling its edge, over the purchase button.
struct LifetimePromoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    var body: some View {
        NavigationStack {
            AppIconEmblem()
                .chromaticOrbit(rim: AppIconEmblem.plate)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom) {
                    LifetimePurchaseActions {
                        dismiss()
                    }
                    .padding(.horizontal, 24)
                }
                .navigationTitle("Unlock All Features")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            if hapticEnabled {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .fontWeight(.semibold)
                        }
                    }
                }
                .presentationDetents([.medium])
                // Custom background replaces the default Liquid Glass, avoiding
                // its compositing artifacts during interactive dismissal: solid
                // black on top fading to fully transparent at the bottom.
                .presentationBackground {
                    LinearGradient(
                        colors: [.black, .black.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
    }
}
