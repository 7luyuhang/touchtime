//
//  CountdownSheet.swift
//  touchtime
//
//  Created on 20/08/2026.
//

import SwiftUI
import UIKit

/// Units shown on each countdown row. Days is the default; years and
/// months can be toggled on additionally, breaking the interval down
/// cumulatively (e.g. 400 days shown as "13 months 4 days").
private struct CountdownUnitOptions {
    var years: Bool
    var months: Bool
    var days: Bool
}

/// List filter: upcoming countdowns (today or later) vs. past ones.
/// `nil` means no filter, showing everything.
private enum CountdownFilter {
    case happening
    case happened
}

struct CountdownSheet: View {
    private enum CountdownSortOrder: String, CaseIterable {
        case newestFirst
        case oldestFirst
    }

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("countdownShowYears") private var showYears = false
    @AppStorage("countdownShowMonths") private var showMonths = false
    @AppStorage("countdownShowDays") private var showDays = true
    @AppStorage("countdownSortOrder") private var countdownSortOrderRawValue = CountdownSortOrder.newestFirst.rawValue

    @State private var countdowns: [CountdownItem] = CountdownStore.load()
    @State private var showEditorSheet = false
    @State private var editingCountdown: CountdownItem? = nil
    @State private var selectedDetent: PresentationDetent = .medium
    @State private var filter: CountdownFilter? = nil

    private var unitOptions: CountdownUnitOptions {
        CountdownUnitOptions(years: showYears, months: showMonths, days: showDays)
    }

    private var countdownSortOrder: CountdownSortOrder {
        CountdownSortOrder(rawValue: countdownSortOrderRawValue) ?? .newestFirst
    }

    private var countdownSortOrderBinding: Binding<CountdownSortOrder> {
        Binding(
            get: {
                countdownSortOrder
            },
            set: { newValue in
                withAnimation(.spring()) {
                    countdownSortOrderRawValue = newValue.rawValue
                }
                triggerHaptic()
            }
        )
    }

    // Each toggle refuses to turn off when it is the last one enabled.
    private var yearsBinding: Binding<Bool> {
        Binding(
            get: {
                showYears
            },
            set: { newValue in
                guard newValue || showMonths || showDays else { return }
                showYears = newValue
                triggerHaptic()
            }
        )
    }

    private var monthsBinding: Binding<Bool> {
        Binding(
            get: {
                showMonths
            },
            set: { newValue in
                guard newValue || showYears || showDays else { return }
                showMonths = newValue
                triggerHaptic()
            }
        )
    }

    private var daysBinding: Binding<Bool> {
        Binding(
            get: {
                showDays
            },
            set: { newValue in
                guard newValue || showYears || showMonths else { return }
                showDays = newValue
                triggerHaptic()
            }
        )
    }

