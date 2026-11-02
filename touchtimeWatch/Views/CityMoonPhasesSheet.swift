//
//  CityMoonPhasesSheet.swift
//  touchtimeWatch
//

import SwiftUI

/// The next occurrence of each principal phase, ordered by date, then the
/// day's moonrise and moonset and the moon's illumination and distance on
/// the page below. Tap anywhere in the phases to switch between dates and
/// days remaining.
struct CityMoonPhasesSheet: View {
    let date: Date
    let timeZone: TimeZone

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
                phasesPage
                detailsPage
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

        return page {
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

        return page {
            detailRow("Moonrise") {
                timeText(riseAndSet.moonrise)
            }
            Divider()
            detailRow("Moonset") {
                timeText(riseAndSet.moonset)
            }
            Divider()
            detailRow("Illumination") {
                Text(illumination.formatted(.percent.locale(locale)))
            }
            Divider()
            detailRow("Distance") {
                Text(distance.formatted(distanceStyle))
            }
        }
    }

    /// Fills the page, scrolling only when larger text sizes push the rows
    /// past the bottom.
    private func page(@ViewBuilder rows: () -> some View) -> some View {
        let content = rows()
        return GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    content
                }
                .scenePadding(.navigationBar, edges: .horizontal)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func detailRow(_ title: LocalizedStringKey, @ViewBuilder value: () -> some View) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .blendMode(.plusLighter)

            Spacer(minLength: 8)

            value()
                .monospacedDigit()
        }
        .font(.body)
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        // As tall as a phase row, whose symbol outgrows the text.
        .frame(minHeight: 24)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    /// The digits alone, as on the watch's clocks. VoiceOver still reads AM or PM.
    @ViewBuilder
    private func timeText(_ time: Date?) -> some View {
        if let time {
            let formattedTime = WatchTimeFormat.time(time, in: timeZone, hourCycle: locale.hourCycle)
            Text(formattedTime.digits)
                .accessibilityLabel([formattedTime.digits, formattedTime.period].compactMap { $0 }.joined(separator: " "))
        } else {
            Text(verbatim: "-")
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
