//
//  CityMoonPhasesSheet.swift
//  touchtimeWatch
//

import SwiftUI

/// The next occurrence of each principal phase, ordered by date.
/// Tap anywhere in the list to switch between dates and days remaining.
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

    var body: some View {
        let events = events
        let dateFormat = Date.FormatStyle(locale: locale, timeZone: timeZone)
            .month(.abbreviated).day()

        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
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
                    .scenePadding(.navigationBar, edges: .horizontal)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                    .contentShape(.rect)
                    .onTapGesture {
                        toggleDisplayMode()
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
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
