//
//  CountdownSpaceView.swift
//  touchtime
//
//  Created on 01/09/2026.
//

import SwiftUI
import UIKit

/// The Space page of a countdown: everything the user saved for the event
/// (notes and photos) laid out as a two-column grid of square widget-style
/// tiles.
struct CountdownSpaceView: View {
    let countdownID: UUID

    @AppStorage("hapticEnabled") private var hapticEnabled = true

    /// Attachment opened full-size in a viewer sheet.
    @State private var viewedAttachment: SpaceAttachment?

    /// Attachments mid-removal: their card shrinks, blurs and fades while
    /// still holding its slot, so the rest of the grid stays put until
    /// the card is gone.
    @State private var removingAttachmentIDs: Set<UUID> = []

    private let spaceStore = CountdownSpaceStore.shared

    /// How long the context menu takes to settle back onto the card after
    /// "Confirm Remove"; the grid must not move before then.
    private static let contextMenuDismissDuration: TimeInterval = 0.35
    /// Length of the card's vanish animation.
    private static let vanishDuration: TimeInterval = 0.3

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var attachments: [SpaceAttachment] {
        spaceStore.attachments(for: countdownID)
    }

    var body: some View {
        Group {
            if attachments.isEmpty {
                // Blank State
                ContentUnavailableView {
                    Label(String(localized: "Empty Space"), systemImage: "sparkles.rectangle.stack")
                } description: {
                    Text(String(localized: "Keep notes and photos for this countdown."))
                }
                .transition(.blurReplace)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(attachments) { attachment in
                            gridTile(for: attachment)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .sheet(item: $viewedAttachment) { attachment in
            SpaceAttachmentViewer(attachment: attachment)
        }
    }

    /// One grid cell: the square tile with its tap, long-press menu and
    /// the in-place vanish used while it is being removed.
    @ViewBuilder
    private func gridTile(for attachment: SpaceAttachment) -> some View {
        let isRemoving = removingAttachmentIDs.contains(attachment.id)
        SpaceAttachmentTile(attachment: attachment)
            .aspectRatio(1, contentMode: .fit)
            // Vanish in place: shrink towards the centre, blur and fade,
            // keeping the grid slot so nothing else moves yet.
            .scaleEffect(isRemoving ? 0.6 : 1)
            .blur(radius: isRemoving ? 12 : 0)
            .opacity(isRemoving ? 0 : 1)
            .allowsHitTesting(!isRemoving)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .onTapGesture {
                open(attachment)
            }
            .contextMenu {
                contextMenuItems(for: attachment)
            }
            // By the time a card leaves the data it is already invisible,
            // so only insertions animate.
            .transition(AsymmetricTransition(insertion: .blurReplace, removal: .identity))
    }

    /// Tap: opens the attachment full-size in the viewer.
    private func open(_ attachment: SpaceAttachment) {
        triggerHaptic()
        viewedAttachment = attachment
    }

    /// Long-press menu: removal behind a confirmation submenu, matching
    /// the countdown list.
    private func contextMenuItems(for attachment: SpaceAttachment) -> some View {
        Menu {
            Button(role: .destructive) {
                remove(attachment)
            } label: {
                Label(String(localized: "Confirm Remove"), systemImage: "checkmark.circle.badge.xmark")
            }
        } label: {
            Label(String(localized: "Remove"), systemImage: "minus.circle")
        }
    }

    /// Removal in three beats: let the context menu settle back onto the
    /// untouched grid, vanish the card in place, then drop it from the
    /// store so the remaining cards slide into the gap.
    private func remove(_ attachment: SpaceAttachment) {
        triggerHaptic()
        Task {
            try? await Task.sleep(for: .seconds(Self.contextMenuDismissDuration))
            withAnimation(.spring(duration: Self.vanishDuration)) {
                _ = removingAttachmentIDs.insert(attachment.id)
            }

            try? await Task.sleep(for: .seconds(Self.vanishDuration))
            withAnimation(.spring()) {
                spaceStore.remove(attachment.id, from: countdownID)
                removingAttachmentIDs.remove(attachment.id)
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

/// One square widget-style tile in the space grid, styled after the app's
/// glass cards.
private struct SpaceAttachmentTile: View {
    let attachment: SpaceAttachment

    var body: some View {
        ZStack {
            switch attachment.kind {
            case .text:
                textTile
            case .image:
                imageTile
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var textTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)

            Text(attachment.text ?? "")
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .lineLimit(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
    }

    private var imageTile: some View {
        Color.clear
            .overlay {
                if let image = tileImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
    }

    /// Decoded tile photos, memoised because the grid re-renders on every
    /// store change. Keyed by attachment id (the image data of a given
    /// attachment never changes) and wiped when it grows too large.
    private static var imageCache: [UUID: UIImage] = [:]

    private var tileImage: UIImage? {
        guard let data = attachment.imageData else { return nil }
        if let cached = Self.imageCache[attachment.id] {
            return cached
        }
        guard let image = UIImage(data: data) else { return nil }
        if Self.imageCache.count > 24 {
            Self.imageCache.removeAll()
        }
        Self.imageCache[attachment.id] = image
        return image
    }
}

/// Full-size viewer for text and photo attachments, titled with the day
/// the attachment was saved.
private struct SpaceAttachmentViewer: View {
    let attachment: SpaceAttachment

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    var body: some View {
        NavigationStack {
            Group {
                switch attachment.kind {
                case .text:
                    ScrollView {
                        Text(attachment.text ?? "")
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                    }
                    .scrollIndicators(.hidden)
                case .image:
                    if let data = attachment.imageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .padding(20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(attachment.createdAt.formatted(.dateTime.year().month().day()))
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
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}

/// Sheet for saving a note into the space.
struct SpaceNoteEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    let onAdd: (String) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .focused($isFocused)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .navigationTitle(String(localized: "Note"))
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

                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .confirm) {
                            triggerHaptic()
                            onAdd(trimmedText)
                            dismiss()
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.white)
                        }
                        .disabled(trimmedText.isEmpty)
                    }
                }
                // Focusing while the sheet is still animating in brings the
                // keyboard up mid-transition (a bare keyboard frame flashes
                // and the sheet re-lays out around it), so wait for the
                // presentation to settle before raising the keyboard.
                .task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    isFocused = true
                }
        }
        // A single detent: with the keyboard up the editor needs the full
        // height anyway, and it leaves the sheet nothing to jump to.
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}

#Preview {
    CountdownSpaceView(countdownID: UUID())
}
