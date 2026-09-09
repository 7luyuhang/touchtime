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
struct CoverPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    @Binding var selectedEmoji: String?
    @Binding var selectedPhotoData: Data?
    /// Called on every emoji tap in the grid, after the selection is
    /// applied; the editor uses it to fire the preview particle burst.
    var onEmojiPick: (() -> Void)? = nil

    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showRemovePhotoDialog = false

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(CountdownCoverEmojis.all, id: \.self) { option in
                        Button {
                            triggerHaptic()
                            selectedEmoji = option
                            selectedPhotoData = nil
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
            .navigationTitle(String(localized: "Cover"))
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

                // Only a photo can be removed; the emoji underneath comes back.
                if selectedPhotoData != nil {
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
                                // Photo-only countdowns saved before covers
                                // were mandatory have no emoji to fall back on.
                                if selectedEmoji == nil {
                                    selectedEmoji = CountdownCoverEmojis.random
                                }
                            }
                        }
                    }
                }

                ToolbarSpacer(.flexible, placement: .bottomBar)

                ToolbarItem(placement: .bottomBar) {
                    Button {
                        triggerHaptic()
                        showPhotoPicker = true
                    } label: {
                        Text(selectedPhotoData == nil
                            ? String(localized: "Add Photo")
                            : String(localized: "Replace Photo"))
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(height: 40)
                            .contentTransition(.numericText())
                            .animation(.spring(), value: selectedPhotoData == nil)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
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
                // photo later restores it.
                selectedPhotoData = processed
                triggerHaptic()
                photoPickerItem = nil
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        // Keep the countdown sheet visible and live behind the picker so
        // the preview card recolours as emojis are tried out.
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
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

#Preview {
    @Previewable @State var emoji: String? = CountdownCoverEmojis.random
    @Previewable @State var photoData: Data? = nil

    Color.clear
        .sheet(isPresented: .constant(true)) {
            CoverPickerSheet(selectedEmoji: $emoji, selectedPhotoData: $photoData)
        }
}
