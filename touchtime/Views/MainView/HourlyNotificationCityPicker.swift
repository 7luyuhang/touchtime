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

    private let maxSelectionCount = 3

    private var isSelectionFull: Bool {
        selectedCityIds.count >= maxSelectionCount
    }

    /// The next on-the-hour fire date, so the preview matches the upcoming notification.
    private var previewFireDate: Date {
        Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? Date()
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
                    // Fixed row height so the section doesn't shift when the body wraps to two lines
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

        }
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
        }
        .onChange(of: selectedCityIds) {
            HourlyNotificationManager.saveSelectedCityIds(selectedCityIds)
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
