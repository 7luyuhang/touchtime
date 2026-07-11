//
//  HourlyNotificationCityPicker.swift
//  touchtime
//
//  Created on 09/07/2026.
//

import SwiftUI
import WeatherKit

struct HourlyNotificationCityPicker: View {
    let worldClocks: [WorldClock]
    /// Ordered: the first selected city appears first in the notification body.
    @Binding var selectedCityIds: [UUID]
    var weatherCondition: WeatherCondition? = nil
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage(HourlyNotificationManager.timeWindowEnabledKey) private var timeWindowEnabled = false
    @AppStorage(HourlyNotificationManager.startTimeKey) private var chimeStartTime = HourlyNotificationManager.defaultStartTime
    @AppStorage(HourlyNotificationManager.endTimeKey) private var chimeEndTime = HourlyNotificationManager.defaultEndTime

    @State private var startDate = Date()
    @State private var endDate = Date()

    private let maxSelectionCount = 3

    private var isSelectionFull: Bool {
        selectedCityIds.count >= maxSelectionCount
    }

    // Same locale trick as AvailableTimePicker so the DatePicker follows the app's time format
    private var datePickerLocale: Locale {
        use24HourFormat ? Locale(identifier: "en_GB") : Locale(identifier: "en_US")
    }

    /// The next on-the-hour fire date (respecting the time window),
    /// so the preview matches the upcoming notification.
    private var previewFireDate: Date {
        let calendar = Calendar.current
        var candidate = calendar.nextDate(
            after: Date(),
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? Date()

        // Look ahead up to 24 hours for the first hour inside the window
        for _ in 0..<24 {
            if HourlyNotificationManager.isWithinTimeWindow(candidate) {
                return candidate
            }
            guard let next = calendar.date(byAdding: .hour, value: 1, to: candidate) else { break }
            candidate = next
        }
        return candidate
    }

    /// Same body text as the scheduled notification, in selection order:
    /// "Shanghai 17:00 · New York 05:00"
    private var previewBodyText: String {
        let fireDate = previewFireDate
        return selectedCityIds
            .compactMap { id -> String? in
                guard let clock = worldClocks.first(where: { $0.id == id }),
                      let timeZone = TimeZone(identifier: clock.timeZoneIdentifier) else { return nil }
                return "\(clock.localizedCityName) \(timeString(for: fireDate, in: timeZone))"
            }
            .joined(separator: " · ")
    }

    var body: some View {
        List {
            // Notification preview on a live sky background
            Section {
                notificationPreview
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        ZStack {
                            Color.black
                            SkyBackgroundView(
                                date: Date(),
                                timeZoneIdentifier: TimeZone.current.identifier,
                                weatherCondition: weatherCondition
                            )
                        }
                    )
            } footer: {
                Text("Preview")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity)
            }

            Section {
                ForEach(worldClocks) { clock in
                    let selectionIndex = selectedCityIds.firstIndex(of: clock.id)
                    let isSelected = selectionIndex != nil

                    Button(action: {
                        withAnimation {
                            toggleSelection(for: clock.id)
                        }

                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }) {
                        HStack {
                            Text(clock.localizedCityName)

                            Spacer()

                            Image(systemName: selectionIndex.map { "\($0 + 1).circle.fill" } ?? "circle")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.25))
                                .contentTransition(.symbolEffect(.replace))
                                .opacity(!isSelected && isSelectionFull ? 0 : 1)
                                .animation(nil, value: isSelectionFull)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isSelected && isSelectionFull)
                }
            }

            // Time window: only chime between start and end time
            Section {
                TouchTimeToggle(isOn: $timeWindowEnabled) {
                    HStack(spacing: 12) {
                        SystemIconImage(systemName: "app.badge.clock", topColor: .gray, bottomColor: .gray, style: .plain)
                        Text("Time Period")
                    }
                }

                if timeWindowEnabled {
                    DatePicker(
                        selection: $startDate,
                        displayedComponents: .hourAndMinute
                    ) {
                        Text(String(localized: "Start Time"))
                    }
                    .datePickerStyle(.compact)
                    .environment(\.locale, datePickerLocale)
                    .onChange(of: startDate) { _, newValue in
                        chimeStartTime = dateToTimeString(newValue)
                    }

                    DatePicker(
                        selection: $endDate,
                        displayedComponents: .hourAndMinute
                    ) {
                        Text(String(localized: "End Time"))
                    }
                    .datePickerStyle(.compact)
                    .environment(\.locale, datePickerLocale)
                    .onChange(of: endDate) { _, newValue in
                        chimeEndTime = dateToTimeString(newValue)
                    }
                }
            } footer: {
                if timeWindowEnabled {
                    Text("Only chime between the start and end time.")
                } else {
                    Text("Enable to only chime within a time period.")
                }
            }

        }
        .scrollIndicators(.hidden)
        .navigationTitle("City Selection")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Drop ids of cities that no longer exist (e.g. deleted or reset),
            // otherwise they still count towards the selection limit
            let validIds = Set(worldClocks.map(\.id))
            let pruned = selectedCityIds.filter { validIds.contains($0) }
            if pruned != selectedCityIds {
                selectedCityIds = pruned
            }

            startDate = timeStringToDate(chimeStartTime)
            endDate = timeStringToDate(chimeEndTime)
        }
        .onChange(of: selectedCityIds) {
            HourlyNotificationManager.saveSelectedCityIds(selectedCityIds)
            HourlyNotificationManager.shared.reschedule()
        }
        .onChange(of: timeWindowEnabled) {
            HourlyNotificationManager.shared.reschedule()
        }
        .onChange(of: chimeStartTime) {
            HourlyNotificationManager.shared.reschedule()
        }
        .onChange(of: chimeEndTime) {
            HourlyNotificationManager.shared.reschedule()
        }
    }

    private var notificationPreview: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("TouchTimeAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("On the Hour")
                    .font(.subheadline.weight(.semibold))

                if !previewBodyText.isEmpty {
                    // Appears/disappears with blurReplace; in-place text changes use numericText
                    Text(previewBodyText)
                        .font(.subheadline)
                        .lineLimit(2)
                        .contentTransition(.numericText())
                        .transition(.blurReplace)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassEffect(
            .regular.interactive(),in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .animation(.spring(), value: previewBodyText)
    }

    // Convert stored "HH:mm" string to a Date for the DatePicker (same as AvailableTimePicker)
    private func timeStringToDate(_ timeString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current

        guard let date = formatter.date(from: timeString) else {
            return Date()
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return calendar.date(bySettingHour: components.hour ?? 9,
                             minute: components.minute ?? 0,
                             second: 0,
                             of: Date()) ?? Date()
    }

    // Convert Date back to "HH:mm" for storage
    private func dateToTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    private func timeString(for date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        if use24HourFormat {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm a"
            formatter.amSymbol = "am"
            formatter.pmSymbol = "pm"
        }
        return formatter.string(from: date)
    }

    private func toggleSelection(for id: UUID) {
        if let index = selectedCityIds.firstIndex(of: id) {
            selectedCityIds.remove(at: index)
        } else if !isSelectionFull {
            selectedCityIds.append(id)
        }
    }
}
