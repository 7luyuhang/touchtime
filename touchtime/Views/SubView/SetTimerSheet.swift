//
//  SetTimerSheet.swift
//  touchtime
//
//  Created on 28/03/2026.
//

import SwiftUI

struct SetTimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("homeTimerName") private var homeTimerName = ""

    let onConfirm: (Int) -> Void
    private let requiresReplacementConfirmation: Bool

    // Remembers the last duration the user confirmed, used as the default for new timers
    private static let lastSetDurationKey = "lastSetTimerDurationSeconds"

    private static let maxDurationSeconds = 59 * 60 + 59
    private static let compactDetent = PresentationDetent.height(300)

    @State private var selectedDuration: Int
    @State private var showReplaceTimerConfirmation = false
    @State private var activeDetent: PresentationDetent = Self.compactDetent
    @State private var recentTimers: [RecentTimer]
    // Name to restore when starting a timer from Recents; nil when starting from the picker
    @State private var pendingTimerName: String? = nil
    // Recent whose play button is awaiting the replace confirmation
    @State private var replaceConfirmationRecentID: UUID? = nil
    @State private var showRenameRecentAlert = false
    @State private var renameRecentNameInput = ""
    @State private var renameTargetRecentID: UUID? = nil

    init(initialDurationSeconds: Int, onConfirm: @escaping (Int) -> Void) {
        let defaultDurationSeconds = 2 * 60
        let lastSetDuration = UserDefaults.standard.integer(forKey: Self.lastSetDurationKey)
        let fallbackDuration = lastSetDuration > 0 ? lastSetDuration : defaultDurationSeconds
        let effectiveDuration = initialDurationSeconds > 0 ? initialDurationSeconds : fallbackDuration
        let clampedDuration = min(max(effectiveDuration, 0), Self.maxDurationSeconds)
        self.onConfirm = onConfirm
        self.requiresReplacementConfirmation = initialDurationSeconds > 0
        _selectedDuration = State(initialValue: clampedDuration)
        _recentTimers = State(initialValue: RecentTimerStore.load())
    }

    private var totalSeconds: Int {
        selectedDuration
    }

    private var selectedMinutes: Int {
        selectedDuration / 60
    }

    private var selectedSeconds: Int {
        selectedDuration % 60
    }

    private var selectedTimeText: String {
        String(format: "%02d:%02d", selectedMinutes, selectedSeconds)
    }

    private var selectedMinutesBinding: Binding<Int> {
        Binding(
            get: { selectedMinutes },
            set: { newValue in
                selectedDuration = newValue * 60 + selectedSeconds
            }
        )
    }

    private var selectedSecondsBinding: Binding<Int> {
        Binding(
            get: { selectedSeconds },
            set: { newValue in
                selectedDuration = selectedMinutes * 60 + newValue
            }
        )
    }

    private var isShowingRecents: Bool {
        activeDetent == .large
    }

    private func startTimerFromPicker() {
        pendingTimerName = nil
        if requiresReplacementConfirmation {
            showReplaceTimerConfirmation = true
        } else {
            confirmTimer()
        }
    }

    private func confirmTimer() {
        if let pendingTimerName {
            homeTimerName = pendingTimerName
        }
        let recordedName = RecentTimerStore.normalizedName(pendingTimerName ?? homeTimerName)
        pendingTimerName = nil

        UserDefaults.standard.set(totalSeconds, forKey: Self.lastSetDurationKey)
        recentTimers = RecentTimerStore.remember(durationSeconds: totalSeconds, name: recordedName)
        onConfirm(totalSeconds)
        dismiss()
    }

    private func startRecentTimer(_ recent: RecentTimer) {
        if hapticEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        selectedDuration = min(max(recent.durationSeconds, 1), Self.maxDurationSeconds)
        pendingTimerName = recent.name ?? ""
        if requiresReplacementConfirmation {
            replaceConfirmationRecentID = recent.id
        } else {
            confirmTimer()
        }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Recents

    private func deleteRecentTimer(_ recent: RecentTimer) {
        recentTimers.removeAll { $0.id == recent.id }
        RecentTimerStore.save(recentTimers)

        if hapticEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func beginRename(for recent: RecentTimer) {
        renameTargetRecentID = recent.id
        renameRecentNameInput = recent.name ?? ""
        showRenameRecentAlert = true
    }

    private func renameTargetRecent() {
        guard let recentID = renameTargetRecentID,
              let index = recentTimers.firstIndex(where: { $0.id == recentID }) else {
            renameRecentNameInput = ""
            renameTargetRecentID = nil
            return
        }

        let trimmedName = renameRecentNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedName = trimmedName.isEmpty ? nil : trimmedName
        let durationSeconds = recentTimers[index].durationSeconds

        recentTimers[index].name = updatedName
        // Keep the same duration + name unique in the list, matching insert behaviour
        recentTimers.removeAll {
            $0.id != recentID && $0.durationSeconds == durationSeconds && $0.name == updatedName
        }
        RecentTimerStore.save(recentTimers)

        renameRecentNameInput = ""
        renameTargetRecentID = nil

        if hapticEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isShowingRecents {
                    recentTimersPage
                        .transition(.blurReplace())
                } else {
                    durationPickerPage
                        .transition(.blurReplace())
                }
            }
            .animation(.smooth(duration: 0.30), value: activeDetent)
            .onChange(of: activeDetent) { _, newValue in
                if newValue == .large && hapticEnabled {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            .navigationTitle(isShowingRecents ? String(localized: "Recents") : String(localized: "New Timer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                if !isShowingRecents {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            startTimerFromPicker()
                        } label: {
                            Image(systemName: "play.fill")
                                .foregroundStyle(totalSeconds == 0 ? .white.opacity(0.50) : .black)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .disabled(totalSeconds == 0)
                        .confirmationDialog(
                            String(localized: "Are you sure you want to replace current timer?"),
                            isPresented: $showReplaceTimerConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button(String(localized: "Replace"), role: .destructive) {
                                confirmTimer()
                            }
                        }
                    }
                }
            }
            .alert(String(localized: "Rename Timer"), isPresented: $showRenameRecentAlert) {
                TextField(String(localized: "Timer"), text: $renameRecentNameInput)
                Button(String(localized: "Cancel"), role: .cancel) {
                    renameRecentNameInput = ""
                    renameTargetRecentID = nil
                }
                Button(String(localized: "Save")) {
                    renameTargetRecent()
                }
            } message: {
                Text(String(localized: "Customize the name of this timer"))
            }
        }
        .presentationDetents([Self.compactDetent, .large], selection: $activeDetent)
        .presentationDragIndicator(.visible)
    }

    private var durationPickerPage: some View {
        VStack {
            ZStack {
                HStack(spacing: 0) {
                    Picker(String(localized: "Minutes"), selection: selectedMinutesBinding) {
                        ForEach(0..<60, id: \.self) { value in
                            Text(String(format: "%02d", value))
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    Picker(String(localized: "Seconds"), selection: selectedSecondsBinding) {
                        ForEach(0..<60, id: \.self) { value in
                            Text(String(format: "%02d", value))
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                HStack(spacing: 0) {
                    Text(String(localized: "min"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 16)
                    Text(String(localized: "sec"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 16)
                }
                .allowsHitTesting(false)
            }
            .frame(height: 200)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var recentTimersPage: some View {
        if recentTimers.isEmpty {
            // Blank State
            ContentUnavailableView {
                Label(String(localized: "No Recent Timers"), systemImage: "timer")
            } description: {
                Text(String(localized: "Timers you start will appear here"))
            }
            .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(recentTimers) { recent in
                    Section {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recent.name ?? String(localized: "Timer"))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .blendMode(.plusLighter)

                                Text(formattedDuration(recent.durationSeconds))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .monospacedDigit()
                            }

                            Spacer()

                            Button {
                                startRecentTimer(recent)
                            } label: {
                                Image(systemName: "play.fill")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.black)
                                    .frame(width: 40, height: 40)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.tint(.white).interactive(), in: Circle())
                            .confirmationDialog(
                                String(localized: "Are you sure you want to replace current timer?"),
                                isPresented: Binding(
                                    get: { replaceConfirmationRecentID == recent.id },
                                    set: { isPresented in
                                        if !isPresented {
                                            replaceConfirmationRecentID = nil
                                        }
                                    }
                                ),
                                titleVisibility: .visible
                            ) {
                                Button(String(localized: "Replace"), role: .destructive) {
                                    confirmTimer()
                                }
                                Button(String(localized: "Cancel"), role: .cancel) {
                                    pendingTimerName = nil
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteRecentTimer(recent)
                            } label: {
                                Label(String(localized: "Remove"), systemImage: "minus.circle.fill")
                            }
                        }
                        .contextMenu {
                            Button {
                                beginRename(for: recent)
                            } label: {
                                Label(String(localized: "Rename"), systemImage: "pencil.tip.crop.circle")
                            }

                            Divider()

                            Menu {
                                Button(role: .destructive) {
                                    deleteRecentTimer(recent)
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
