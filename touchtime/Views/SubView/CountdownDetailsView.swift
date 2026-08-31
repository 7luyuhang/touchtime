//
//  CountdownDetailsView.swift
//  touchtime
//
//  Created on 23/08/2026.
//

import SwiftUI
import UIKit
import PhotosUI

/// Countdown details: a form used to create a new countdown or edit an
/// existing one, with a live preview card, a title plus a calendar date
/// picker.
struct CountdownDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    // Time Display settings from the countdown sheet, used by the Share menu.
    @AppStorage("countdownShowYears") private var showYears = false
    @AppStorage("countdownShowMonths") private var showMonths = false
    @AppStorage("countdownShowDays") private var showDays = true

    let onSave: (String, Date, String?, Data?, Bool, CountdownItem.RepeatFrequency, Date?, Int) -> Void
    let onDelete: (() -> Void)?
    private let original: CountdownItem?

    @State private var title: String
    @State private var targetDate: Date
    @State private var emoji: String?
    @State private var photoData: Data?
    @State private var isPinned: Bool
    @State private var repeatFrequency: CountdownItem.RepeatFrequency
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var reminderLeadDays: Int
    @State private var showDiscardDialog = false
    @State private var showCoverPicker = false
    @State private var showNotificationPermissionAlert = false
    /// Bumped on every emoji pick in the cover sheet; the preview card
    /// plays one particle burst per change.
    @State private var emojiParticleBurst = 0
    @FocusState private var isTitleFocused: Bool

    private var isEditing: Bool {
        original != nil
    }

    init(countdown: CountdownItem? = nil, onDelete: (() -> Void)? = nil, onSave: @escaping (String, Date, String?, Data?, Bool, CountdownItem.RepeatFrequency, Date?, Int) -> Void) {
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
        _photoData = State(initialValue: countdown?.photoData)
        _isPinned = State(initialValue: countdown?.isPinned ?? false)
        _repeatFrequency = State(initialValue: countdown?.repeatFrequency ?? .never)

        // Reminders default to 9:00 AM on the day of the event.
        let defaultReminderTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
        _reminderEnabled = State(initialValue: countdown?.reminderTime != nil)
        _reminderTime = State(initialValue: countdown?.reminderTime ?? defaultReminderTime)
        _reminderLeadDays = State(initialValue: countdown?.reminderLeadDays ?? 0)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The reminder time as currently configured in the form; nil when off.
    private var draftReminderTime: Date? {
        reminderEnabled ? reminderTime : nil
    }

    /// Lead days as currently configured; 0 (event day) when the reminder
    /// is off.
    private var draftReminderLeadDays: Int {
        reminderEnabled ? reminderLeadDays : 0
    }

    /// The selectable "remind me X days before" choices.
    private static let reminderLeadDayOptions = [1, 2, 3, 7]

    /// Menu label for a lead-day option, e.g. "1 Day" / "3 Days".
    private func leadDaysLabel(_ days: Int) -> String {
        days == 1
            ? String(localized: "1 Day")
            : String(format: String(localized: "%d Days"), days)
    }

    /// Reminder time for the footer, honouring the 24-hour format setting.
    private var reminderTimeString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if use24HourFormat {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm a"
            formatter.amSymbol = "am"
            formatter.pmSymbol = "pm"
        }
        return formatter.string(from: reminderTime)
    }

    private var hasChanges: Bool {
        guard let original else { return false }
        return trimmedTitle != original.title
            || targetDate != original.targetDate
            || emoji != original.emoji
            || photoData != original.photoData
            || isPinned != original.isPinned
            || repeatFrequency != original.repeatFrequency
            || draftReminderTime != original.reminderTime
            || draftReminderLeadDays != original.reminderLeadDays
    }

    /// What the countdown counts to right now: the picked date, rolled
    /// forward to the next occurrence when it repeats. Drives the preview
    /// card and the Share menu.
    private var effectiveTargetDate: Date {
        CountdownItem.nextOccurrence(of: targetDate, frequency: repeatFrequency, after: Date())
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
                            targetDate: effectiveTargetDate,
                            emoji: emoji,
                            photoData: photoData,
                            isRepeating: repeatFrequency != .never,
                            emojiParticleBurst: emojiParticleBurst
                        ) {
                            triggerHaptic()
                            // Drop the keyboard before the picker comes up
                            isTitleFocused = false
                            showCoverPicker = true
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
                    HStack {
                        TextField(String(localized: "Title"), text: $title)
                            .focused($isTitleFocused)

                        if !title.isEmpty && isTitleFocused {
                            Button {
                                triggerHaptic()
                                title = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .transition(.blurReplace)
                        }
                    }
                    .animation(.spring(), value: !title.isEmpty && isTitleFocused)
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

                    Picker(String(localized: "Repeat"), selection: $repeatFrequency) {
                        ForEach(CountdownItem.RepeatFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    .onChange(of: repeatFrequency) { _, _ in
                        triggerHaptic()
                    }
                }

                Section {
                    TouchTimeToggle(isOn: $reminderEnabled) {
                        Text(String(localized: "Reminder"))
                    }

                    if reminderEnabled {
                        HStack(spacing: 8) {
                            Text(String(localized: "Time"))

                            Spacer()

                            // Lead-day menu: remind 1/2/3/7 days before the
                            // event; picking the current option again goes
                            // back to the event day.
                            Menu {
                                Section(String(localized: "Before")) {
                                    ForEach(Self.reminderLeadDayOptions, id: \.self) { days in
                                        Button {
                                            triggerHaptic()
                                            reminderLeadDays = reminderLeadDays == days ? 0 : days
                                        } label: {
                                            if reminderLeadDays == days {
                                                Label(leadDaysLabel(days), systemImage: "checkmark.circle")
                                            } else {
                                                Text(leadDaysLabel(days))
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.left")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(Color(UIColor.tertiarySystemFill)))
                                    .contentShape(Circle())
                            }

                            DatePicker(
                                "",
                                selection: $reminderTime,
                                displayedComponents: [.hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        }
                    }
                } footer: {
                    if reminderEnabled {
                        if reminderLeadDays == 0 {
                            Text("Get a notification at \(reminderTimeString) on the day of the event.")
                        } else if reminderLeadDays == 1 {
                            Text("Get a notification at \(reminderTimeString), 1 day before the event.")
                        } else {
                            Text("Get a notification at \(reminderTimeString), \(reminderLeadDays) days before the event.")
                        }
                    }
                }
                .animation(.spring(), value: reminderEnabled)

                Section {
                    TouchTimeToggle(isOn: $isPinned) {
                        Text(String(localized: "Pin Countdown"))
                    }
                } footer: {
                    Text(String(localized: "Pinned countdowns will also appear on the Home screen."))
                }
            }
            .sheet(isPresented: $showCoverPicker) {
                CoverPickerSheet(selectedEmoji: $emoji, selectedPhotoData: $photoData) {
                    emojiParticleBurst += 1
                }
            }
            // Background interaction keeps the title field tappable while
            // the picker is up: put the picker away when typing resumes.
            .onChange(of: isTitleFocused) { _, focused in
                if focused {
                    showCoverPicker = false
                }
            }
            // Turning the reminder on needs notification permission; flip
            // the toggle back off when it is denied.
            .onChange(of: reminderEnabled) { _, enabled in
                triggerHaptic()
                guard enabled else { return }
                Task {
                    let granted = await CountdownReminderManager.shared.requestAuthorization()
                    if !granted {
                        await MainActor.run {
                            reminderEnabled = false
                            showNotificationPermissionAlert = true
                        }
                    }
                }
            }
            .alert("Notifications Disabled", isPresented: $showNotificationPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Allow notifications in Settings to get countdown reminders.")
            }
            .navigationTitle(isEditing ? "" : String(localized: "New Countdown"))
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                // No explicit save button when editing: commit changes on dismiss.
                guard isEditing, hasChanges, !trimmedTitle.isEmpty else { return }
                onSave(trimmedTitle, targetDate, emoji, photoData, isPinned, repeatFrequency, draftReminderTime, draftReminderLeadDays)
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
                                // "Created on ..." as the section header so it
                                // renders in the small secondary menu style.
                                Section(String(format: String(localized: "Created on %@"), original.createdAt.formatted(.dateTime.year().month().day()))) {
                                    shareMenu

                                    Divider()

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
                                }
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

    /// Share submenu at the top of the editor menu, sharing the countdown
    /// as it is currently edited (unsaved values included).
    @ViewBuilder
    private var shareMenu: some View {
        let shareTitle = trimmedTitle.isEmpty ? String(localized: "Event Name") : trimmedTitle
        let lazyImage = LazyCardImage { [self] in
            CountdownShare.renderCardImage(
                title: shareTitle,
                targetDate: effectiveTargetDate,
                emoji: emoji,
                photoData: photoData,
                isRepeating: repeatFrequency != .never,
                now: Date(),
                showYears: showYears,
                showMonths: showMonths,
                showDays: showDays
            )
        }
        Menu {
            Button {
                triggerHaptic()
                UIPasteboard.general.string = CountdownShare.copyText(
                    title: shareTitle,
                    targetDate: effectiveTargetDate,
                    now: Date(),
                    showYears: showYears,
                    showMonths: showMonths,
                    showDays: showDays
                )
            } label: {
                Label(String(localized: "Copy as Text"), systemImage: "quote.opening")
            }
            ShareLink(item: lazyImage, preview: SharePreview(shareTitle)) {
                Label(String(localized: "Share as Image"), systemImage: "camera.macro")
            }
        } label: {
            Label(String(localized: "Share"), systemImage: "square.and.arrow.up") // Editor Share
        }
    }

    private func saveAndDismiss() {
        triggerHaptic()
        onSave(trimmedTitle, targetDate, emoji, photoData, isPinned, repeatFrequency, draftReminderTime, draftReminderLeadDays)
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
/// card: a happened/happening arrow (or a repeat symbol for repeating
/// countdowns) top-left, event title bottom-left, the
/// day count as a large bare number on the right, and a complication-sized
/// emoji in the middle whose dominant colour fills the card. Also reused on
/// the Home screen; without `onEmojiTap` the emoji is display-only.
struct CountdownPreviewCard: View {
    let title: String
    let targetDate: Date
    let emoji: String?
    /// Downsampled photo shown in the centre badge instead of the emoji,
    /// with a blurred copy as the card background.
    var photoData: Data? = nil
    /// Reference "now" for the day count; the Home screen passes the
    /// scrubbed time so the number follows Slide to Adjust.
    var now: Date = Date()
    /// True for repeating countdowns; swaps the top-left arrow for a
    /// repeat symbol.
    var isRepeating: Bool = false
    /// Bumped by the editor whenever an emoji is picked in the cover
    /// sheet; each change spawns one particle burst in the card background.
    var emojiParticleBurst: Int = 0
    var onEmojiTap: (() -> Void)? = nil

    @Environment(\.colorScheme) private var systemColorScheme

    /// Derived directly from the current emoji (with a cache) so the card
    /// never renders a stale colour when it is reused with new data.
    private var emojiColor: Color? {
        guard let emoji else { return nil }
        return Self.cachedDominantColor(of: emoji)
    }

    private var photoImage: UIImage? {
        guard let photoData else { return nil }
        return Self.cachedImage(from: photoData)
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

    /// Localized compact day unit: "d" in English, "天" in Chinese.
    private var dayUnit: String {
        String(localized: "d")
    }

    /// PingFang ideographs sink ~0.1em below the Latin baseline (measured
    /// ~1.8pt at 20pt), so the CJK unit needs a lift to sit visually on
    /// the digits' baseline the way the Latin "d" does.
    private var dayUnitBaselineOffset: CGFloat {
        dayUnit.unicodeScalars.contains { $0.properties.isIdeographic } ? 1.8 : 0
    }

    /// The centre badge is present in the editor (always a button) or on
    /// Home when an emoji or photo is set. Without it the title can use
    /// the full width, matching the city rows.
    private var hasCenterBadge: Bool {
        onEmojiTap != nil || emoji != nil || photoData != nil
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 4) {
                // Repeat symbol (repeating) / happened (left arrow) /
                // happening (right arrow) top-left, countdown date top-right
                HStack {
                    Image(systemName: isRepeating ? "repeat" : (hasHappened ? "arrow.left" : "arrow.right"))
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
                        .frame(maxWidth: hasCenterBadge ? 120 : .infinity, alignment: .leading)
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
                            Text(dayUnit)
                                .font(.system(size: 20, weight: .regular, design: .rounded))
                                .baselineOffset(dayUnitBaselineOffset)
                                .transition(.blurReplace)
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, -4)
            .background {
                ZStack {
                    if let photoImage {
                        // Blurred copy of the badge photo instead of the flat
                        // emoji colour; darkened a touch for text contrast.
                        Image(uiImage: photoImage)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 24, opaque: true)
                            .overlay(Color.black.opacity(0.25))
                    } else if let emojiColor {
                        emojiColor
                    }

                    // Editor-only: cover-emoji particles float up the card
                    // background whenever an emoji is picked in the cover
                    // sheet. Mounted regardless of the current cover so the
                    // burst that sets the first emoji still plays.
                    if onEmojiTap != nil {
                        EmojiParticlesView(emoji: emoji, burst: emojiParticleBurst)
                    }
                }
            }
            .clipShape(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .glassEffect(
                .clear,
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )

            // Complication-sized emoji or photo in the middle; a button
            // only when a tap action is provided (i.e. inside the editor).
            // In display-only mode the badge disappears with its content.
            if let onEmojiTap {
                Button(action: onEmojiTap) {
                    centerBadge
                        .glassEffect(.clear.interactive())
                }
                .buttonStyle(.plain)
            } else if emoji != nil || photoData != nil {
                centerBadge
                    .glassEffect(.clear)
            }
        }
        // The flat colour fill / photo stays mid-dark, so force white text.
        .environment(\.colorScheme, emojiColor == nil && photoImage == nil ? systemColorScheme : .dark)
        .animation(.spring(), value: bigText)
        .animation(.spring(), value: hasHappened)
        .animation(.spring(), value: isRepeating)
        .animation(.spring(), value: emoji)
        .animation(.spring(), value: photoData)
    }

    // A ZStack (not a Group) so the frame and the glass effect belong to a
    // stable container and only the glyph inside transitions on change.
    private var centerBadge: some View {
        ZStack {
            if let photoImage, let photoData {
                // Distinct identity per photo so swapping one for another
                // replaces the badge content instead of keeping the old one.
                Image(uiImage: photoImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .id(photoData)
                    .transition(.identity)
            } else if let emoji {
                // Distinct identity per emoji so switching one for another
                // plays the blur replace instead of swapping instantly.
                Text(emoji)
                    .font(.system(size: 36))
                    .id(emoji)
                    .transition(.identity)
            } else {
                Image(systemName: "face.smiling.inverse")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
                    .transition(.identity)
            }
        }
        .frame(width: 64, height: 64)
    }

    /// Decoded badge photos, memoised because the card re-renders every
    /// second on the Home screen. Wiped when it grows past a handful of
    /// entries so abandoned photos don't pile up in memory.
    private static var imageCache: [Data: UIImage] = [:]

    private static func cachedImage(from data: Data) -> UIImage? {
        if let cached = imageCache[data] {
            return cached
        }
        guard let image = UIImage(data: data) else { return nil }
        if imageCache.count > 12 {
            imageCache.removeAll()
        }
        imageCache[data] = image
        return image
    }

    /// The bitmap analysis is not free and the card re-renders every second
    /// on the Home screen, so computed colours are memoised per emoji.
    /// Main-thread only, like all SwiftUI body evaluation.
    private static var dominantColorCache: [String: Color?] = [:]

    static func cachedDominantColor(of emoji: String) -> Color? {
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

/// Cover picker: a grid of common event emojis, the chosen one colouring
/// the preview card, or alternatively a photo from the library that fills
/// the centre badge with a blurred copy as the card background.
private struct CoverPickerSheet: View {
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

    private static let emojis: [String] = [
        "🎂", "🎉", "🎈", "🎁", "🍰", "🥂", "🎊", "🪩",
        "🥳", "🍾", "🧁", "🍻", "🪅", "🎟️", "🎪", "🎇",
        "❤️", "💍", "💒", "👶", "🌹", "💌", "💘", "🫶",
        "🎓", "📚", "✏️", "💼", "🏆", "🥇", "🎯", "🧳",
        "✈️", "🏝️", "🗺️", "🚗", "⛺️", "🎡", "🛳️", "🚀",
        "🛫", "🚄", "🏖️", "🏔️", "🗽", "🗼", "⛩️", "🏰",
        "🎄", "🎃", "🧧", "🏮", "🐰", "🦃", "🌕", "🎆",
        "🪔", "🕎", "☘️", "🎍", "🌅", "🕯️", "🎗️", "🛍️",
        "☀️", "🌸", "🍂", "❄️", "⭐️", "🌈", "🔥", "💧",
        "⚽️", "🏀", "🎾", "🏃", "🧘", "🎮", "🎵", "🎬",
        "🏊", "🚴", "⛷️", "🏂", "⛳️", "🏓", "🥊", "🛹",
        "🎤", "🎸", "🎹", "🎻", "🎭", "🎨", "🎧", "🎫",
        "🍽️", "☕️", "🍕", "🍜", "🍣", "🍦", "🍷", "🧋",
        "📦", "🤝", "📝", "💻", "🩺", "🐶", "🐱", "🧸",
        "🏠", "🔑", "💰", "💎", "📅", "⏰", "🔔", "📌",
        "⏳", "🚩", "📷", "🗳️", "💵", "🪴", "🌙", "🌊"
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

                if selectedEmoji != nil || selectedPhotoData != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            triggerHaptic()
                            if selectedPhotoData != nil {
                                showRemovePhotoDialog = true
                            } else {
                                selectedEmoji = nil
                            }
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
                                selectedEmoji = nil
                                selectedPhotoData = nil
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
                selectedPhotoData = processed
                selectedEmoji = nil
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
    CountdownDetailsView { _, _, _, _, _, _, _, _ in }
}
