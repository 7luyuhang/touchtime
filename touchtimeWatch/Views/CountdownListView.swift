//
//  CountdownListView.swift
//  touchtimeWatch
//

import SwiftUI
import UIKit

/// The iPhone app's countdowns, a swipe across from the list of cities. Each
/// row is laid out like a city's, and filled like the countdown's card on
/// iPhone: with its cover emoji's colour, or its photo blurred. The cover
/// itself doesn't show.
struct CountdownListView: View {
    @Environment(WatchCityStore.self) private var cityStore

    var body: some View {
        if cityStore.countdowns.isEmpty {
            ContentUnavailableView {
                Label("No Countdowns", systemImage: "hourglass")
            } description: {
                Text("Add countdowns on iPhone.")
            }
        } else {
            // Each minute, so the day counts turn over at midnight
            TimelineView(.everyMinute) { context in
                List(cityStore.countdowns) { countdown in
                    CountdownRow(countdown: countdown, now: context.date)
                        .listRowBackground(countdown.background.map { CountdownRowBackground(background: $0) })
                }
            }
        }
    }
}

/// The countdown's title and date above its day count and, as on its card
/// on iPhone, the arrow back or ahead, or the repeat or pause symbol.
private struct CountdownRow: View {
    let countdown: WatchCountdown
    let now: Date

    /// As big as a city's time in the list.
    @ScaledMetric(relativeTo: .largeTitle) private var digitsSize: CGFloat = 36
    @ScaledMetric(relativeTo: .largeTitle) private var unitSize: CGFloat = 20

    /// Whole calendar days from `start` to `targetDate`; negative once the
    /// event has happened.
    private func dayDifference(from start: Date, to targetDate: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: targetDate)
        ).day ?? 0
    }

    var body: some View {
        let targetDate = countdown.effectiveTargetDate(at: now)
        // Held at the pause date while paused
        let days = dayDifference(from: countdown.pausedAt ?? now, to: targetDate)
        // The year only for a date a year or more from today, leaving the
        // title more of the row: nearer, the day count and the symbol
        // beside it tell which year
        let dateFormat: Date.FormatStyle = abs(dayDifference(from: now, to: targetDate)) < 365
            ? .dateTime.month().day()
            : .dateTime.year().month().day()

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(countdown.title)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(targetDate, format: dateFormat)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .lineLimit(1)
                    .layoutPriority(1)
            }

            HStack(alignment: .lastTextBaseline) {
                dayCount(days)

                Spacer(minLength: 4)

                let status = status(days: days)
                Image(systemName: status.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .accessibilityLabel(Text(status.label))
            }
        }
        // As a city's row, less below, as the digits leave the space under
        // their baseline empty
        .padding(.top, 12)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
    }

    /// The days to go, or gone, with the day unit after them; Today on the
    /// day itself.
    @ViewBuilder
    private func dayCount(_ days: Int) -> some View {
        // Proportional, unlike a clock's digits, as the count doesn't tick:
        // a leading 1 starts in line with the title
        let digitsFont = Font.system(size: digitsSize, design: .rounded)
        if days == 0 {
            Text("Today")
                .font(digitsFont)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        } else {
            let unit = String(localized: "d")
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(verbatim: "\(abs(days))")
                    .font(digitsFont)
                Text(unit)
                    .font(.system(size: unitSize, design: .rounded))
                    // Ideographs sink about a tenth of their size below the
                    // Latin baseline, so a CJK unit is lifted onto the
                    // digits' as the Latin "d" sits
                    .baselineOffset(unit.unicodeScalars.contains { $0.properties.isIdeographic } ? unitSize * 0.09 : 0)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Duration.seconds(abs(days) * 86_400).formatted(.units(allowed: [.days], width: .wide)))
        }
    }

    /// Repeat for repeating countdowns, pause while paused, otherwise an
    /// arrow back once the event has happened, or ahead to it.
    private func status(days: Int) -> (symbolName: String, label: LocalizedStringKey) {
        if countdown.repeatFrequency != .never {
            return ("repeat", "Repeat")
        }
        if countdown.pausedAt != nil {
            return ("pause", "Paused")
        }
        return days < 0 ? ("arrow.left", "Happened") : ("arrow.right", "Happening")
    }
}

/// A countdown's row filled as its card is on iPhone, in the rounded shape
/// the list gives its rows.
private struct CountdownRowBackground: View {
    let background: WatchCountdown.Background

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        fill
            .clipShape(shape)
            .overlay {
                shape
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    .blendMode(.plusLighter)
            }
    }

    @ViewBuilder
    private var fill: some View {
        switch background {
        case .color(let hue, let saturation, let brightness):
            Color(hue: hue, saturation: saturation, brightness: brightness)
        case .photo(let data):
            // In an overlay, so the photo fills the row without sizing it
            Color.clear
                .overlay {
                    if let photo = UIImage(data: data) {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            // As blurred for the row's width as the card's
                            // photo is for its own on iPhone
                            .blur(radius: 12, opaque: true)
                            // Darkened a touch for the text, as on iPhone
                            .overlay(Color.black.opacity(0.25))
                    }
                }
        }
    }
}
