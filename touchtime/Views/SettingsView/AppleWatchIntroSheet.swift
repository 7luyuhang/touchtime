import SwiftUI
import UIKit

struct AppleWatchIntroSheet: View {
    // Settings presents it full height, like the widget sheet; the Home menus at half height
    var fullHeight = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var showAppleWatchSupport = false
    // The view the watch is showing; taps on its screen move through them
    @State private var screen = AppleWatchPreviewScreen.allCases[0]
    // The page dots and the name pill come in after the watch, like the widget sheet's
    @State private var animateIndicators = false
    // The tagline starts this far up, where the dots and the pill come in
    @State private var indicatorsHeight: CGFloat = 0

    // Apple's guide to downloading watch apps, localized to the language the app is running in
    private var appleWatchSupportURL: URL {
        let region: String
        switch Bundle.main.preferredLocalizations.first {
        case "zh-Hans":
            region = "zh-cn"
        case "zh-Hant":
            region = "zh-tw"
        case "ja":
            region = "ja-jp"
        default:
            region = "en-gb"
        }
        return URL(string: "https://support.apple.com/\(region)/109023")!
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppleWatchMockupView(onScreenChange: { newScreen in
                    // The pill's blur swap only animates when the change itself is animated
                    withAnimation(.smooth(duration: 0.5)) {
                        screen = newScreen
                    }
                })
                    // The camera frames the watch by the view's height, so this
                    // cap sets the watch's size in the full-height sheet.
                    .frame(maxWidth: .infinity, maxHeight: 280)
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

                if fullHeight {
                    VStack(spacing: 0) {
                        // Page dots, same as the widget sheet's
                        HStack(spacing: 8) {
                            ForEach(AppleWatchPreviewScreen.allCases, id: \.self) { page in
                                Circle()
                                    .fill(.primary)
                                    .frame(width: 7, height: 7)
                                    .opacity(screen == page ? 0.9 : 0.3)
                            }
                        }
                        .blendMode(.plusLighter)
                        .padding(.top, 12)
                        .animation(.smooth(duration: 0.3), value: screen)

                        // Current view's name in a glass capsule, swapping with a
                        // blur as taps on the watch move through the views.
                        Text(screen.title)
                            .font(.subheadline.weight(.semibold))
                            .transition(.blurReplace)
                            .id(screen)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .glassEffect(.clear, in: Capsule(style: .continuous))
                            .padding(.top, 24)
                    }
                    .blur(radius: animateIndicators ? 0 : 10)
                    .opacity(animateIndicators ? 1.0 : 0.0)
                    // Waits for the tagline to move out of the way
                    .animation(.smooth(duration: 1.0).delay(0.3), value: animateIndicators)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        indicatorsHeight = height
                    }
                }

                Text("Touch time, right on your wrist.")
                    .font(fullHeight ? .headline : .subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, fullHeight ? 24 : 12)
                    .padding(.bottom, 24)
                    .offset(y: animateIndicators ? 0 : -indicatorsHeight)
                    .animation(.smooth(duration: 1.0), value: animateIndicators)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                openWatchButton
                    .padding(.horizontal, 24)
            }
            .background {
                // Twinkling dot matrix, same as the onboarding's
                if fullHeight {
                    DotMatrixOverlay()
                        .ignoresSafeArea()
                        .blendMode(.plusLighter)
                        .opacity(0.75)
                }
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

                // Tips: Apple guide on downloading apps on Apple Watch
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        showAppleWatchSupport = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    animateIndicators = true
                }
            }
            .sheet(isPresented: $showAppleWatchSupport) {
                SafariView(url: appleWatchSupportURL)
                    .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents(fullHeight ? [.large] : [.medium])
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
