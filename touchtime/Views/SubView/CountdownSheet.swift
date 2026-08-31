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

    /// Free users can keep up to this many countdowns; more requires lifetime access.
    private static let freeCountdownLimit = 3

    @Environment(\.dismiss) private var dismiss
    @Environment(CountdownStore.self) private var countdownStore
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("hasLifetimeAccess") private var hasLifetimeAccess = false
    @AppStorage("countdownShowYears") private var showYears = false
    @AppStorage("countdownShowMonths") private var showMonths = false
    @AppStorage("countdownShowDays") private var showDays = true
    @AppStorage("countdownSortOrder") private var countdownSortOrderRawValue = CountdownSortOrder.newestFirst.rawValue

    @State private var showEditorSheet = false
    @State private var showLifetimeStore = false
    @State private var editingCountdown: CountdownItem? = nil
    @State private var filter: CountdownFilter? = nil

    /// Read-only convenience over the shared store.
    private var countdowns: [CountdownItem] {
        countdownStore.countdowns
    }

    private var hasReachedFreeLimit: Bool {
        !hasLifetimeAccess && countdowns.count >= Self.freeCountdownLimit
    }

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
                            if hasReachedFreeLimit {
                                triggerWarningHaptic()
                                showLifetimeStore = true
                            } else {
                                triggerHaptic()
                                showEditorSheet = true
                            }
                        } label: {
                            Image(systemName: hasReachedFreeLimit ? "lock.fill" : "plus")
                                .font(.headline)
                                .foregroundStyle(hasReachedFreeLimit ? .black : .white)
                                .frame(width: 60, height: 40)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(hasReachedFreeLimit ? .yellow : .blue)
                        // Toolbar caches the button's tint; force a rebuild when
                        // the locked state flips so the background color updates.
                        .id(hasReachedFreeLimit)
                    }
                }
        }
        .sheet(isPresented: $showEditorSheet) {
            CountdownDetailsView { title, targetDate, emoji, photoData, isPinned, repeatFrequency, reminderTime, reminderLeadDays in
                addCountdown(title: title, targetDate: targetDate, emoji: emoji, photoData: photoData, isPinned: isPinned, repeatFrequency: repeatFrequency, reminderTime: reminderTime, reminderLeadDays: reminderLeadDays)
            }
        }
        .sheet(item: $editingCountdown) { item in
            CountdownDetailsView(countdown: item, onDelete: {
                deleteCountdown(item)
            }) { title, targetDate, emoji, photoData, isPinned, repeatFrequency, reminderTime, reminderLeadDays in
                updateCountdown(item, title: title, targetDate: targetDate, emoji: emoji, photoData: photoData, isPinned: isPinned, repeatFrequency: repeatFrequency, reminderTime: reminderTime, reminderLeadDays: reminderLeadDays)
            }
            // Force a fresh view identity per item, otherwise SwiftUI reuses
            // the sheet content and @State keeps the previous item's values.
            .id(item.id)
        }
        .sheet(isPresented: $showLifetimeStore) {
            NavigationStack {
                LifetimeStoreView()
            }
        }
        .presentationDetents([.large])
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
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                togglePin(item)
                            } label: {
                                Label(
                                    item.isPinned ? String(localized: "Unpin") : String(localized: "Pin"),
                                    systemImage: item.isPinned ? "pin.slash.fill" : "pin.fill"
                                )
                            }
                            .tint(item.isPinned ? .orange : .blue)
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

            if hasReachedFreeLimit {
                Text(String(localized: "Upgrade to add more countdowns"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets(top:4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listSectionSpacing(12) // List paddings
        // Let the upgrade hint row shrink below the standard 44pt row height;
        // countdown rows are taller than that, so they're unaffected.
        .environment(\.defaultMinListRowHeight, 0)
        .scrollIndicators(.hidden)
    }

    /// Whether the countdown's target date has already passed (before
    /// today). Repeating countdowns roll forward, so they never count as
    /// past.
    private func isPast(_ item: CountdownItem, at now: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: item.effectiveTargetDate(at: now)) < calendar.startOfDay(for: now)
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

    private func addCountdown(title: String, targetDate: Date, emoji: String?, photoData: Data?, isPinned: Bool, repeatFrequency: CountdownItem.RepeatFrequency, reminderTime: Date?, reminderLeadDays: Int) {
        let item = CountdownItem(id: UUID(), title: title, targetDate: targetDate, createdAt: Date(), isPinned: isPinned, repeatFrequency: repeatFrequency, emoji: emoji, photoData: photoData, reminderTime: reminderTime, reminderLeadDays: reminderLeadDays)
        withAnimation(.spring()) {
            countdownStore.countdowns.append(item)
        }
        triggerHaptic()
    }

    private func togglePin(_ item: CountdownItem) {
        guard let index = countdownStore.countdowns.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.spring()) {
            countdownStore.countdowns[index].isPinned.toggle()
        }
        triggerHaptic()
    }

    private func updateCountdown(_ item: CountdownItem, title: String, targetDate: Date, emoji: String?, photoData: Data?, isPinned: Bool, repeatFrequency: CountdownItem.RepeatFrequency, reminderTime: Date?, reminderLeadDays: Int) {
        guard let index = countdownStore.countdowns.firstIndex(where: { $0.id == item.id }) else { return }
        // Assemble the edited item first so the store (and UserDefaults)
        // sees a single mutation instead of one per field.
        var updated = countdownStore.countdowns[index]
        updated.title = title
        updated.targetDate = targetDate
        updated.emoji = emoji
        updated.photoData = photoData
        updated.isPinned = isPinned
        updated.repeatFrequency = repeatFrequency
        updated.reminderTime = reminderTime
        updated.reminderLeadDays = reminderLeadDays
        withAnimation(.spring()) {
            countdownStore.countdowns[index] = updated
        }
        triggerHaptic()
    }

    private func deleteCountdown(_ item: CountdownItem) {
        withAnimation(.spring()) {
            countdownStore.countdowns.removeAll { $0.id == item.id }
        }
        triggerHaptic()
    }

    private func removeAllCountdowns() {
        withAnimation(.spring()) {
            countdownStore.countdowns.removeAll()
            filter = nil
        }
        triggerHaptic()
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }

    private func triggerWarningHaptic() {
        guard hapticEnabled else { return }
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(.error)
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

    /// Stored date for one-off countdowns, next occurrence for repeating ones.
    private var effectiveTargetDate: Date {
        item.effectiveTargetDate(at: now)
    }

    /// Whole calendar days from today to the target date; negative for past dates.
    private var dayDifference: Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: effectiveTargetDate)
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
            to: calendar.startOfDay(for: effectiveTargetDate)
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
        calendar.isDate(effectiveTargetDate, equalTo: now, toGranularity: .year)
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

            // Repeat symbol ahead of the date for repeating countdowns
            HStack(spacing: 4) {
                if item.repeatFrequency != .never {
                    Image(systemName: "repeat")
                        .font(.footnote.weight(.semibold))
                        .transition(.blurReplace)
                }

                if isTargetInCurrentYear {
                    Text(effectiveTargetDate, format: .dateTime.month().day())
                } else {
                    Text(effectiveTargetDate, format: .dateTime.year().month().day())
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .blendMode(.plusLighter)
            .contentTransition(.numericText())
        }
    }
}

#Preview {
    CountdownSheet()
        .environment(CountdownStore())
}
