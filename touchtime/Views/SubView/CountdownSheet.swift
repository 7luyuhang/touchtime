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
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("countdownShowYears") private var showYears = false
    @AppStorage("countdownShowMonths") private var showMonths = false
    @AppStorage("countdownShowDays") private var showDays = true

    @State private var countdowns: [CountdownItem] = CountdownStore.load()
    @State private var showEditorSheet = false
    @State private var editingCountdown: CountdownItem? = nil
    @State private var selectedDetent: PresentationDetent = .medium
    @State private var filter: CountdownFilter? = nil

    private var unitOptions: CountdownUnitOptions {
        CountdownUnitOptions(years: showYears, months: showMonths, days: showDays)
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
            CountdownEditorSheet { title, targetDate in
                addCountdown(title: title, targetDate: targetDate)
            }
        }
        .sheet(item: $editingCountdown) { item in
            CountdownEditorSheet(countdown: item, onDelete: {
                deleteCountdown(item)
            }) { title, targetDate in
                updateCountdown(item, title: title, targetDate: targetDate)
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
                                Label(String(localized: "Edit"), systemImage: "pencil.tip.crop.circle")
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
        let sorted = sortedCountdowns(at: now)
        switch filter {
        case .happening:
            return sorted.filter { !isPast($0, at: now) }
        case .happened:
            return sorted.filter { isPast($0, at: now) }
        case nil:
            return sorted
        }
    }

    /// Pinned countdowns first, then upcoming ones (soonest at the top),
    /// past dates after (most recent first).
    private func sortedCountdowns(at now: Date) -> [CountdownItem] {
        countdowns.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            let lhsPast = isPast(lhs, at: now)
            let rhsPast = isPast(rhs, at: now)
            if lhsPast != rhsPast {
                return !lhsPast
            }
            if lhsPast {
                return lhs.targetDate > rhs.targetDate
            }
            return lhs.targetDate < rhs.targetDate
        }
    }

    private func addCountdown(title: String, targetDate: Date) {
        let item = CountdownItem(id: UUID(), title: title, targetDate: targetDate, createdAt: Date())
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

    private func updateCountdown(_ item: CountdownItem, title: String, targetDate: Date) {
        guard let index = countdowns.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.spring()) {
            countdowns[index].title = title
            countdowns[index].targetDate = targetDate
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

/// Form used to create a new countdown or edit an existing one:
/// a title plus a calendar date picker.
private struct CountdownEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    let onSave: (String, Date) -> Void
    let onDelete: (() -> Void)?
    private let original: CountdownItem?

    @State private var title: String
    @State private var targetDate: Date
    @State private var showDiscardDialog = false

    private var isEditing: Bool {
        original != nil
    }

    init(countdown: CountdownItem? = nil, onDelete: (() -> Void)? = nil, onSave: @escaping (String, Date) -> Void) {
        self.onSave = onSave
        self.onDelete = onDelete
        self.original = countdown
        _title = State(initialValue: countdown?.title ?? "")

        // New countdowns default to tomorrow at 10:00 AM.
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        let defaultDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        _targetDate = State(initialValue: countdown?.targetDate ?? defaultDate)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanges: Bool {
        guard let original else { return false }
        return trimmedTitle != original.title || targetDate != original.targetDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "Title"), text: $title)
                } header: {
                    Text(String(localized: "Event Name"))
                }

                Section {
                    DatePicker(
                        String(localized: "Date"),
                        selection: $targetDate,
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
            .navigationTitle(isEditing ? "" : String(localized: "New Countdown"))
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                // No explicit save button when editing: commit changes on dismiss.
                guard isEditing, hasChanges, !trimmedTitle.isEmpty else { return }
                onSave(trimmedTitle, targetDate)
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
        onSave(trimmedTitle, targetDate)
        dismiss()
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
