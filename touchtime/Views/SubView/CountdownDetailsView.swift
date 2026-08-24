//
//  CountdownDetailsView.swift
//  touchtime
//
//  Created on 23/08/2026.
//

import SwiftUI
import UIKit

/// Countdown details: a form used to create a new countdown or edit an
/// existing one, with a live preview card, a title plus a calendar date
/// picker.
struct CountdownDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    let onSave: (String, Date, String?) -> Void
    let onDelete: (() -> Void)?
    private let original: CountdownItem?

    @State private var title: String
    @State private var targetDate: Date
    @State private var emoji: String?
    @State private var showDiscardDialog = false
    @State private var showEmojiPicker = false
    @FocusState private var isTitleFocused: Bool

    private var isEditing: Bool {
        original != nil
    }

    init(countdown: CountdownItem? = nil, onDelete: (() -> Void)? = nil, onSave: @escaping (String, Date, String?) -> Void) {
        self.onSave = onSave
        self.onDelete = onDelete
        self.original = countdown
        _title = State(initialValue: countdown?.title ?? "")

        // New countdowns default to tomorrow at 10:00 AM.
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        let defaultDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        _targetDate = State(initialValue: countdown?.targetDate ?? defaultDate)

        _emoji = State(initialValue: countdown?.emoji)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanges: Bool {
        guard let original else { return false }
        return trimmedTitle != original.title
            || targetDate != original.targetDate
            || emoji != original.emoji
    }

    /// Selectable range: a century either side of today keeps the year
    /// picker within sensible bounds.
    private var targetDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()
        let lowerBound = calendar.date(byAdding: .year, value: -100, to: now) ?? now
        let upperBound = calendar.date(byAdding: .year, value: 100, to: now) ?? now
        return lowerBound...upperBound
    }

    var body: some View {
        NavigationStack {
            Form {
                // Live preview of this countdown, styled like the Settings preview card
                Section {
                    VStack(alignment: .center, spacing: 10) {
                        CountdownPreviewCard(
                            title: trimmedTitle,
                            targetDate: targetDate,
                            emoji: emoji
                        ) {
                            triggerHaptic()
                            // Drop the keyboard before the picker comes up
                            isTitleFocused = false
                            showEmojiPicker = true
                        }

                        // Preview Text
                        Text("Preview")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .multilineTextAlignment(.center)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    TextField(String(localized: "Title"), text: $title)
                        .focused($isTitleFocused)
                } header: {
                    Text(String(localized: "Event Name"))
                }

                Section {
                    DatePicker(
                        String(localized: "Date"),
                        selection: $targetDate,
                        in: targetDateRange,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)

                    DatePicker(
                        String(localized: "Time"),
                        selection: $targetDate,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                }
            }
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerSheet(selectedEmoji: $emoji)
            }
            .navigationTitle(isEditing ? "" : String(localized: "New Countdown"))
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                // No explicit save button when editing: commit changes on dismiss.
                guard isEditing, hasChanges, !trimmedTitle.isEmpty else { return }
                onSave(trimmedTitle, targetDate, emoji)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        triggerHaptic()
                        if !isEditing && !trimmedTitle.isEmpty {
                            showDiscardDialog = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .confirmationDialog(
                        String(localized: "Are you sure you want to discard this countdown?"),
                        isPresented: $showDiscardDialog,
                        titleVisibility: .visible
                    ) {
                        Button(String(localized: "Discard"), role: .destructive) {
                            triggerHaptic()
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Menu {
                            if let original {
                                Section {
                                    Text(String(format: String(localized: "Created on %@"), original.createdAt.formatted(.dateTime.year().month().day())))
                                }
                            }

                            Menu {
                                Button(role: .destructive) {
                                    onDelete?()
                                    dismiss()
                                } label: {
                                    Label(String(localized: "Confirm Remove"), systemImage: "checkmark.circle.badge.xmark")
                                }
                            } label: {
                                Label(String(localized: "Remove"), systemImage: "minus.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    } else {
                        Button(role: .confirm) {
                            saveAndDismiss()
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.white)
                        }
                        .disabled(trimmedTitle.isEmpty)
                    }
                }
            }
        }
        .interactiveDismissDisabled(!isEditing && !trimmedTitle.isEmpty)
    }

    private func saveAndDismiss() {
        triggerHaptic()
        onSave(trimmedTitle, targetDate, emoji)
        dismiss()
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}

/// Live preview card for a countdown, styled after the Settings preview
/// card: a happened/happening arrow top-left, event title bottom-left, the
/// day count as a large bare number on the right, and a complication-sized
/// emoji in the middle whose dominant colour fills the card. Also reused on
/// the Home screen; without `onEmojiTap` the emoji is display-only.
struct CountdownPreviewCard: View {
    let title: String
    let targetDate: Date
    let emoji: String?
    /// Reference "now" for the day count; the Home screen passes the
    /// scrubbed time so the number follows Slide to Adjust.
    var now: Date = Date()
    var onEmojiTap: (() -> Void)? = nil

    @Environment(\.colorScheme) private var systemColorScheme

    /// Derived directly from the current emoji (with a cache) so the card
    /// never renders a stale colour when it is reused with new data.
    private var emojiColor: Color? {
        guard let emoji else { return nil }
        return Self.cachedDominantColor(of: emoji)
    }

    private var calendar: Calendar {
        Calendar.current
    }

    /// Whole calendar days from the reference date to the target date;
    /// negative once the event has happened.
    private var dayDifference: Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: targetDate)
        ).day ?? 0
    }

    private var hasHappened: Bool {
        dayDifference < 0
    }

    private var bigText: String {
        dayDifference == 0 ? String(localized: "Today") : "\(abs(dayDifference))"
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 4) {
                // Happened (left arrow) / happening (right arrow) top-left,
                // countdown date top-right
                HStack {
                    Image(systemName: hasHappened ? "arrow.left" : "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .contentTransition(.symbolEffect(.replace))

                    Spacer()

                    Text(targetDate, format: .dateTime.year().month().day())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .contentTransition(.numericText())
                }

                // Event title bottom-left, day count bottom-right
                HStack(alignment: .lastTextBaseline) {
                    Text(title.isEmpty ? String(localized: "Event Name") : title)
                        .font(.headline)
                        .foregroundStyle(title.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 120, alignment: .leading)
                        .blendMode(title.isEmpty ? .plusLighter : .normal)
                        .contentTransition(.numericText())
                        .animation(.spring(), value: title)

                    Spacer()

                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(bigText)
                            .font(.system(size: 36))
                            .fontWeight(.light)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                            .contentTransition(.numericText())

                        // Day unit, hidden when the card reads "Today"
                        if dayDifference != 0 {
                            Text(verbatim: "d")
                                .font(.system(size: 20, weight: .regular, design: .rounded))
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, -4)
            .background(emojiColor)
            .clipShape(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .glassEffect(
                .clear,
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )

            // Complication-sized emoji in the middle; a button only when
            // a tap action is provided (i.e. inside the editor). In
            // display-only mode the badge disappears with the emoji.
            if let onEmojiTap {
                Button(action: onEmojiTap) {
                    emojiBadge
                        .glassEffect(.clear.interactive())
                }
                .buttonStyle(.plain)
            } else if emoji != nil {
                emojiBadge
                    .glassEffect(.clear)
            }
        }
        // The flat colour fill stays mid-dark, so force white text over it.
        .environment(\.colorScheme, emojiColor == nil ? systemColorScheme : .dark)
        .animation(.spring(), value: bigText)
        .animation(.spring(), value: hasHappened)
        .animation(.spring(), value: emoji)
    }

    private var emojiBadge: some View {
        Group {
            if let emoji {
                Text(emoji)
                    .font(.system(size: 36))
            } else {
                Image(systemName: "face.smiling.inverse")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 64, height: 64)
    }

    /// The bitmap analysis is not free and the card re-renders every second
    /// on the Home screen, so computed colours are memoised per emoji.
    /// Main-thread only, like all SwiftUI body evaluation.
    private static var dominantColorCache: [String: Color?] = [:]

    private static func cachedDominantColor(of emoji: String) -> Color? {
        if let cached = dominantColorCache[emoji] {
            return cached
        }
        let color = dominantColor(of: emoji)
        dominantColorCache[emoji] = color
        return color
    }

    /// Downsamples the emoji into a small bitmap and picks its dominant
    /// vibrant colour: each pixel votes for a hue bucket, weighted by how
    /// saturated and bright it is, so a colourful accent wins instead of
    /// the muddy average of every pixel. Falls back to grey for
    /// monochrome emojis.
    private static func dominantColor(of emoji: String) -> Color? {
        let font = UIFont.systemFont(ofSize: 64)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let string = emoji as NSString
        let size = string.size(withAttributes: attributes)
        guard size.width > 0, size.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            string.draw(at: .zero, withAttributes: attributes)
        }
        guard let cgImage = image.cgImage else { return nil }

        // Downsample to a small square; colour statistics don't need detail.
        let dimension = 32
        guard let context = CGContext(
            data: nil,
            width: dimension,
            height: dimension,
            bitsPerComponent: 8,
            bytesPerRow: dimension * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: dimension, height: dimension))
        guard let data = context.data else { return nil }

        let pixels = data.bindMemory(to: UInt8.self, capacity: dimension * dimension * 4)

        let bucketCount = 12
        var bucketWeight = [CGFloat](repeating: 0, count: bucketCount)
        var bucketHue = [CGFloat](repeating: 0, count: bucketCount)
        var bucketSaturation = [CGFloat](repeating: 0, count: bucketCount)
        var bucketBrightness = [CGFloat](repeating: 0, count: bucketCount)
        var greyWeight: CGFloat = 0
        var greyBrightness: CGFloat = 0

        for index in stride(from: 0, to: dimension * dimension * 4, by: 4) {
            let alpha = CGFloat(pixels[index + 3]) / 255
            guard alpha > 0.3 else { continue }

            // Un-premultiply
            let red = min(CGFloat(pixels[index]) / 255 / alpha, 1)
            let green = min(CGFloat(pixels[index + 1]) / 255 / alpha, 1)
            let blue = min(CGFloat(pixels[index + 2]) / 255 / alpha, 1)

            let maxChannel = max(red, green, blue)
            let minChannel = min(red, green, blue)
            let delta = maxChannel - minChannel

            let brightness = maxChannel
            let saturation = maxChannel == 0 ? 0 : delta / maxChannel

            // Washed-out or very dark pixels only count towards the grey fallback.
            guard saturation > 0.2, brightness > 0.2 else {
                greyWeight += alpha
                greyBrightness += brightness * alpha
                continue
            }

            var hue: CGFloat
            if maxChannel == red {
                hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxChannel == green {
                hue = (blue - red) / delta + 2
            } else {
                hue = (red - green) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }

            // Vibrant pixels get a louder vote.
            let weight = alpha * saturation * brightness
            let bucket = min(bucketCount - 1, Int(hue * CGFloat(bucketCount)))
            bucketWeight[bucket] += weight
            bucketHue[bucket] += hue * weight
            bucketSaturation[bucket] += saturation * weight
            bucketBrightness[bucket] += brightness * weight
        }

        if let winner = bucketWeight.indices.max(by: { bucketWeight[$0] < bucketWeight[$1] }),
           bucketWeight[winner] > 0 {
            let weight = bucketWeight[winner]
            let hue = bucketHue[winner] / weight
            let saturation = bucketSaturation[winner] / weight
            let brightness = bucketBrightness[winner] / weight
            // Clamp into a range that stays vivid but keeps white text readable.
            return Color(
                hue: hue,
                saturation: min(max(saturation * 1.15, 0.45), 0.9),
                brightness: min(max(brightness, 0.45), 0.8)
            )
        }

        guard greyWeight > 0 else { return nil }
        return Color(white: min(max(greyBrightness / greyWeight, 0.3), 0.6))
    }
}

/// Grid of common event emojis; the chosen one colours the preview card.
private struct EmojiPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    @Binding var selectedEmoji: String?

    private static let emojis: [String] = [
        "🎂", "🎉", "🎈", "🎁", "🍰", "🥂", "🎊", "🪩",
        "❤️", "💍", "💒", "👶", "🌹", "💌", "💘", "🫶",
        "🎓", "📚", "✏️", "💼", "🏆", "🥇", "🎯", "🧳",
        "✈️", "🏝️", "🗺️", "🚗", "⛺️", "🎡", "🛳️", "🚀",
        "🎄", "🎃", "🧧", "🏮", "🐰", "🦃", "🌕", "🎆",
        "☀️", "🌸", "🍂", "❄️", "⭐️", "🌈", "🔥", "💧",
        "⚽️", "🏀", "🎾", "🏃", "🧘", "🎮", "🎵", "🎬",
        "🏠", "🔑", "💰", "💎", "📅", "⏰", "🔔", "📌"
    ]

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Self.emojis, id: \.self) { option in
                        Button {
                            triggerHaptic()
                            selectedEmoji = option
                        } label: {
                            Text(option)
                                .font(.system(size: 34))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .navigationTitle(String(localized: "Emoji"))
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

                if selectedEmoji != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            triggerHaptic()
                            selectedEmoji = nil
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        // Keep the countdown sheet visible and live behind the picker so
        // the preview card recolours as emojis are tried out.
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}

#Preview {
    CountdownDetailsView { _, _, _ in }
}