    var body: some View {
        NavigationStack {
            countdownsPage
                .navigationTitle(String(localized: "Countdown"))
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

                    if !countdowns.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Section(String(localized: "Filter")) {
                                    Button {
                                        triggerHaptic()
                                        withAnimation(.spring()) {
                                            filter = filter == .happening ? nil : .happening
                                        }
                                    } label: {
                                        Label(String(localized: "Happening"), systemImage: filter == .happening ? "checkmark.circle" : "")
                                    }

                                    Button {
                                        triggerHaptic()
                                        withAnimation(.spring()) {
                                            filter = filter == .happened ? nil : .happened
                                        }
                                    } label: {
                                        Label(String(localized: "Happened"), systemImage: filter == .happened ? "checkmark.circle" : "")
                                    }
                                }

                                if countdowns.count > 1 {
                                    Section(String(localized: "Sort by")) {
                                        Button {
                                            countdownSortOrderBinding.wrappedValue = .newestFirst
                                        } label: {
                                            if countdownSortOrder == .newestFirst {
                                                Label(String(localized: "Newest First"), systemImage: "checkmark.circle")
                                            } else {
                                                Text(String(localized: "Newest First"))
                                            }
                                        }
                                        Button {
                                            countdownSortOrderBinding.wrappedValue = .oldestFirst
                                        } label: {
                                            if countdownSortOrder == .oldestFirst {
                                                Label(String(localized: "Oldest First"), systemImage: "checkmark.circle")
                                            } else {
                                                Text(String(localized: "Oldest First"))
                                            }
                                        }
                                    }
                                }

                                Section(String(localized: "Time Display")) {
                                    Toggle(String(localized: "Years"), isOn: yearsBinding)
                                    Toggle(String(localized: "Months"), isOn: monthsBinding)
                                    Toggle(String(localized: "Days"), isOn: daysBinding)
                                }

                                Divider()

                                Menu {
                                    Button(role: .destructive) {
                                        removeAllCountdowns()
                                    } label: {
                                        Label(String(localized: "Confirm Remove"), systemImage: "checkmark.circle.badge.xmark")
                                    }
                                } label: {
                                    Label(String(localized: "Remove All"), systemImage: "minus.circle")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                            }
                        }
                    }

                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            triggerHaptic()
                            showEditorSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 40)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
        }
        .sheet(isPresented: $showEditorSheet) {
            CountdownEditorSheet { title, targetDate, emoji in
                addCountdown(title: title, targetDate: targetDate, emoji: emoji)
            }
        }
        .sheet(item: $editingCountdown) { item in
            CountdownEditorSheet(countdown: item, onDelete: {
                deleteCountdown(item)
            }) { title, targetDate, emoji in
                updateCountdown(item, title: title, targetDate: targetDate, emoji: emoji)
            }
            // Force a fresh view identity per item, otherwise SwiftUI reuses
            // the sheet content and @State keeps the previous item's values.
            .id(item.id)
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .onChange(of: selectedDetent) { oldValue, newValue in
            if oldValue == .medium && newValue == .large {
                triggerHaptic()
            }
        }
    }

    @ViewBuilder
    private var countdownsPage: some View {
        if countdowns.isEmpty {
            // Blank State
            ContentUnavailableView {
                Label("No Countdowns", systemImage: "hourglass")
            } description: {
                Text(String(localized: "Create countdowns for your moments"))
            }
            .frame(maxHeight: .infinity)
        } else {
            TimelineView(.everyMinute) { context in
                let displayedItems = displayedCountdowns(at: context.date)
                ZStack {
                    if displayedItems.isEmpty {
                        // All countdowns are hidden by the current filter
                        ContentUnavailableView {
                            Label("No Countdowns", systemImage: "hourglass")
                        } description: {
                            Text(filter == .happened
                                ? String(localized: "No past countdowns.")
                                : String(localized: "No upcoming countdowns."))
                        }
                        .frame(maxHeight: .infinity)
                        .transition(.blurReplace)
                    } else {
                        countdownList(displayedItems, now: context.date)
                            .id(filter)
                            .transition(.blurReplace)
                    }
                }
            }
        }
    }

    private func countdownList(_ items: [CountdownItem], now: Date) -> some View {
        List {
            ForEach(items) { item in
                Section {
                    CountdownRow(item: item, now: now, units: unitOptions)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            triggerHaptic()
                            editingCountdown = item
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteCountdown(item)
                            } label: {
                                Label(String(localized: "Remove"), systemImage: "minus.circle.fill")
                            }
                        }
                        .contextMenu {
                            Button {
                                togglePin(item)
                            } label: {
                                Label(
                                    item.isPinned ? String(localized: "Unpin") : String(localized: "Pin"),
                                    systemImage: item.isPinned ? "pin.slash" : "pin"
                                )
                            }

                            Button {
                                triggerHaptic()
                                editingCountdown = item
                            } label: {
                                Label(String(localized: "Edit"), systemImage: "slider.horizontal.3")
                            }

                            Divider()

                            Menu {
                                Button(role: .destructive) {
                                    deleteCountdown(item)
                                } label: {
                                    Label(String(localized: "Confirm Remove"), systemImage: "checkmark.circle.badge.xmark")
                                }
                            } label: {
                                Label(String(localized: "Remove"), systemImage: "minus.circle")
                            }
                        }
                }
            }
        }
        .listSectionSpacing(12) // List paddings
        .scrollIndicators(.hidden)
    }

    /// Whether the countdown's target date has already passed (before today).
    private func isPast(_ item: CountdownItem, at now: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: item.targetDate) < calendar.startOfDay(for: now)
    }

    /// Sorted countdowns narrowed down by the active filter, if any.
    private func displayedCountdowns(at now: Date) -> [CountdownItem] {
        let sorted = sortedCountdowns
        switch filter {
        case .happening:
            return sorted.filter { !isPast($0, at: now) }
        case .happened:
            return sorted.filter { isPast($0, at: now) }
        case nil:
            return sorted
        }
    }

    /// Pinned countdowns first, then by creation date according to the
    /// selected sort order.
    private var sortedCountdowns: [CountdownItem] {
        countdowns.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            switch countdownSortOrder {
            case .newestFirst:
                return lhs.createdAt > rhs.createdAt
            case .oldestFirst:
                return lhs.createdAt < rhs.createdAt
            }
        }
    }

    private func addCountdown(title: String, targetDate: Date, emoji: String?) {
        let item = CountdownItem(id: UUID(), title: title, targetDate: targetDate, createdAt: Date(), emoji: emoji)
        withAnimation(.spring()) {
            countdowns.append(item)
        }
        CountdownStore.save(countdowns)
        triggerHaptic()
    }

    private func togglePin(_ item: CountdownItem) {
        guard let index = countdowns.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.spring()) {
            countdowns[index].isPinned.toggle()
        }
        CountdownStore.save(countdowns)
        triggerHaptic()
    }

    private func updateCountdown(_ item: CountdownItem, title: String, targetDate: Date, emoji: String?) {
        guard let index = countdowns.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.spring()) {
            countdowns[index].title = title
            countdowns[index].targetDate = targetDate
            countdowns[index].emoji = emoji
        }
        CountdownStore.save(countdowns)
        triggerHaptic()
    }

    private func deleteCountdown(_ item: CountdownItem) {
        withAnimation(.spring()) {
            countdowns.removeAll { $0.id == item.id }
        }
        CountdownStore.save(countdowns)
        triggerHaptic()
    }

    private func removeAllCountdowns() {
        withAnimation(.spring()) {
            countdowns.removeAll()
            filter = nil
        }
        CountdownStore.save(countdowns)
        triggerHaptic()
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}

