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

    /// Photo zoomed open from its card into the full-screen viewer.
    @State private var viewedImage: SpaceAttachment?
    /// Note zoomed open from its card into the editor.
    @State private var editedNote: SpaceAttachment?

    /// Pairs each card with the view that zooms out of it.
    @Namespace private var zoomNamespace

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
        .fullScreenCover(item: $viewedImage) { attachment in
            SpaceImageViewer(attachment: attachment)
                .navigationTransition(.zoom(sourceID: attachment.id, in: zoomNamespace))
        }
        .fullScreenCover(item: $editedNote) { note in
            SpaceNoteEditor(text: note.text ?? "") { newText in
                updateNote(note, text: newText)
            }
            .navigationTransition(.zoom(sourceID: note.id, in: zoomNamespace))
        }
    }

    /// One grid cell: the square tile with its tap, long-press menu and
    /// the in-place vanish used while it is being removed.
    @ViewBuilder
    private func gridTile(for attachment: SpaceAttachment) -> some View {
        let isRemoving = removingAttachmentIDs.contains(attachment.id)
        SpaceAttachmentTile(attachment: attachment)
            .aspectRatio(1, contentMode: .fit)
            // The zoom transition grows out of this card and lands back on
            // it; clip the source to the card's corners so the morph starts
            // and ends rounded.
            .matchedTransitionSource(id: attachment.id, in: zoomNamespace) { source in
                source.clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            // Vanish in place: shrink towards the centre, blur and fade,
            // keeping the grid slot so nothing else moves yet.
            .scaleEffect(isRemoving ? 0.6 : 1)
            .blur(radius: isRemoving ? 12 : 0)
            .opacity(isRemoving ? 0 : 1)
            .allowsHitTesting(!isRemoving)
            // One shape for both hit testing and the context menu preview,
            // so the lifted card keeps the tile's corner radius instead of
            // snapping to the system default.
            .contentShape(
                [.interaction, .contextMenuPreview],
                RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
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

    /// Tap: notes reopen in the editor, photos open full-size in the viewer.
    private func open(_ attachment: SpaceAttachment) {
        triggerHaptic()
        switch attachment.kind {
        case .text:
            editedNote = attachment
        case .image:
            viewedImage = attachment
        }
    }

    private func updateNote(_ note: SpaceAttachment, text: String) {
        withAnimation(.spring()) {
            spaceStore.updateText(text, of: note.id, for: countdownID)
        }
        triggerHaptic()
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

/// One square widget-style tile in the space grid, coloured like a
/// grouped list row so it matches the Detail page's form sections.
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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var textTile: some View {
        Text(attachment.text ?? "")
            .font(.subheadline)
            .multilineTextAlignment(.leading)
            .lineLimit(7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
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

/// Full-size viewer for photo attachments, titled with the day the photo
/// was saved.
private struct SpaceImageViewer: View {
    let attachment: SpaceAttachment

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    var body: some View {
        NavigationStack {
            Group {
                if let data = attachment.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .padding(20)
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
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}

/// Editor for writing a new note into the space (presented as a sheet
/// from the add menu) or editing an existing one (zoomed open from its
/// card). New notes are committed with the add button; edits are
/// committed on dismiss, like the countdown editor.
struct SpaceNoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    /// The note's current text when editing; nil when writing a new one.
    private let original: String?
    let onSave: (String) -> Void

    @State private var text: String
    @FocusState private var isFocused: Bool

    init(text: String? = nil, onSave: @escaping (String) -> Void) {
        self.original = text
        self.onSave = onSave
        _text = State(initialValue: text ?? "")
    }

    private var isEditing: Bool {
        original != nil
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanges: Bool {
        trimmedText != original
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .focused($isFocused)
                .font(.body)
                // Insets go on the scroll content, not the editor: padding
                // the editor itself would pull its frame out from under the
                // navigation bar and hard-clip text there instead of letting
                // it scroll beneath the bar.
                .contentMargins(.horizontal, 14, for: .scrollContent)
                .contentMargins(.top, 8, for: .scrollContent)
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

                    if !isEditing {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(role: .confirm) {
                                triggerHaptic()
                                onSave(trimmedText)
                                dismiss()
                            } label: {
                                Image(systemName: "plus")
                                    .foregroundStyle(.white)
                            }
                            .disabled(trimmedText.isEmpty)
                        }
                    }
                }
                // Only a new note raises the keyboard on arrival; an existing
                // one opens readable, and a tap puts the cursor where editing
                // should start. Focusing while the sheet is still animating in
                // brings the keyboard up mid-transition (a bare keyboard frame
                // flashes and the sheet re-lays out around it), so wait for
                // the presentation to settle first.
                .task {
                    guard !isEditing else { return }
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled else { return }
                    isFocused = true
                }
                .onDisappear {
                    // No explicit save button when editing: commit changes on
                    // dismiss. An emptied note keeps its previous text.
                    guard isEditing, hasChanges, !trimmedText.isEmpty else { return }
                    onSave(trimmedText)
                }
        }
        // For the new-note sheet: a single detent, since with the keyboard
        // up the editor needs the full height anyway, and it leaves the
        // sheet nothing to jump to. No effect on the zoomed full-screen
        // presentation used for editing.
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
