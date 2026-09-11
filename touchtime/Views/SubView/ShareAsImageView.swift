//
//  ShareAsImageView.swift
//  touchtime
//
//  Created on 06/09/2026.
//

import SwiftUI
import UIKit
import CoreHaptics
import Photos

/// Frame of a share image. The width is fixed so the card keeps the
/// same size in every ratio; only the backdrop around it grows or
/// shrinks. The raw value doubles as the menu label.
/// Listed tallest first, so the menu reads like a frame getting
/// squarer from top to bottom.
enum ShareAspectRatio: String, CaseIterable {
    case nineBySixteen = "9:16"
    case twoByThree = "2:3"
    case threeByFour = "3:4"
    case oneByOne = "1:1"

    /// Point size of the rendered view; the image is 3x this.
    var size: CGSize {
        switch self {
        case .nineBySixteen: CGSize(width: 360, height: 640)
        case .twoByThree: CGSize(width: 360, height: 540)
        case .threeByFour: CGSize(width: 360, height: 480)
        case .oneByOne: CGSize(width: 360, height: 360)
        }
    }

    /// Proportions of the frame, for drawing it as an icon.
    var widthOverHeight: CGFloat {
        size.width / size.height
    }
}

/// Full-screen share-as-image view for a card (a countdown or a city):
/// the share card centred as a preview, with Aspect Ratio
/// (9:16 / 2:3 / 3:4 / 1:1), Share (system share sheet) and Save (to
/// Photos) as glass buttons underneath.
///
/// The preview is the live share card rather than a rendered bitmap, so
/// changing ratio only resizes the frame around an unchanged backdrop and
/// card instead of swapping one snapshot for another. Saving and sharing
/// render the same card through ImageRenderer.
struct ShareAsImageView<Card: View>: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    /// Last picked frame, remembered across shares.
    @AppStorage("shareAspectRatio") private var aspectRatio: ShareAspectRatio = .nineBySixteen

    /// Title of the share sheet preview.
    let title: String
    /// The card at its export size for a frame, that frame rounded by the
    /// given corner radius; the preview scales this down.
    let card: (_ aspectRatio: ShareAspectRatio, _ frameCornerRadius: CGFloat) -> Card
    /// The card for a frame, rendered into the image that gets saved or
    /// shared.
    let render: (_ aspectRatio: ShareAspectRatio) -> UIImage

    /// Flips the Save arrow to a checkmark for a moment after saving.
    @State private var didSave = false
    @State private var showPhotoAccessAlert = false
    /// Drives the card's bounce-in on appear.
    @State private var animateCard = false
    /// Set once the bounce-in has played, so the entrance blur can leave
    /// the tree.
    @State private var entranceSettled = false
    /// Plays the entrance pattern; kept for the view's lifetime and
    /// stopped on disappear.
    @State private var hapticEngine: CHHapticEngine?

    // Computed rather than stored: generic types can't hold static storage.
    private static var buttonSize: CGFloat { 48 }
    private static var previewCornerRadius: CGFloat { 28 }
    private static var previewOutlineWidth: CGFloat { 1 }
    /// Tallest side of the ratio icon; every frame here is portrait or
    /// square, so the width is what varies.
    private static var ratioIconHeight: CGFloat { 16 }

    init(
        title: String,
        @ViewBuilder card: @escaping (_ aspectRatio: ShareAspectRatio, _ frameCornerRadius: CGFloat) -> Card,
        render: @escaping (_ aspectRatio: ShareAspectRatio) -> UIImage
    ) {
        self.title = title
        self.card = card
        self.render = render
    }

    var body: some View {
        NavigationStack {
            // The card is laid out at its export size and scaled down to
            // fit, so every ratio shows the same card at the same
            // proportions as the file that gets saved.
            GeometryReader { viewport in
                let frame = aspectRatio.size
                let scale = previewScale(for: frame, in: viewport.size)
                // Rounded by the card's own crop, before scaling, so the
                // corners track the frame exactly while it animates.
                card(aspectRatio, Self.previewCornerRadius / scale)
                    .overlay {
                        previewShape(scale: scale)
                            .strokeBorder(
                                .white.opacity(0.1),
                                lineWidth: Self.previewOutlineWidth / scale
                            )
                            .blendMode(.plusLighter)
                    }
                    .scaleEffect(scale)
                    .frame(width: frame.width * scale, height: frame.height * scale)
                    .frame(width: viewport.size.width, height: viewport.size.height)
            }
            .animation(.spring(duration: 0.25), value: aspectRatio)
            .modifier(EntranceBlur(isActive: !entranceSettled, radius: animateCard ? 0 : 10))
            .scaleEffect(animateCard ? 1.0 : 0.5)
            .opacity(animateCard ? 1.0 : 0.0)
            .modifier(EntranceBlur(isActive: !entranceSettled, radius: animateCard ? 0 : 20))
            .offset(y: animateCard ? 0 : 100)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .onAppear {
                guard !animateCard else { return }
                withAnimation(.spring(duration: 0.50)) {
                    animateCard = true
                } completion: {
                    entranceSettled = true
                }
                playEntranceHaptic()
            }
            .onDisappear {
                hapticEngine?.stop()
                hapticEngine = nil
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionButtons
                    .padding(.bottom, 8)
            }
            .navigationTitle(String(localized: "Share as Image"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        triggerHaptic()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .alert(String(localized: "Photo Access Needed"), isPresented: $showPhotoAccessAlert) {
                Button(String(localized: "Open Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "Allow photo library access in Settings to save images."))
            }
        }
    }

    /// Aspect ratio (a capsule showing the current ratio, the way a
    /// camera zoom button shows its factor), share, then save as the
    /// tinted primary action.
    ///
    /// No GlassEffectContainer here: the buttons never merge, and a Menu
    /// inside a container loses its glass while its label morphs into the
    /// menu.
    private var actionButtons: some View {
        HStack(spacing: 10) {
            Menu {
                Section(String(localized: "Aspect Ratio")) {
                    ForEach(ShareAspectRatio.allCases, id: \.self) { ratio in
                        Button {
                            select(ratio)
                        } label: {
                            if ratio == aspectRatio {
                                Label(ratio.rawValue, systemImage: "checkmark.circle")
                            } else {
                                Text(ratio.rawValue)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3.0, style: .continuous)
                        .stroke(lineWidth: 2.0)
                        .frame(
                            width: Self.ratioIconHeight * aspectRatio.widthOverHeight,
                            height: Self.ratioIconHeight
                        )
                        .frame(width: Self.ratioIconHeight)

                    Text(aspectRatio.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .animation(.spring(), value: aspectRatio)
                .frame(width: 85, height: Self.buttonSize)
            }
            .buttonStyle(GlassActionButtonStyle(shape: Capsule(style: .continuous)))

            ShareLink(
                item: LazyCardImage { render(aspectRatio) },
                preview: SharePreview(title)
            ) {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: Self.buttonSize, height: Self.buttonSize)
            }
            .buttonStyle(GlassActionButtonStyle(shape: Circle()))

            Button {
                saveToPhotos()
            } label: {
                Image(systemName: didSave ? "checkmark" : "arrow.down.to.line.compact")
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(.black)
                    .frame(width: Self.buttonSize, height: Self.buttonSize)
            }
            .buttonStyle(GlassActionButtonStyle(shape: Circle(), tint: .white))
        }
        .font(.title3.weight(.medium))
        .foregroundStyle(.primary)
    }

    /// The preview's rounded frame, for the outline; divided by the
    /// preview scale so the radius and outline land at their on-screen
    /// sizes once the card is scaled down.
    private func previewShape(scale: CGFloat) -> RoundedRectangle {
        RoundedRectangle(
            cornerRadius: Self.previewCornerRadius / scale,
            style: .continuous
        )
    }

    /// Scale that fits the card's export frame into the viewport.
    private func previewScale(for frame: CGSize, in available: CGSize) -> CGFloat {
        guard available.width > 0, available.height > 0, frame.width > 0, frame.height > 0 else {
            return 1
        }
        return min(available.width / frame.width, available.height / frame.height)
    }

    private func select(_ ratio: ShareAspectRatio) {
        triggerHaptic()
        aspectRatio = ratio
    }

    /// Saves the card as a PNG into the photo library, asking for
    /// add-only access first; a denied request points at Settings.
    private func saveToPhotos() {
        triggerHaptic()
        guard !didSave else { return }
        let image = render(aspectRatio)
        Task { @MainActor in
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                showPhotoAccessAlert = true
                return
            }
            guard let data = image.pngData() else { return }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .photo, data: data, options: nil)
                }
            } catch {
                return
            }

            if hapticEnabled {
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.prepare()
                notificationFeedback.notificationOccurred(.success)
            }
            withAnimation(.spring()) {
                didSave = true
            }
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.spring()) {
                didSave = false
            }
        }
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }

    /// Plays the entrance pattern in step with the card's bounce-in.
    ///
    /// The engine starts asynchronously so the presentation never waits
    /// on it; a failure anywhere just means a silent entrance.
    private func playEntranceHaptic() {
        guard hapticEnabled, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        Task { @MainActor in
            do {
                let engine = try CHHapticEngine()
                engine.playsHapticsOnly = true
                hapticEngine = engine
                try await engine.start()
                let player = try engine.makePlayer(with: Self.entrancePattern())
                try player.start(atTime: CHHapticTimeImmediate)
            } catch {
                hapticEngine = nil
            }
        }
    }

    /// The card's entrance as felt: a soft swell that follows the spring,
    /// then a light tap as the card lands.
    ///
    /// The bounce-in is a 0.5 s spring without bounce, so the card moves
    /// fastest about 80 ms in (duration / 2π) and is nine tenths of the
    /// way there by 0.3 s. The swell's intensity tracks that motion,
    /// peaking early and fading over the rest of the spring; the tap
    /// marks the moment the card reads as in place.
    private static func entrancePattern() throws -> CHHapticPattern {
        let swell = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.75),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25),
            ],
            relativeTime: 0,
            duration: 0.50
        )
        let swellIntensity = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 0),
                .init(relativeTime: 0.10, value: 0.50),
                .init(relativeTime: 0.50, value: 0),
            ],
            relativeTime: 0
        )
        let landing = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
            ],
            relativeTime: 0.25
        )
        return try CHHapticPattern(events: [swell, landing], parameterCurves: [swellIntensity])
    }
}

