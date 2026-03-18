//
//  SetAlarmSheet.swift
//  touchtime
//
//  Created on 17/03/2026.
//

import SwiftUI
import AlarmKit
import UIKit

nonisolated struct TouchtimeAlarmMetadata: AlarmMetadata {
    // Empty metadata
}

struct AlarmRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let hour: Int
    let minute: Int
    var isEnabled: Bool
    let createdAt: Date
    var sourceCityName: String?
    var sourceCityHour: Int?
    var sourceCityMinute: Int?

    init(
        id: UUID,
        hour: Int,
        minute: Int,
        isEnabled: Bool,
        createdAt: Date,
        sourceCityName: String? = nil,
        sourceCityHour: Int? = nil,
        sourceCityMinute: Int? = nil
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.sourceCityName = sourceCityName
        self.sourceCityHour = sourceCityHour
        self.sourceCityMinute = sourceCityMinute
    }
}

struct SetAlarmSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var alarmRecords: [AlarmRecord] = []
    @State private var authorizationState: AlarmManager.AuthorizationState = AlarmManager.shared.authorizationState
    @State private var errorMessage = ""
    @State private var showErrorAlert = false
    @State private var showPermissionAlert = false
    @State private var alarmUpdatesTask: Task<Void, Never>? = nil

    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    private let alarmManager = AlarmManager.shared
    private let alarmRecordsKey = "savedAlarmRecords"

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
                                deleteAllRecords()
                            } label: {
                                Label(String(localized: "Remove All"), systemImage: "minus.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
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
        .alert("Alarm Permission Needed", isPresented: $showPermissionAlert) {
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Go to Settings")) {
                openSystemSettings()
            }
        } message: {
            Text("Please allow alarm access in Settings to create alarms.")
        }
        .alert("Alarm Error", isPresented: $showErrorAlert) {
            Button(String(localized: "Done"), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var alarmsPage: some View {
        if sortedRecords.isEmpty {
            ContentUnavailableView {
                Label("No Alarms", systemImage: "alarm")
            } description: {
                Text(String(localized: "Swipe right to set an alarm for the selected city"))
            }
            .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(sortedRecords) { record in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.footnote.weight(.semibold))
                                Text(formattedTime(hour: record.hour, minute: record.minute))
                                    .font(.headline)
                            }
                            .foregroundStyle(.primary)

                            if let cityName = record.sourceCityName,
                               let cityHour = record.sourceCityHour,
                               let cityMinute = record.sourceCityMinute {
                                Text("\(cityName) · \(formattedTime(hour: cityHour, minute: cityMinute))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
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
            try await scheduleAlarm(id: record.id, hour: record.hour, minute: record.minute)
            synchronizeWithSystemAlarms()
        } catch {
            if let index = alarmRecords.firstIndex(where: { $0.id == record.id }) {
                alarmRecords[index].isEnabled = false
                saveAlarmRecords()
            }
            presentError(error)
        }
    }

    private func scheduleAlarm(id: UUID, hour: Int, minute: Int) async throws {
        let alarmTitle = LocalizedStringResource("Alarm")
        let doneText = LocalizedStringResource("Done")
        let alert: AlarmPresentation.Alert

        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(title: alarmTitle)
        } else {
            alert = AlarmPresentation.Alert(
                title: alarmTitle,
                stopButton: AlarmButton(
                    text: doneText,
                    textColor: .white,
                    systemImageName: "checkmark"
                )
            )
        }

        let attributes = AlarmAttributes<TouchtimeAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: .white
        )

        let schedule = Alarm.Schedule.relative(
            .init(
                time: .init(hour: hour, minute: minute),
                repeats: .never
            )
        )

        _ = try await alarmManager.schedule(
            id: id,
            configuration: .alarm(schedule: schedule, attributes: attributes)
        )
    }

    @MainActor
    private func ensureAuthorizationForAlarmActions() async -> Bool {
        authorizationState = alarmManager.authorizationState

        switch authorizationState {
        case .authorized:
            return true
        case .denied:
            showPermissionAlert = true
            return false
        case .notDetermined:
            do {
                authorizationState = try await alarmManager.requestAuthorization()
                if authorizationState == .authorized {
                    return true
                }

                showPermissionAlert = true
                return false
            } catch {
                authorizationState = alarmManager.authorizationState
                presentError(error)
                return false
            }
        @unknown default:
            return false
        }
    }

    @MainActor
    private func synchronizeWithSystemAlarms() {
        do {
            let activeAlarmIDs = Set(try alarmManager.alarms.map(\.id))
            var didChange = false

            for index in alarmRecords.indices {
                if alarmRecords[index].isEnabled && !activeAlarmIDs.contains(alarmRecords[index].id) {
                    alarmRecords[index].isEnabled = false
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
            if alarmRecords[index].isEnabled && !activeAlarmIDs.contains(alarmRecords[index].id) {
                alarmRecords[index].isEnabled = false
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

    @MainActor
    private func loadAlarmRecords() {
        guard let data = UserDefaults.standard.data(forKey: alarmRecordsKey),
              let decoded = try? JSONDecoder().decode([AlarmRecord].self, from: data) else {
            alarmRecords = []
            return
        }

        alarmRecords = decoded
    }

    private func saveAlarmRecords() {
        guard let encoded = try? JSONEncoder().encode(alarmRecords) else { return }
        UserDefaults.standard.set(encoded, forKey: alarmRecordsKey)
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
    private func presentError(_ error: Error) {
        errorMessage = error.localizedDescription
        showErrorAlert = true
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}
