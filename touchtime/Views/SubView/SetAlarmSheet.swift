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
    private enum AlarmSortOrder: String, CaseIterable {
        case newestFirst
        case oldestFirst
    }

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
    @State private var showLocalCityTimeAdjustmentSheet = false
    @State private var localCityTimeOffset: TimeInterval = 0
    @State private var localShowScrollTimeButtons = false

    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("alarmSortOrder") private var alarmSortOrderRawValue = AlarmSortOrder.newestFirst.rawValue
    @AppStorage("showWhatsNewLongpressAlarm") private var showWhatsNewLongpressAlarm = true

    private let alarmManager = AlarmManager.shared

    private var sortedRecords: [AlarmRecord] {
        switch alarmSortOrder {
        case .newestFirst:
            return alarmRecords.sorted { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            return alarmRecords.sorted { $0.createdAt < $1.createdAt }
        }
    }

    private var alarmSortOrder: AlarmSortOrder {
        AlarmSortOrder(rawValue: alarmSortOrderRawValue) ?? .newestFirst
    }

    private var alarmSortOrderBinding: Binding<AlarmSortOrder> {
        Binding(
            get: {
                alarmSortOrder
            },
            set: { newValue in
                alarmSortOrderRawValue = newValue.rawValue
                triggerHaptic()
            }
        )
    }

    private var repeatWeekdayOptions: [(name: String, index: Int)] {
        [
            (String(localized: "Mon"), 2),
            (String(localized: "Tue"), 3),
            (String(localized: "Wed"), 4),
            (String(localized: "Thu"), 5),
            (String(localized: "Fri"), 6),
            (String(localized: "Sat"), 7),
            (String(localized: "Sun"), 1)
        ]
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
                            if alarmRecords.count > 1 {
                                Section(String(localized: "Sort by")) {
                                    Button {
                                        alarmSortOrderBinding.wrappedValue = .newestFirst
                                    } label: {
                                        if alarmSortOrder == .newestFirst {
                                            Label(String(localized: "Newest First"), systemImage: "checkmark.circle")
                                        } else {
                                            Text(String(localized: "Newest First"))
                                        }
                                    }
                                    Button {
                                        alarmSortOrderBinding.wrappedValue = .oldestFirst
                                    } label: {
                                        if alarmSortOrder == .oldestFirst {
                                            Label(String(localized: "Oldest First"), systemImage: "checkmark.circle")
                                        } else {
                                            Text(String(localized: "Oldest First"))
                                        }
                                    }
                                }
                                Divider()
                            }

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
                            Button(String(localized: "Remove"), role: .destructive) {
                                deleteAllRecords()
                            }
                        }
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    Button {
                        triggerHaptic()
                        localCityTimeOffset = 0
                        localShowScrollTimeButtons = false
                        showLocalCityTimeAdjustmentSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
        }
        .sheet(isPresented: $showLocalCityTimeAdjustmentSheet) {
            CityTimeAdjustmentSheet(
                cityName: String(localized: "Local"),
                timeZoneIdentifier: TimeZone.current.identifier,
                timeOffset: $localCityTimeOffset,
                showSheet: $showLocalCityTimeAdjustmentSheet,
                showScrollTimeButtons: $localShowScrollTimeButtons
            )
        }
        .onChange(of: showLocalCityTimeAdjustmentSheet) { oldValue, newValue in
            if oldValue && !newValue {
                loadAlarmRecords()
                synchronizeWithSystemAlarms()
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
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var alarmsPage: some View {
        if sortedRecords.isEmpty {
            // Blank State
            ContentUnavailableView {
                Label("No Alarms", systemImage: "alarm")
            } description: {
                Text(String(localized: "Create alarms for your moments"))
            }
            .frame(maxHeight: .infinity)
        } else {
            List {
                if showWhatsNewLongpressAlarm {
                    Section {
                        HStack(spacing: 16) {
                            Image(systemName: "hand.tap.fill")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .blendMode(.plusLighter)
                                .frame(width: 24, height: 24)

                            Text(String(localized: "Press and hold for more options"))
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "xmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 24, height: 24)
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(Color.black.opacity(0.10))
                                .glassEffect(
                                    .regular.interactive(),
                                    in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                                )
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring()) {
                                showWhatsNewLongpressAlarm = false
                            }
                            triggerHaptic()
                        }
                    }
                }

                ForEach(sortedRecords) { record in
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
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

                            if record.repeatRule == .weekly {
                                repeatWeekdayRow(for: record)
                            }
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
                            Menu {
                                Picker(
                                    String(localized: "Repeat"),
                                    selection: bindingForRepeatRule(recordID: record.id)
                                ) {
                                    Text(String(localized: "Once"))
                                        .tag(AlarmRepeatRule.once)
                                    Text(String(localized: "Weekly"))
                                        .tag(AlarmRepeatRule.weekly)
                                }
                            } label: {
                                Label(String(localized: "Repeat"), systemImage: "repeat")
                            }

                            Button {
                                beginRename(for: record)
                            } label: {
                                Label(String(localized: "Rename"), systemImage: "pencil.tip.crop.circle")
                            }
                            
                            Divider()

                            Button(role: .destructive) {
                                deleteRecord(record)
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

    private func bindingForRepeatRule(recordID: UUID) -> Binding<AlarmRepeatRule> {
        Binding(
            get: {
                alarmRecords.first(where: { $0.id == recordID })?.repeatRule ?? .once
            },
            set: { newValue in
                Task {
                    await updateRepeatRule(recordID: recordID, to: newValue)
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
                repeatRule: record.repeatRule,
                repeatWeekdays: record.repeatWeekdays,
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
                repeatRule: record.repeatRule,
                repeatWeekdays: record.repeatWeekdays,
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
                repeatRule: record.repeatRule,
                repeatWeekdays: record.repeatWeekdays,
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

    @ViewBuilder
    private func repeatWeekdayRow(for record: AlarmRecord) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(repeatWeekdayOptions.enumerated()), id: \.element.index) { index, weekday in
                if index > 0 {
                    Spacer(minLength: 0)
                }

                Button {
                    Task {
                        await toggleWeeklyDay(for: record, weekday: weekday.index)
                    }
                } label: {
                    let isSelected = record.repeatWeekdays.contains(weekday.index)
                    Text(weekday.name)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle(isSelected ? Color.black : Color.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(isSelected ? Color.white : Color.black.opacity(0.20))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
    }

    @MainActor
    private func updateRepeatRule(recordID: UUID, to repeatRule: AlarmRepeatRule) async {
        guard let record = alarmRecords.first(where: { $0.id == recordID }) else { return }

        switch repeatRule {
        case .once:
            await applyRepeatConfiguration(
                recordID: recordID,
                repeatRule: .once,
                repeatWeekdays: []
            )
        case .weekly:
            let weekdays = normalizedRepeatWeekdays(record.repeatWeekdays)
            await applyRepeatConfiguration(
                recordID: recordID,
                repeatRule: .weekly,
                repeatWeekdays: weekdays.isEmpty ? [defaultRepeatWeekday()] : weekdays
            )
        }
    }

    @MainActor
    private func toggleWeeklyDay(for record: AlarmRecord, weekday: Int) async {
        guard let index = alarmRecords.firstIndex(where: { $0.id == record.id }) else { return }

        var weekdays = Set(alarmRecords[index].repeatWeekdays)
        if weekdays.contains(weekday) {
            if weekdays.count == 1 {
                return
            }
            weekdays.remove(weekday)
        } else {
            weekdays.insert(weekday)
        }

        await applyRepeatConfiguration(
            recordID: record.id,
            repeatRule: .weekly,
            repeatWeekdays: Array(weekdays)
        )
    }

    @MainActor
    private func applyRepeatConfiguration(
        recordID: UUID,
        repeatRule: AlarmRepeatRule,
        repeatWeekdays: [Int]
    ) async {
        guard let index = alarmRecords.firstIndex(where: { $0.id == recordID }) else { return }

        let previousRule = alarmRecords[index].repeatRule
        let previousWeekdays = alarmRecords[index].repeatWeekdays
        let baseRecord = alarmRecords[index]
        let normalizedWeekdays: [Int]
        if repeatRule == .weekly {
            let weekdays = normalizedRepeatWeekdays(repeatWeekdays)
            normalizedWeekdays = weekdays.isEmpty ? [defaultRepeatWeekday()] : weekdays
        } else {
            normalizedWeekdays = []
        }

        alarmRecords[index].repeatRule = repeatRule
        alarmRecords[index].repeatWeekdays = normalizedWeekdays
        saveAlarmRecords()

        guard baseRecord.isEnabled else {
            triggerHaptic()
            return
        }

        let updatedRecord = alarmRecords[index]

        do {
            try? alarmManager.cancel(id: updatedRecord.id)
            try await AlarmSupport.scheduleAlarm(
                id: updatedRecord.id,
                hour: updatedRecord.hour,
                minute: updatedRecord.minute,
                eventTitle: updatedRecord.eventTitle,
                repeatRule: updatedRecord.repeatRule,
                repeatWeekdays: updatedRecord.repeatWeekdays,
                using: alarmManager
            )
            synchronizeWithSystemAlarms()
            triggerHaptic()
        } catch {
            if let restoreIndex = alarmRecords.firstIndex(where: { $0.id == recordID }) {
                alarmRecords[restoreIndex].repeatRule = previousRule
                alarmRecords[restoreIndex].repeatWeekdays = previousWeekdays
                saveAlarmRecords()
            }

            try? await AlarmSupport.scheduleAlarm(
                id: baseRecord.id,
                hour: baseRecord.hour,
                minute: baseRecord.minute,
                eventTitle: baseRecord.eventTitle,
                repeatRule: previousRule,
                repeatWeekdays: previousWeekdays,
                using: alarmManager
            )
            synchronizeWithSystemAlarms()
            presentError(error)
        }
    }

    private func normalizedRepeatWeekdays(_ weekdays: [Int]) -> [Int] {
        Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
    }

    private func defaultRepeatWeekday() -> Int {
        Calendar.current.component(.weekday, from: Date())
    }
}
