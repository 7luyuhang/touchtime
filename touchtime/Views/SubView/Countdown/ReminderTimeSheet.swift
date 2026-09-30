//
//  ReminderTimeSheet.swift
//  touchtime
//
//  Created on 30/09/2026.
//

import SwiftUI
import UIKit

/// Countdown reminder time, set on time wheels like CityTimeAdjustmentSheet.
/// The title is a menu of Local and Home's cities, so the time can be picked
/// on a friend's clock abroad, with the matching local time in the capsule
/// underneath. Nothing is applied until confirm.
struct ReminderTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("additionalTimeDisplay") private var additionalTimeDisplay = "None"

    /// The day the reminder falls on. The picked time is converted on this
    /// date, so the local time allows for daylight saving and date changes.
    private let reminderDay: Date
    /// Home's cities in Home's order, listed after Local in the title menu.
    private let cities: [WorldClock]
    private let onConfirm: (Date, WorldClock?) -> Void

    /// The city whose clock the wheels are set on; nil for Local.
    @State private var city: WorldClock?
    /// The wheels' selection. They run on the device's clock, so its hour
    /// and minute here are the time on the city's clock.
    @State private var wheelTime: Date

    /// `time` is the saved reminder time: the wheels start on its hour and
    /// minute on `city`'s clock.
    init(time: Date, city: WorldClock?, reminderDay: Date, onConfirm: @escaping (Date, WorldClock?) -> Void) {
        let homeCities = Self.loadHomeCities()
        // Home's copy of the city carries any rename since it was picked;
        // one removed from Home since stays listed, so it can be kept.
        let city = city.map { saved in homeCities.first { $0.id == saved.id } ?? saved }
        if let city, !homeCities.contains(where: { $0.id == city.id }) {
            cities = homeCities + [city]
        } else {
            cities = homeCities
        }
        self.reminderDay = reminderDay
        self.onConfirm = onConfirm
        _city = State(initialValue: city)

        var calendar = Calendar.current
        calendar.timeZone = CountdownItem.reminderTimeZone(for: city)
        let components = calendar.dateComponents([.hour, .minute], from: time)
        _wheelTime = State(initialValue: Self.wheelDate(hour: components.hour ?? 9, minute: components.minute ?? 0))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { _ in
                VStack {
                    DatePicker(
                        "",
                        selection: $wheelTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: use24HourFormat ? "de_DE" : "en_US"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    cityMenu
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        triggerHaptic()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        triggerHaptic()
                        onConfirm(reminderDate, city)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            // Same spot as in CityTimeAdjustmentSheet, where the Set Alarm
            // capsule pads this one by 8pt.
            .safeAreaPadding(.bottom, 8)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                LocalTimeCapsule(time: localTimeText, dayOffset: localDayOffset)
                    .padding(.vertical, 8)
                    .offset(y: 8)
            }
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
    }

    /// The title: the city's name over its time difference, as in
    /// CityTimeAdjustmentSheet, opening a menu of Local and Home's cities.
    private var cityMenu: some View {
        Menu {
            cityButton(nil)

            if !cities.isEmpty {
                Divider()

                ForEach(cities) { city in
                    cityButton(city)
                }
            }
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(cityName(city))
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.down.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                if !additionalTimeText.isEmpty {
                    Text(additionalTimeText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                }
            }
        }
    }

    /// A title menu row: the city's name, checked while the wheels are on
    /// its clock, over the time it is there at the picked moment.
    private func cityButton(_ city: WorldClock?) -> some View {
        Button {
            select(city)
        } label: {
            if city?.id == self.city?.id {
                Label(cityName(city), systemImage: "checkmark.circle")
            } else {
                Text(cityName(city))
            }
            Text(timeText(reminderDate, in: CountdownItem.reminderTimeZone(for: city)))
        }
    }

    private func cityName(_ city: WorldClock?) -> String {
        city?.localizedCityName ?? String(localized: "Local")
    }

    /// Turns the wheels to `newCity`'s clock at the picked moment, so the
    /// local time stays put while the title changes.
    private func select(_ newCity: WorldClock?) {
        triggerHaptic()
        guard newCity?.id != city?.id else { return }
        var calendar = Calendar.current
        calendar.timeZone = CountdownItem.reminderTimeZone(for: newCity)
        let components = calendar.dateComponents([.hour, .minute], from: reminderDate)
        withAnimation(.spring()) {
            city = newCity
            wheelTime = Self.wheelDate(hour: components.hour ?? 0, minute: components.minute ?? 0)
        }
    }

    /// When the reminder goes off with the wheels as they are: their time
    /// on the city's clock, on the reminder day.
    private var reminderDate: Date {
        let time = Calendar.current.dateComponents([.hour, .minute], from: wheelTime)
        return CountdownItem.reminderDate(on: reminderDay, hour: time.hour ?? 0, minute: time.minute ?? 0, in: city) ?? wheelTime
    }

    /// The reminder time on the device's own clock, for the capsule.
    private var localTimeText: String {
        timeText(reminderDate, in: .current)
    }

    /// Days between the reminder day and the day the reminder goes off
    /// here: -1 when a time picked on a clock ahead is the day before.
    private var localDayOffset: Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: reminderDay),
            to: calendar.startOfDay(for: reminderDate)
        ).day ?? 0
    }

    /// Under the title, per the Additional Time setting: the city's
    /// difference from local time, or its UTC offset, on the reminder day.
    private var additionalTimeText: String {
        let offset = CountdownItem.reminderTimeZone(for: city).secondsFromGMT(for: reminderDate)

        switch additionalTimeDisplay {
        case "Time Difference":
            let diffHours = (offset - TimeZone.current.secondsFromGMT(for: reminderDate)) / 3600
            if diffHours > 0 {
                return String(format: String(localized: "+%d hours"), diffHours)
            }
            return String(format: String(localized: "%d hours"), diffHours)
        case "UTC":
            let offsetHours = offset / 3600
            return offsetHours < 0 ? "UTC \(offsetHours)" : "UTC +\(offsetHours)"
        default:
            return ""
        }
    }

    /// A time as the app writes it, honouring the 24-hour format setting.
    private func timeText(_ date: Date, in timeZone: TimeZone) -> String {
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

    /// Today at `hour`:`minute` on the device's clock: how the wheels,
    /// which only run on it, show a time on another city's clock.
    private static func wheelDate(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    /// The cities on Home, as HomeView saves them.
    private static func loadHomeCities() -> [WorldClock] {
        guard let data = UserDefaults.standard.data(forKey: "savedWorldClocks"),
              let clocks = try? JSONDecoder().decode([WorldClock].self, from: data) else {
            return []
        }
        return clocks
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}
