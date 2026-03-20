//
//  SetAlarmSheet.swift
//  touchtime
//
//  Created on 17/03/2026.
//

import SwiftUI
import AlarmKit
import UIKit

struct SetAlarmSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var alarmRecords: [AlarmRecord] = []
    @State private var authorizationState: AlarmManager.AuthorizationState = AlarmManager.shared.authorizationState
    @State private var errorMessage = ""
    @State private var showErrorAlert = false
    @State private var showPermissionAlert = false
    @State private var showRemoveAllConfirmationDialog = false
    @State private var showRenameEventAlert = false
    @State private var renameEventTitleInput = ""
    @State private var renameTargetRecordID: UUID? = nil
    @State private var alarmUpdatesTask: Task<Void, Never>? = nil

    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    private let alarmManager = AlarmManager.shared

    private var sortedRecords: [AlarmRecord] {
        alarmRecords.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            alarmsPage
            .navigationTitle(String(localized: "Alarms"))
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

                if !alarmRecords.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                showRemoveAllConfirmationDialog = true
                            } label: {
                                Label(String(localized: "Remove All"), systemImage: "minus.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                        .confirmationDialog(
                            String(localized: "Are you sure want to remove all alarms?"),
                            isPresented: $showRemoveAllConfirmationDialog,
                            titleVisibility: .visible
                        ) {
                            Button(String(localized: "Confirm Remove"), role: .destructive) {
                                deleteAllRecords()
                            }
                        }
                    }
                }
            }
        }
        .task {
            await prepareSheet()
        }
        .onDisappear {
            alarmUpdatesTask?.cancel()
            alarmUpdatesTask = nil
        }
        .alert(String(localized: "Alarm Permission Needed"), isPresented: $showPermissionAlert) {
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Go to Settings")) {
                AlarmSupport.openSystemSettings()
            }
        } message: {
            Text(String(localized: "Please allow alarm access in Settings to create alarms."))
        }
        .alert(String(localized: "Alarm Error"), isPresented: $showErrorAlert) {
            Button(String(localized: "Done"), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert(String(localized: "Event Title"), isPresented: $showRenameEventAlert) {
            TextField(String(localized: "Optional"), text: $renameEventTitleInput)
            Button(String(localized: "Cancel")) {
                renameEventTitleInput = ""
                renameTargetRecordID = nil
            }
            Button(String(localized: "Rename")) {
                Task {
                    await renameTargetRecord()
                }
            }
        } message: {
            Text(String(localized: "Enter the event title for this alarm."))
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var alarmsPage: some View {
        if sortedRecords.isEmpty {
            ContentUnavailableView {
                Label("No Alarms", systemImage: "alarm")
            }
            .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(sortedRecords) { record in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            if let eventTitle = normalizedEventTitle(for: record) {
                                Text(eventTitle)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .contentTransition(.numericText())
                                    .animation(.smooth(duration: 0.25), value: eventTitle)
                                    .blendMode(.plusLighter)
                            }
                            
                            Text(formattedTime(hour: record.hour, minute: record.minute))
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            if let cityName = sourceCityDisplayName(for: record),
                               let cityHour = record.sourceCityHour,
                               let cityMinute = record.sourceCityMinute {
                                Text("\(cityName) · \(formattedTime(hour: cityHour, minute: cityMinute))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .blendMode(.plusLighter)
                            }
                        }
                        Spacer()
                        Toggle(
                            "",
                            isOn: bindingForToggle(recordID: record.id)
                        )
                        .labelsHidden()
                        .tint(.blue) // Toggle Colour
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteRecord(record)
                        } label: {
                            Label(String(localized: "Remove"), systemImage: "minus.circle.fill")
                        }
                    }
                    .contextMenu {
                        Button {
                            beginRename(for: record)
                        } label: {
                            Label(String(localized: "Rename Event"), systemImage: "pencil.tip.crop.circle")
                        }

                        Button(role: .destructive) {
                            deleteRecord(record)
                        } label: {
                            Label(String(localized: "Remove"), systemImage: "minus.circle")
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .listStyle(.insetGrouped)
        }
    }

    @MainActor
    private func prepareSheet() async {
        loadAlarmRecords()
        authorizationState = alarmManager.authorizationState
        synchronizeWithSystemAlarms()
        startAlarmUpdatesObserver()
    }

    private func bindingForToggle(recordID: UUID) -> Binding<Bool> {
        Binding(
            get: {
                alarmRecords.first(where: { $0.id == recordID })?.isEnabled ?? false
            },
            set: { newValue in
                Task {
                    await updateRecordEnabled(recordID: recordID, isEnabled: newValue)
                }
            }
        )
    }

    @MainActor
    private func updateRecordEnabled(recordID: UUID, isEnabled: Bool) async {
        guard let index = alarmRecords.firstIndex(where: { $0.id == recordID }) else { return }

        alarmRecords[index].isEnabled = isEnabled
        saveAlarmRecords()

        if isEnabled {
            guard await ensureAuthorizationForAlarmActions() else {
                alarmRecords[index].isEnabled = false
                saveAlarmRecords()
                return
            }

            await scheduleAndSync(record: alarmRecords[index])
            triggerHaptic()
            return
        }

        do {
            try alarmManager.cancel(id: recordID)
            synchronizeWithSystemAlarms()
            triggerHaptic()
        } catch {
            alarmRecords[index].isEnabled = true
            saveAlarmRecords()
            presentError(error)
        }
    }

    @MainActor
    private func scheduleAndSync(record: AlarmRecord) async {
        do {
            // Avoid duplicate-ID failures if a system alarm with the same ID still exists.
            try? alarmManager.cancel(id: record.id)

            try await AlarmSupport.scheduleAlarm(
                id: record.id,
                hour: record.hour,
                minute: record.minute,
                eventTitle: record.eventTitle,
                using: alarmManager
            )
        } catch {
            if let index = alarmRecords.firstIndex(where: { $0.id == record.id }) {
                alarmRecords[index].isEnabled = false
                saveAlarmRecords()
            }
            presentError(error)
        }
    }

    @MainActor
    private func ensureAuthorizationForAlarmActions() async -> Bool {
        switch await AlarmSupport.ensureAuthorization(using: alarmManager) {
        case .authorized:
            authorizationState = .authorized
            return true
        case .denied:
            authorizationState = alarmManager.authorizationState
            showPermissionAlert = true
            return false
        case .failed(let error):
            authorizationState = alarmManager.authorizationState
            presentError(error)
            return false
        }
    }

    @MainActor
    private func synchronizeWithSystemAlarms() {
        do {
            let activeAlarmIDs = Set(try alarmManager.alarms.map(\.id))
            var didChange = false

            for index in alarmRecords.indices {
                let shouldBeEnabled = activeAlarmIDs.contains(alarmRecords[index].id)
                if alarmRecords[index].isEnabled != shouldBeEnabled {
                    alarmRecords[index].isEnabled = shouldBeEnabled
                    didChange = true
                }
            }

            if didChange {
                saveAlarmRecords()
            }
        } catch {
            // Ignore if AlarmKit data is temporarily unavailable.
        }
    }

    @MainActor
    private func synchronizeWithAlarmUpdates(_ alarms: [Alarm]) {
        let activeAlarmIDs = Set(alarms.map(\.id))
        var didChange = false

        for index in alarmRecords.indices {
            let shouldBeEnabled = activeAlarmIDs.contains(alarmRecords[index].id)
            if alarmRecords[index].isEnabled != shouldBeEnabled {
                alarmRecords[index].isEnabled = shouldBeEnabled
                didChange = true
            }
        }

        if didChange {
            saveAlarmRecords()
        }
    }

    @MainActor
    private func startAlarmUpdatesObserver() {
        alarmUpdatesTask?.cancel()

        alarmUpdatesTask = Task {
            for await alarms in alarmManager.alarmUpdates {
                await MainActor.run {
                    synchronizeWithAlarmUpdates(alarms)
                }
            }
        }
    }

    private func formattedTime(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let calendar = Calendar.current
        let date = calendar.date(from: components) ?? Date()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = use24HourFormat ? "HH:mm" : "h:mm a"

        if use24HourFormat {
            return formatter.string(from: date)
        }

        return formatter.string(from: date).lowercased()
    }

    private func normalizedEventTitle(for record: AlarmRecord) -> String? {
        let trimmedTitle = record.eventTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedTitle, !trimmedTitle.isEmpty else { return nil }
        return trimmedTitle
    }

    private func sourceCityDisplayName(for record: AlarmRecord) -> String? {
        if let customName = normalizedText(record.sourceCityCustomName) {
            return customName
        }

        if let timeZoneIdentifier = normalizedText(record.sourceCityTimeZoneIdentifier) {
            let cityKey = originalCityName(from: timeZoneIdentifier)
            return String(localized: String.LocalizationValue(cityKey))
        }

        if let legacyCityName = normalizedText(record.sourceCityName) {
            return String(localized: String.LocalizationValue(legacyCityName))
        }

        return nil
    }

    private func originalCityName(from timeZoneIdentifier: String) -> String {
        let components = timeZoneIdentifier.split(separator: "/")
        if components.count >= 2 {
            return components.last!.replacingOccurrences(of: "_", with: " ")
        }

        return String(components.first ?? "")
    }

    private func normalizedText(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    @MainActor
    private func loadAlarmRecords() {
        alarmRecords = AlarmSupport.loadRecords()
    }

    private func saveAlarmRecords() {
        AlarmSupport.saveRecords(alarmRecords)
    }

    @MainActor
    private func deleteRecord(_ record: AlarmRecord) {
        if record.isEnabled {
            try? alarmManager.cancel(id: record.id)
        }

        alarmRecords.removeAll { $0.id == record.id }
        saveAlarmRecords()
        triggerHaptic()
    }

    @MainActor
    private func deleteAllRecords() {
        for record in alarmRecords {
            try? alarmManager.cancel(id: record.id)
        }

        alarmRecords.removeAll()
        saveAlarmRecords()
        triggerHaptic()
    }

    @MainActor
    private func beginRename(for record: AlarmRecord) {
        renameTargetRecordID = record.id
        renameEventTitleInput = normalizedEventTitle(for: record) ?? ""
        showRenameEventAlert = true
    }

    @MainActor
    private func renameTargetRecord() async {
        guard let recordID = renameTargetRecordID,
              let index = alarmRecords.firstIndex(where: { $0.id == recordID }) else {
            renameEventTitleInput = ""
            renameTargetRecordID = nil
            return
        }

        let trimmedTitle = renameEventTitleInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedTitle = trimmedTitle.isEmpty ? nil : trimmedTitle
        let previousTitle = alarmRecords[index].eventTitle
        let record = alarmRecords[index]

        alarmRecords[index].eventTitle = updatedTitle
        saveAlarmRecords()

        renameEventTitleInput = ""
        renameTargetRecordID = nil

        guard record.isEnabled else {
            triggerHaptic()
            return
        }

        do {
            try? alarmManager.cancel(id: record.id)
            try await AlarmSupport.scheduleAlarm(
                id: record.id,
                hour: record.hour,
                minute: record.minute,
                eventTitle: updatedTitle,
                using: alarmManager
            )

            if let rescheduledIndex = alarmRecords.firstIndex(where: { $0.id == record.id }),
               !alarmRecords[rescheduledIndex].isEnabled {
                alarmRecords[rescheduledIndex].isEnabled = true
                saveAlarmRecords()
            }

            triggerHaptic()
        } catch {
            if let restoredIndex = alarmRecords.firstIndex(where: { $0.id == record.id }) {
                alarmRecords[restoredIndex].eventTitle = previousTitle
                saveAlarmRecords()
            }

            try? await AlarmSupport.scheduleAlarm(
                id: record.id,
                hour: record.hour,
                minute: record.minute,
                eventTitle: previousTitle,
                using: alarmManager
            )
            synchronizeWithSystemAlarms()
            presentError(error)
        }
    }

    @MainActor
    private func presentError(_ error: Error) {
        errorMessage = error.localizedDescription
        showErrorAlert = true
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}