/// The preview's bounce-in blurs, removed from the tree instead of being
/// left at radius 0: a zero-radius blur still routes everything under it
/// through an offscreen filter pass on every frame. The swap happens on
/// the animation's completion, when the radius is already 0 and the
/// rebuilt subtree looks identical.
private struct EntranceBlur: ViewModifier {
    let isActive: Bool
    let radius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if isActive {
            content.blur(radius: radius)
        } else {
            content
        }
    }
}

/// Glass for the action row, applied through a button style rather than
/// as a `glassEffect` on the control.
///
/// A `Menu` is itself a button: modifying the Menu (or its label view)
/// with `glassEffect` leaves the glass out of the label the system morphs
/// into the open menu, so the button looks unstyled while the menu is up
/// and snaps back on dismiss. Applied to the style's label it travels
/// with the morph, and `contentShape` keeps the animation on the same
/// shape as the glass instead of starting from a rectangle.
private struct GlassActionButtonStyle<S: Shape>: ButtonStyle {
    let shape: S
    /// Tint for the primary action; nil keeps the neutral glass.
    var tint: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassEffect(glass, in: shape)
            .contentShape(shape)
    }

    private var glass: Glass {
        guard let tint else { return .regular.interactive() }
        return .regular.tint(tint).interactive()
    }
}
