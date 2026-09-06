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

    private static let buttonSize: CGFloat = 48
    private static let previewCornerRadius: CGFloat = 28

    var body: some View {
        NavigationStack {
            // The card is laid out at its export size and scaled down to
            // fit, so every ratio shows the same card at the same
            // proportions as the file that gets saved.
            GeometryReader { viewport in
                let frame = aspectRatio.size
                let scale = previewScale(for: frame, in: viewport.size)
                snapshotView
                    // Masked before scaling so the rounded corners track
                    // the card exactly while the frame animates.
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: Self.previewCornerRadius / scale,
                            style: .continuous
                        )
                    )
                    .scaleEffect(scale)
                    .frame(width: frame.width * scale, height: frame.height * scale)
                    .frame(width: viewport.size.width, height: viewport.size.height)
            }
            .animation(.spring(duration: 0.25), value: aspectRatio)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
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

    /// The share card at its natural export size; the preview scales this
    /// down and the renderer draws it as is.
    private var snapshotView: some View {
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
            aspectRatio: aspectRatio
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
                Text(aspectRatio.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(), value: aspectRatio)
                    .frame(width: 64, height: Self.buttonSize)
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
