//
//  OnboardingSheet.swift
//  touchtimeWatch
//

import SwiftUI

/// The first launch's welcome: the app's icon, then its tagline, and a
/// button on to the clocks.
struct OnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    /// Brings in the icon, then the tagline, once the sheet appears.
    @State private var hasAppeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image("TouchTimeAppIcon")
                    .resizable()
                    .scaledToFit()
                    // Small enough for Continue to show without scrolling on
                    // 42mm watches, where the tagline wraps to two lines
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                    .animation(.bouncy(duration: 1.0)) { content in
                        content
                            .scaleEffect(hasAppeared ? 1 : 0.5)
                            .opacity(hasAppeared ? 1 : 0)
                    }

                Text("Touch time, right on your wrist.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .animation(.bouncy(duration: 1.0)) { content in
                        content
                            .scaleEffect(hasAppeared ? 1 : 0.5)
                            .opacity(hasAppeared ? 1 : 0)
                    }

                Button("Continue") {
                    dismiss()
                }
                .padding(.top, 16)
            }
            .scenePadding(.navigationBar, edges: .horizontal)
        }
        // Scrolls only on watches too small to fit it all. On 42mm it fits
        // only with Continue down in the bottom corners, outside the safe area.
        .scrollBounceBehavior(.basedOnSize)
        .ignoresSafeArea(edges: .bottom)
        // Continue is the only way on, in place of the sheet's close button
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            hasAppeared = true
        }
    }
}
