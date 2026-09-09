//
//  CoverPickerSheet.swift
//  touchtime
//
//  Created on 09/09/2026.
//

import SwiftUI
import UIKit
import PhotosUI

/// Cover picker: a grid of common event emojis, the chosen one colouring
/// the preview card, or alternatively a photo from the library that fills
/// the centre badge with a blurred copy as the card background. Every
/// countdown keeps an emoji; a photo sits on top of it and is the only
/// cover that can be removed.
///
/// With a photo set, View turns the sheet into a photo editor: the photo
/// starts out filling the whole sheet, like a wallpaper, under a circular
/// window standing in for the badge; it pans by dragging and zooms by
/// pinching, down to just covering the circle. The checkmark keeps that
/// framing (`selectedPhotoCrop`); the photo itself is never altered, so
/// coming back to the editor starts from the full photo again.
struct CoverPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    @Binding var selectedEmoji: String?
    @Binding var selectedPhotoData: Data?
    @Binding var selectedPhotoCrop: CountdownItem.PhotoCrop?
    /// Called on every emoji tap in the grid, after the selection is
    /// applied; the editor uses it to fire the preview particle burst.
    var onEmojiPick: (() -> Void)? = nil

    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showRemovePhotoDialog = false

    // Photo editor. `editingCrop` is the framing being edited; nil for a
    // photo not framed yet, which the editor fits to the sheet it appears
    // in (see `EditorGeometry`) as soon as it is on screen. The gestures
    // report cumulative values, so the previous ones are kept to apply
    // every change as a delta; that way a pan and a pinch going on at the
    // same time compose.
    @State private var isEditingPhoto = false
    @State private var editingCrop: CountdownItem.PhotoCrop?
    @State private var previousPanTranslation: CGSize = .zero
    @State private var previousMagnification: CGFloat = 1

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 8)]

    /// The full cover photo as picked; nil for emoji covers.
    private var photoImage: UIImage? {
        guard let selectedPhotoData else { return nil }
        return CountdownPreviewCard.cachedImage(from: selectedPhotoData)
    }

    /// Bottom bar action on the Cover page: add a photo, or open the
    /// editor for the current one.
    private var bottomBarTitle: String {
        selectedPhotoData == nil ? String(localized: "Add Photo") : String(localized: "View Photo")
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEditingPhoto, let photoImage {
                    photoEditor(image: photoImage)
                        .transition(.blurReplace)
                } else {
                    emojiGrid
                        .transition(.blurReplace)
                }
            }
            .navigationTitle(isEditingPhoto ? String(localized: "Crop") : String(localized: "Cover"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        triggerHaptic()
                        if isEditingPhoto {
                            // Back to the grid, dropping the new framing.
                            exitPhotoEditor()
                        } else {
                            dismiss()
                        }
                    } label: {
                        // Cropping is a step inside the sheet, so it backs
                        // out to the Cover page rather than closing.
                        Image(systemName: isEditingPhoto ? "chevron.left" : "xmark")
                    }
                }

                if isEditingPhoto {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            triggerHaptic()
                            applyCrop()
                        } label: {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                    }
                } else if selectedPhotoData != nil {
                    // Only a photo can be removed; the emoji underneath comes back.
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            triggerHaptic()
                            showRemovePhotoDialog = true
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .confirmationDialog(
                            String(localized: "Are you sure you want to remove this photo?"),
                            isPresented: $showRemovePhotoDialog,
                            titleVisibility: .visible
                        ) {
                            Button(String(localized: "Remove"), role: .destructive) {
                                triggerHaptic()
                                selectedPhotoData = nil
                                selectedPhotoCrop = nil
                                // Photo-only countdowns saved before covers
                                // were mandatory have no emoji to fall back on.
                                if selectedEmoji == nil {
                                    selectedEmoji = CountdownCoverEmojis.random
                                }
                            }
                        }
                    }
                }

                if isEditingPhoto {
                    // Replace sits in the middle of the bar, in plain glass:
                    // the tinted action while cropping is the checkmark.
                    ToolbarSpacer(.flexible, placement: .bottomBar)

                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            triggerHaptic()
                            showPhotoPicker = true
                        } label: {
                            Text(String(localized: "Replace"))
                                .font(.headline)
                                .frame(height: 40)
                        }
                    }

                    ToolbarSpacer(.flexible, placement: .bottomBar)
                } else {
                    ToolbarSpacer(.flexible, placement: .bottomBar)

                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            triggerHaptic()
                            if selectedPhotoData == nil {
                                showPhotoPicker = true
                            } else {
                                enterPhotoEditor()
                            }
                        } label: {
                            Text(bottomBarTitle)
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(height: 40)
                                .contentTransition(.numericText())
                                .animation(.spring(), value: bottomBarTitle)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                    }
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let processed = Self.downsampledJPEGData(from: data) else { return }
                // The emoji stays stored under the photo, so removing the
                // photo later restores it. A new photo starts out unframed,
                // in the editor too if it was swapped in from there.
                selectedPhotoData = processed
                selectedPhotoCrop = nil
                editingCrop = nil
                triggerHaptic()
                photoPickerItem = nil
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        // Keep the countdown sheet visible and live behind the picker so
        // the preview card recolours as emojis are tried out.
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        // Panning the photo in the editor must not pull the sheet down.
        .interactiveDismissDisabled(isEditingPhoto)
    }

    /// The Cover page: the emoji grid.
    private var emojiGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(CountdownCoverEmojis.all, id: \.self) { option in
                    Button {
                        triggerHaptic()
                        selectedEmoji = option
                        selectedPhotoData = nil
                        selectedPhotoCrop = nil
                        onEmojiPick?()
                    } label: {
                        Text(option)
                            .font(.system(size: 36))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .scrollIndicators(.hidden)
    }

    /// The Crop page: the photo across the whole sheet, running
    /// under the bars, with the circular window centred in the space
    /// between them. A fresh photo starts out filling the sheet. Dragging
    /// pans, pinching zooms about the circle's centre, and both are clamped
    /// so the photo never leaves a gap inside the circle.
    private func photoEditor(image: UIImage) -> some View {
        GeometryReader { viewport in
            let geometry = EditorGeometry(viewport: viewport, image: image)
            // Drawn from the resolved framing, so the very first frame is
            // right even before the state has been fitted to the sheet.
            let framing = geometry.resolved(editingCrop)
            let photoSize = geometry.photoSize(at: framing.scale)
            let photo = Image(uiImage: image)
                .resizable()
                .frame(width: photoSize.width, height: photoSize.height)
                .position(geometry.photoCenter(for: framing.offset))

            ZStack {
                photo
                    .blur(radius: 25)

                photo
                    .mask {
                        Circle()
                            .frame(width: geometry.diameter, height: geometry.diameter)
                            .position(geometry.circleCenter)
                    }

                Circle()
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1.0)
                    .frame(width: geometry.diameter, height: geometry.diameter)
                    .position(geometry.circleCenter)
                    .blendMode(.plusLighter)
            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(panGesture(in: geometry).simultaneously(with: pinchGesture(in: geometry)))
            // Fit the framing to this sheet: a fresh photo (also one swapped
            // in from here) gets the sheet-filling start, a saved framing is
            // kept within the editor's bounds.
            .onAppear { editingCrop = geometry.resolved(editingCrop) }
            .onChange(of: geometry) { _, geometry in editingCrop = geometry.resolved(editingCrop) }
            .onChange(of: selectedPhotoData) { _, _ in editingCrop = geometry.resolved(editingCrop) }
        }
        .ignoresSafeArea()
    }

    /// One-finger pan, in circle diameters so the framing stays valid
    /// whatever the viewport.
    private func panGesture(in geometry: EditorGeometry) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let delta = CGSize(
                    width: (value.translation.width - previousPanTranslation.width) / geometry.diameter,
                    height: (value.translation.height - previousPanTranslation.height) / geometry.diameter
                )
                previousPanTranslation = value.translation
                var framing = geometry.resolved(editingCrop)
                framing.offset = geometry.clampedOffset(
                    CGSize(width: framing.offset.width + delta.width, height: framing.offset.height + delta.height),
                    at: framing.scale
                )
                editingCrop = framing
            }
            .onEnded { _ in
                previousPanTranslation = .zero
            }
    }

    /// Pinch to zoom about the circle's centre: the offset grows with the
    /// zoom so the point under the centre stays put.
    private func pinchGesture(in geometry: EditorGeometry) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let delta = value.magnification / previousMagnification
                previousMagnification = value.magnification
                let framing = geometry.resolved(editingCrop)
                let newScale = geometry.clampedScale(framing.scale * delta)
                // Reaching either end of the zoom taps once, like a detent;
                // pinching on against it stays quiet.
                let hitsEnd = newScale == geometry.scaleRange.lowerBound || newScale == geometry.scaleRange.upperBound
                if hitsEnd && newScale != framing.scale {
                    triggerHaptic()
                }
                let growth = newScale / framing.scale
                editingCrop = CountdownItem.PhotoCrop(
                    scale: newScale,
                    offset: geometry.clampedOffset(
                        CGSize(width: framing.offset.width * growth, height: framing.offset.height * growth),
                        at: newScale
                    )
                )
            }
            .onEnded { _ in
                previousMagnification = 1
            }
    }

    /// Opens the editor on the saved framing, if any; a photo without one
    /// gets its sheet-filling start once the editor knows the sheet.
    private func enterPhotoEditor() {
        editingCrop = selectedPhotoCrop
        withAnimation(.spring()) {
            isEditingPhoto = true
        }
    }

    private func exitPhotoEditor() {
        withAnimation(.spring()) {
            isEditingPhoto = false
        }
    }

    /// Keeps the framing and leaves the editor. Only the framing changes;
    /// the photo data stays as picked.
    private func applyCrop() {
        selectedPhotoCrop = editingCrop
        exitPhotoEditor()
    }

    /// The editor's layout in one sheet, and the bounds it keeps a framing
    /// within. The photo is drawn centred on the circle's centre shifted by
    /// the offset (in diameters), at its aspect-fill size for the circle
    /// times the zoom, so the framing reads the same as the stored
    /// `PhotoCrop`.
    private struct EditorGeometry: Equatable {
        let viewportSize: CGSize
        let circleCenter: CGPoint
        let diameter: CGFloat
        let fillAspect: CGSize

        init(viewport: GeometryProxy, image: UIImage) {
            let insets = viewport.safeAreaInsets
            let barsFreeArea = CGRect(
                x: insets.leading,
                y: insets.top,
                width: viewport.size.width - insets.leading - insets.trailing,
                height: viewport.size.height - insets.top - insets.bottom
            )
            viewportSize = viewport.size
            circleCenter = CGPoint(x: barsFreeArea.midX, y: barsFreeArea.midY)
            diameter = CoverPickerSheet.cropDiameter(in: barsFreeArea.size)
            fillAspect = CoverPickerSheet.fillAspect(of: image)
        }

        func photoSize(at scale: CGFloat) -> CGSize {
            CGSize(width: fillAspect.width * diameter * scale, height: fillAspect.height * diameter * scale)
        }

        func photoCenter(for offset: CGSize) -> CGPoint {
            CGPoint(x: circleCenter.x + offset.width * diameter, y: circleCenter.y + offset.height * diameter)
        }

        /// The smallest zoom at which the photo covers the whole sheet.
        var coverScale: CGFloat {
            let fillSize = photoSize(at: 1)
            return max(viewportSize.width / fillSize.width, viewportSize.height / fillSize.height)
        }

        /// Where a fresh photo starts: filling the sheet, centred on it.
        var sheetFillingFraming: CountdownItem.PhotoCrop {
            let centredOnSheet = CGSize(
                width: (viewportSize.width / 2 - circleCenter.x) / diameter,
                height: (viewportSize.height / 2 - circleCenter.y) / diameter
            )
            return CountdownItem.PhotoCrop(scale: coverScale, offset: clampedOffset(centredOnSheet, at: coverScale))
        }

        /// The framing as the editor shows it: the sheet-filling start for
        /// a photo not framed yet, otherwise the framing within bounds.
        func resolved(_ framing: CountdownItem.PhotoCrop?) -> CountdownItem.PhotoCrop {
            guard let framing else { return sheetFillingFraming }
            let scale = clampedScale(framing.scale)
            return CountdownItem.PhotoCrop(scale: scale, offset: clampedOffset(framing.offset, at: scale))
        }

        /// From the photo just covering the circle to three times the
        /// zoom that fills the sheet.
        var scaleRange: ClosedRange<CGFloat> {
            1...(coverScale * 3)
        }

        func clampedScale(_ scale: CGFloat) -> CGFloat {
            min(max(scale, scaleRange.lowerBound), scaleRange.upperBound)
        }

        /// Limits the offset so the photo, at this zoom, still covers the
        /// whole circle: it can shift by half its overhang on each axis.
        func clampedOffset(_ offset: CGSize, at scale: CGFloat) -> CGSize {
            let maxX = (fillAspect.width * scale - 1) / 2
            let maxY = (fillAspect.height * scale - 1) / 2
            return CGSize(
                width: min(max(offset.width, -maxX), maxX),
                height: min(max(offset.height, -maxY), maxY)
            )
        }
    }

    /// Crop circle: 70% of the shorter side of the space between the bars,
    /// leaving photo visible around it for context, capped so it stays
    /// badge-like on wide layouts.
    private static func cropDiameter(in size: CGSize) -> CGFloat {
        min(max(min(size.width, size.height) * 0.7, 1), 260)
    }

    /// The photo's aspect-fill size in circle diameters: the shorter side
    /// spans exactly one diameter at scale 1.
    private static func fillAspect(of image: UIImage) -> CGSize {
        let shortSide = min(image.size.width, image.size.height)
        guard shortSide > 0 else { return CGSize(width: 1, height: 1) }
        return CGSize(width: image.size.width / shortSide, height: image.size.height / shortSide)
    }

    /// Shrinks the picked photo to a size that comfortably covers the badge
    /// and the blurred card background, so the countdown store never holds
    /// multi-megabyte originals. Redrawing also bakes in the orientation.
    private static func downsampledJPEGData(from data: Data, maxDimension: CGFloat = 800) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let largestSide = max(image.size.width, image.size.height)
        guard largestSide > 0 else { return nil }

        let scale = min(1, maxDimension / largestSide)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.75)
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}
