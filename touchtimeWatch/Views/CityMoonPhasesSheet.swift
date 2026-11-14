//
//  CityMoonPhasesSheet.swift
//  touchtimeWatch
//

import SwiftUI

/// The day's moonrise and moonset and the moon's illumination and distance,
/// then the next occurrence of each principal phase, ordered by date, then
/// the month's moons. Tap anywhere in the phases to switch between dates and
/// days remaining.
struct CityMoonPhasesSheet: View {
    let date: Date
    let timeZone: TimeZone
    /// The iPhone app's first day of the week, for the calendar's weeks.
    let firstWeekday: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var showsRemainingDays = false

    private struct Event: Identifiable {
        let phase: MoonPhase
        let name: String
        let date: Date
        var id: String { phase.symbolName }
    }

    private var events: [Event] {
        let quarter = MoonAstronomy.synodicMonthDays / 4
        let phases: [(MoonPhase, String, Double)] = [
            (.newMoon, String(localized: "New"), 0),
            (.firstQuarter, String(localized: "First"), quarter),
            (.fullMoon, String(localized: "Full"), quarter * 2),
            (.lastQuarter, String(localized: "Last"), quarter * 3)
        ]
        return phases.compactMap { phase, name, age in
            MoonAstronomy.nextPhaseDate(targetAgeDays: age, startingFrom: date)
                .map { Event(phase: phase, name: name, date: $0) }
        }
        .sorted { $0.date < $1.date }
    }

    /// The selected day's phase, matching the name under the moon.
    private var phase: MoonPhase {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return MoonDay(containing: date, calendar: calendar).phase
    }

    /// Moonrise and moonset during the city's day.
    private var riseAndSet: MoonDayEvents {
        guard let coordinate = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier) else {
            return MoonDayEvents(moonrise: nil, moonset: nil)
        }
        return MoonAstronomy.riseAndSet(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            date: date,
            timeZone: timeZone
        )
    }

    var body: some View {
        NavigationStack {
            TabView {
                detailsPage
                phasesPage
                CityMoonCalendarPage(date: date, timeZone: timeZone, firstWeekday: firstWeekday)
            }
            .tabViewStyle(.verticalPage)
            .navigationTitle(phase.localizedName)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var phasesPage: some View {
        let events = events
        let dateFormat = Date.FormatStyle(locale: locale, timeZone: timeZone)
            .month(.abbreviated).day()

        return DetailSheetPage {
            ForEach(events) { event in
                let value = showsRemainingDays
                    ? daysUntil(event.date)
                    : event.date.formatted(dateFormat)

                if event.id != events.first?.id {
                    Divider()
                }
                HStack(spacing: 8) {
                    Text(event.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(.secondary)
                        .blendMode(.plusLighter)

                    Image(systemName: event.phase.symbolName)
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 20))
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                        .foregroundColor(.secondary)
                        .blendMode(.plusLighter)

                    Text(value)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.body)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 10)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(event.phase.localizedName)
                .accessibilityValue(showsRemainingDays
                    ? value
                    : event.date.formatted(dateFormat.year()))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    toggleDisplayMode()
                }
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            toggleDisplayMode()
        }
    }

    private var detailsPage: some View {
        let riseAndSet = riseAndSet
        let snapshot = MoonAstronomy.snapshot(for: date)
        let illumination = Int((snapshot.illuminatedFraction * 100).rounded())
        let distance = Measurement(value: snapshot.distanceKilometers, unit: UnitLength.kilometers)
        // Road usage picks km or miles by the watch's region settings.
        let distanceStyle = Measurement<UnitLength>.FormatStyle(
            width: .abbreviated,
            locale: locale,
            usage: .road,
            numberFormatStyle: .number.precision(.fractionLength(0))
        )

        return DetailSheetPage {
            DetailSheetRow("Moonrise") {
                DetailSheetTime(date: riseAndSet.moonrise, timeZone: timeZone)
            }
            Divider()
            DetailSheetRow("Moonset") {
                DetailSheetTime(date: riseAndSet.moonset, timeZone: timeZone)
            }
            Divider()
            DetailSheetRow("Illumination") {
                Text(illumination.formatted(.percent.locale(locale)))
            }
            Divider()
            DetailSheetRow("Distance") {
                Text(distance.formatted(distanceStyle))
            }
        }
    }

    private func toggleDisplayMode() {
        withAnimation(.smooth(duration: 0.25)) {
            showsRemainingDays.toggle()
        }
    }

    private func daysUntil(_ targetDate: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        // Count local calendar days so tomorrow is one day away even across DST.
        let days = max(0, calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: targetDate)
        ).day ?? 0)
        if days == 0 {
            return String(localized: "Today", locale: locale)
        }
        return String(localized: "\(days)D", locale: locale)
    }
}
