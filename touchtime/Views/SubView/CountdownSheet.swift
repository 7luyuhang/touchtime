//
//  CountdownSheet.swift
//  touchtime
//
//  Created on 20/08/2026.
//

import SwiftUI
import UIKit

struct CountdownSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    @State private var countdowns: [CountdownItem] = CountdownStore.load()
    @State private var showEditorSheet = false
    @State private var editingCountdown: CountdownItem? = nil

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
            CountdownEditorSheet(countdown: item) { title, targetDate in
                updateCountdown(item, title: title, targetDate: targetDate)
            }
        }
        .presentationDetents([.medium, .large])
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
                List {
                    ForEach(sortedCountdowns(at: context.date)) { item in
                        Section {
                            CountdownRow(item: item, now: context.date)
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
                                        triggerHaptic()
                                        editingCountdown = item
                                    } label: {
                                        Label(String(localized: "Edit"), systemImage: "pencil")
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
        }
    }

    /// Upcoming countdowns first (soonest at the top), past dates after (most recent first).
    private func sortedCountdowns(at now: Date) -> [CountdownItem] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        return countdowns.sorted { lhs, rhs in
            let lhsPast = calendar.startOfDay(for: lhs.targetDate) < startOfToday
            let rhsPast = calendar.startOfDay(for: rhs.targetDate) < startOfToday
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
        let normalizedDate = Calendar.current.startOfDay(for: targetDate)
        let item = CountdownItem(id: UUID(), title: title, targetDate: normalizedDate, createdAt: Date())
        withAnimation(.spring()) {
            countdowns.append(item)
        }
        CountdownStore.save(countdowns)
        triggerHaptic()
    }

    private func updateCountdown(_ item: CountdownItem, title: String, targetDate: Date) {
        guard let index = countdowns.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.spring()) {
            countdowns[index].title = title
            countdowns[index].targetDate = Calendar.current.startOfDay(for: targetDate)
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

    private var dayCountText: String {
        if dayDifference == 0 {
            return String(localized: "Today")
        }
        if dayDifference > 0 {
            let unit = dayDifference == 1 ? String(localized: "day") : String(localized: "days")
            return "\(dayDifference) \(unit)"
        }
        let unit = dayDifference == -1 ? String(localized: "day ago") : String(localized: "days ago")
        return "\(-dayDifference) \(unit)"
    }

    private var isTargetInCurrentYear: Bool {
        calendar.isDate(item.targetDate, equalTo: now, toGranularity: .year)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .blendMode(.plusLighter)

            Text(dayCountText)
                .font(.headline)
                .foregroundStyle(.primary)

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
        }
    }
}

/// Form used to create a new countdown or edit an existing one:
/// a title plus a calendar date picker.
private struct CountdownEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    let onSave: (String, Date) -> Void
    private let isEditing: Bool

    @State private var title: String
    @State private var targetDate: Date

    init(countdown: CountdownItem? = nil, onSave: @escaping (String, Date) -> Void) {
        self.onSave = onSave
        self.isEditing = countdown != nil
        _title = State(initialValue: countdown?.title ?? "")
        _targetDate = State(
            initialValue: countdown?.targetDate
                ?? Calendar.current.date(byAdding: .day, value: 1, to: .now)
                ?? .now
        )
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
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
                }
            }
            .navigationTitle(isEditing ? String(localized: "Edit Countdown") : String(localized: "New Countdown"))
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
                        saveAndDismiss()
                    } label: {
                        Image(systemName: isEditing ? "checkmark" : "plus")
                            .foregroundStyle(.white)
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
        }
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