/// An alarm-style list row showing one countdown.
private struct CountdownRow: View {
    let item: CountdownItem
    let now: Date
    let units: CountdownUnitOptions

    private var calendar: Calendar {
        Calendar.current
    }

    /// Whole calendar days from today to the target date; negative for past dates.
    private var dayDifference: Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: item.targetDate)
        ).day ?? 0
    }

    /// Interval broken down into the enabled units, largest first,
    /// skipping zero components (e.g. "1 year 4 days"). Falls back to
    /// the day count when the target is closer than any enabled unit.
    private var countText: String {
        if dayDifference == 0 {
            return String(localized: "Today")
        }

        var unitSet: Set<Calendar.Component> = []
        if units.years { unitSet.insert(.year) }
        if units.months { unitSet.insert(.month) }
        if units.days { unitSet.insert(.day) }

        let difference = calendar.dateComponents(
            unitSet,
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: item.targetDate)
        )

        var parts: [String] = []
        if let years = difference.year, years != 0 {
            let unit = abs(years) == 1 ? String(localized: "year") : String(localized: "years")
            parts.append("\(abs(years)) \(unit)")
        }
        if let months = difference.month, months != 0 {
            let unit = abs(months) == 1 ? String(localized: "month") : String(localized: "months")
            parts.append("\(abs(months)) \(unit)")
        }
        if let days = difference.day, days != 0 {
            let unit = abs(days) == 1 ? String(localized: "day") : String(localized: "days")
            parts.append("\(abs(days)) \(unit)")
        }

        if parts.isEmpty {
            let unit = abs(dayDifference) == 1 ? String(localized: "day") : String(localized: "days")
            parts.append("\(abs(dayDifference)) \(unit)")
        }

        let joined = parts.joined(separator: " ")
        if dayDifference < 0 {
            return String(format: String(localized: "%@ ago"), joined)
        }
        return joined
    }

    private var isTargetInCurrentYear: Bool {
        calendar.isDate(item.targetDate, equalTo: now, toGranularity: .year)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .blendMode(.plusLighter)
                    .contentTransition(.numericText())

                if item.isPinned {
                    Spacer()

                    Image(systemName: "pin.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .transition(.blurReplace)
                }
            }

            Text(countText)
                .font(.headline)
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Group {
                if isTargetInCurrentYear {
                    Text(item.targetDate, format: .dateTime.month().day())
                } else {
                    Text(item.targetDate, format: .dateTime.year().month().day())
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .blendMode(.plusLighter)
            .contentTransition(.numericText())
        }
    }
}

/// Form used to create a new countdown or edit an existing one: a live
/// preview card, a title plus a calendar date picker.
private struct CountdownEditorSheet: View {
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

/// Live preview card at the top of the countdown details, styled after the
/// Settings preview card: a happened/happening arrow top-left, event title
/// bottom-left, the day count as a large bare number on the right, and a
/// complication-sized button in the middle that picks an emoji whose
/// dominant colour fills the card.
private struct CountdownPreviewCard: View {
    let title: String
    let targetDate: Date
    let emoji: String?
    let onEmojiTap: () -> Void

    @Environment(\.colorScheme) private var systemColorScheme
    @State private var emojiColor: Color? = nil

    private var calendar: Calendar {
        Calendar.current
    }

    /// Whole calendar days from today to the target date; negative once
    /// the event has happened.
    private var dayDifference: Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
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

            // Complication-sized emoji button in the middle
            Button(action: onEmojiTap) {
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
                .glassEffect(.clear.interactive())
            }
            .buttonStyle(.plain)
        }
        // The flat colour fill stays mid-dark, so force white text over it.
        .environment(\.colorScheme, emojiColor == nil ? systemColorScheme : .dark)
        .animation(.spring(), value: bigText)
        .animation(.spring(), value: hasHappened)
        .onChange(of: emoji, initial: true) { _, newValue in
            withAnimation(.spring()) {
                emojiColor = newValue.flatMap { Self.dominantColor(of: $0) }
            }
        }
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
                                .background(
                                    Circle()
                                        .fill(.quaternary)
                                        .opacity(selectedEmoji == option ? 1 : 0)
                                )
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
    CountdownSheet()
}
