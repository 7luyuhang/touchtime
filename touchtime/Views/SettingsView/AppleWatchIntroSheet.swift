import SwiftUI
import UIKit

struct AppleWatchIntroSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                AppleWatchMockupView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.10),
                                .init(color: .black, location: 0.90),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .layoutPriority(1)

                Text("Touch time, right on your wrist.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                openWatchButton
                    .padding(.horizontal, 24)
            }
            .navigationTitle("Apple Watch")
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
                    }
                    .accessibilityLabel(Text("Close"))
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
//        .presentationBackground {
//            LinearGradient(
//                colors: [.black, .black.opacity(0)],
//                startPoint: .top,
//                endPoint: .bottom
//            )
//        }
    }

    private var openWatchButton: some View {
        Button {
            if hapticEnabled {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
            if let url = URL(string: "itms-watchs://") {
                UIApplication.shared.open(url)
            }
        } label: {
            Label("Open Watch App", systemImage: "applewatch.watchface")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .contentShape(Capsule(style: .continuous))
                .glassEffect(.clear.interactive().tint(.white), in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AppleWatchIntroSheet()
}
