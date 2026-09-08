//
//  ShareAsImageView.swift
//  touchtime
//
//  Created on 06/09/2026.
//

import SwiftUI
import UIKit
import Photos

/// Full-screen share-as-image view for a countdown: the share card
/// centred as a preview, with Save (to Photos), Aspect Ratio
/// (9:16 / 3:4 / 1:1) and Share (system share sheet) as glass circle
/// buttons underneath.
///
/// The preview is the live share card rather than a rendered bitmap, so
/// changing ratio only resizes the frame around an unchanged backdrop and
/// card instead of swapping one snapshot for another. Saving and sharing
/// render the same view through ImageRenderer.
struct ShareAsImageView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    /// Last picked frame, remembered across shares.
    @AppStorage("countdownShareAspectRatio") private var aspectRatio: CountdownShare.AspectRatio = .nineBySixteen
    // Time Display settings from the countdown sheet, as the menu shares use.
    @AppStorage("countdownShowYears") private var showYears = false
    @AppStorage("countdownShowMonths") private var showMonths = false
    @AppStorage("countdownShowDays") private var showDays = true

    let title: String
    let targetDate: Date
    let emoji: String?
    let photoData: Data?
    /// True for repeating countdowns; swaps the card's arrow for a
    /// repeat symbol.
    let isRepeating: Bool
    /// Reference "now" for the day count and the footer line.
    var now: Date = Date()

    /// Flips the Save arrow to a checkmark for a moment after saving.
    @State private var didSave = false
    @State private var showPhotoAccessAlert = false
    /// Drives the card's bounce-in on appear.
    @State private var animateCard = false
    /// Set once the bounce-in has played, so the entrance blur can leave
    /// the tree.
    @State private var entranceSettled = false

    private static let buttonSize: CGFloat = 48
    private static let previewCornerRadius: CGFloat = 28
    private static let previewOutlineWidth: CGFloat = 1
    /// Tallest side of the ratio icon; every frame here is portrait or
    /// square, so the width is what varies.
    private static let ratioIconHeight: CGFloat = 16

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
                snapshotView(frameCornerRadius: Self.previewCornerRadius / scale)
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

    /// The share card at its natural export size, its frame rounded for
    /// the preview; the preview scales this down and the renderer draws
    /// the square-cornered card as is.
    private func snapshotView(frameCornerRadius: CGFloat) -> some View {
        CountdownCardSnapshotView(
            title: title,
            targetDate: targetDate,
            emoji: emoji,
            photoData: photoData,
            isRepeating: isRepeating,
            now: now,
            footerText: CountdownShare.footerText(
                from: now,
                to: targetDate,
                showYears: showYears,
                showMonths: showMonths,
                showDays: showDays
            ),
            aspectRatio: aspectRatio,
            frameCornerRadius: frameCornerRadius
        )
        .environment(\.colorScheme, .dark)
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
                    ForEach(CountdownShare.AspectRatio.allCases, id: \.self) { ratio in
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
                item: LazyCardImage { renderImage() },
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

    private func select(_ ratio: CountdownShare.AspectRatio) {
        triggerHaptic()
        aspectRatio = ratio
    }

    private func renderImage() -> UIImage {
        CountdownShare.renderCardImage(
            title: title,
            targetDate: targetDate,
            emoji: emoji,
            photoData: photoData,
            isRepeating: isRepeating,
            now: now,
            showYears: showYears,
            showMonths: showMonths,
            showDays: showDays,
            aspectRatio: aspectRatio
        )
    }

    /// Saves the card as a PNG into the photo library, asking for
    /// add-only access first; a denied request points at Settings.
    private func saveToPhotos() {
        triggerHaptic()
        guard !didSave else { return }
        let image = renderImage()
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
