//
//  DSTSheet.swift
//  touchtime
//
//  Created on 16/10/2026.
//

import SwiftUI
import UIKit

/// The next DST change: the city's clock now beside what it will read at
/// the same moment once the change is in, e.g. 20:00 and 19:00 (-1h).
/// Zooms out of the DST pill, and can set a reminder for the day before.
struct DSTSheet: View {
    let cityName: String
    let transitionDate: Date
    let isStart: Bool
    let timeOffset: TimeInterval
    let dateFormat: DetailsDateFormat

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var isReminderSet = false
    @State private var isUpdatingReminder = false
    @State private var showNotificationPermissionAlert = false

    private static let columnSpacing: CGFloat = 24
    private static let maxDialSize: CGFloat = 150

    private var timeZone: TimeZone {
        TimeZone(identifier: dateFormat.timeZoneIdentifier) ?? .current
    }

    /// The city's offset from UTC once the change is in, in seconds
    private var offsetAfterChange: Int {
        timeZone.secondsFromGMT(for: transitionDate)
    }

    /// How far the clocks move, in seconds: negative when they go back
    private var offsetChange: Int {
        offsetAfterChange - timeZone.secondsFromGMT(for: transitionDate.addingTimeInterval(-1))
    }

    /// Settable until its time has passed; once set, it stays to be cancelled.
    private var showsRemindButton: Bool {
        isReminderSet || DSTReminderManager.shared.fireDate(before: transitionDate) != nil
    }

    var body: some View {
        NavigationStack {
            clockComparison
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity, alignment: .center)
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

                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text(isStart ? String(localized: "Daylight Saving Time Starts") : String(localized: "Daylight Saving Time Ends"))
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Text(cityName)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if showsRemindButton {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: toggleReminder) {
                                Image(systemName: isReminderSet ? "bell.fill" : "bell")
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .accessibilityLabel(isReminderSet ? String(localized: "Reminder Set") : String(localized: "Remind Me"))
                        }
                    }
                }
                .task {
                    isReminderSet = await DSTReminderManager.shared.isScheduled(
                        timeZoneIdentifier: dateFormat.timeZoneIdentifier,
                        transitionDate: transitionDate
                    )
                }
                .alert("Notifications Disabled", isPresented: $showNotificationPermissionAlert) {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Allow notifications in Settings to get DST reminders.")
                }
        }
        .presentationDetents([.height(300)])
    }

    /// Two clocks side by side, each above its title.
    private var clockComparison: some View {
        VStack(spacing: 12) {
            TimelineView(.animation) { context in
                let date = context.date.addingTimeInterval(timeOffset)

                HStack(spacing: Self.columnSpacing) {
                    DSTClockDial(
                        date: date,
                        secondsFromGMT: timeZone.secondsFromGMT(for: date),
                        use24HourFormat: dateFormat.use24HourFormat
                    )
                    .frame(maxWidth: Self.maxDialSize)
                    .frame(maxWidth: .infinity)

                    DSTClockDial(
                        date: date,
                        secondsFromGMT: offsetAfterChange,
                        use24HourFormat: dateFormat.use24HourFormat,
                        hourHandShift: offsetChange
                    )
                    .frame(maxWidth: Self.maxDialSize)
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: Self.columnSpacing) {
                columnTitle(String(localized: "Current"))
                columnTitle(dateFormat.monthDayYear(transitionDate))
            }
        }
    }

    private func columnTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
    }

    /// Sets the reminder, or cancels it when it is already set.
    private func toggleReminder() {
        guard !isUpdatingReminder else { return }
        triggerHaptic()
        isUpdatingReminder = true

        Task {
            defer { isUpdatingReminder = false }
            let reminderManager = DSTReminderManager.shared

            if isReminderSet {
                reminderManager.cancel(timeZoneIdentifier: dateFormat.timeZoneIdentifier, transitionDate: transitionDate)
                withAnimation(.spring()) {
                    isReminderSet = false
                }
                return
            }

            guard await reminderManager.requestAuthorization() else {
                showNotificationPermissionAlert = true
                return
            }

            let didSchedule = await reminderManager.schedule(
                cityName: cityName,
                timeZoneIdentifier: dateFormat.timeZoneIdentifier,
                transitionDate: transitionDate,
                isStart: isStart,
                offsetChange: offsetChange,
                dateText: dateFormat.monthDay(transitionDate)
            )
            guard didSchedule else { return }

            withAnimation(.spring()) {
                isReminderSet = true
            }
            if hapticEnabled {
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.prepare()
                notificationFeedback.notificationOccurred(.success)
            }
        }
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}
