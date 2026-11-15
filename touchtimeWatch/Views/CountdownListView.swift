//
//  CountdownListView.swift
//  touchtimeWatch
//

import SwiftUI
import UIKit

/// The iPhone app's countdowns, or just its pinned ones, as the Countdowns
/// View setting chooses, a swipe across from the list of cities. Each row is
/// laid out like a city's, and filled like the countdown's card on iPhone:
/// with its cover emoji's colour, or its photo blurred. It opens the
/// countdown's details, where the cover itself shows.
struct CountdownListView: View {
    @Environment(WatchCityStore.self) private var cityStore
    @AppStorage(CountdownListFilter.storageKey) private var filter: CountdownListFilter = .all

    var body: some View {
        let countdowns = filter.apply(to: cityStore.countdowns)

        if cityStore.countdowns.isEmpty {
            emptyState("No Countdowns")
        } else if countdowns.isEmpty {
            emptyState("No Pinned Countdowns")
        } else {
            // Each minute, so the day counts turn over at midnight
            TimelineView(.everyMinute) { context in
                List(countdowns) { countdown in
                    NavigationLink {
                        CountdownDetailView(countdown: countdown)
                    } label: {
                        CountdownRow(countdown: countdown, now: context.date)
                    }
                    .listRowBackground(countdown.background.map { CountdownRowBackground(background: $0) })
                }
            }
        }
    }

    /// Only `title`, in a label with no icon: bare text in its place isn't
    /// styled as the title.
    private func emptyState(_ title: LocalizedStringKey) -> some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                EmptyView()
            }
        }
        // Left to fill the page, the view sets its content at the top;
        // sized to the title instead, it's centred between the toolbar and
        // the page dots, which need less room than the bottom safe area
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: .infinity)
        .padding(.bottom, 20)
        .ignoresSafeArea(edges: .bottom)
    }
}

/// The countdown's title and date above its day count and, as on its card
/// on iPhone, the arrow back or ahead, or the repeat or pause symbol.
private struct CountdownRow: View {
    let countdown: WatchCountdown
    let now: Date

    var body: some View {
        let targetDate = countdown.effectiveTargetDate(at: now)
        // The year only for a date a year or more from today, leaving the
        // title more of the row: nearer, the day count and the symbol
        // beside it tell which year
        let dateFormat: Date.FormatStyle = abs(CountdownDays.dayDifference(from: now, to: targetDate)) < 365
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

            CountdownDays(countdown: countdown, now: now)
        }
        // As a city's row, less below, as the digits leave the space under
        // their baseline empty
        .padding(.top, 12)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
    }
}

/// A countdown's day count and after it, as on its card on iPhone, the
/// arrow back or ahead, or the repeat or pause symbol.
struct CountdownDays: View {
    enum Size {
        /// As big as a city's time in the list.
        case list
        /// As big as a city's time in its details.
        case large
    }

    let countdown: WatchCountdown
    let now: Date
    var size: Size = .list

    @ScaledMetric(relativeTo: .largeTitle) private var listDigitsSize: CGFloat = 36
    @ScaledMetric(relativeTo: .largeTitle) private var listUnitSize: CGFloat = 20
    @ScaledMetric(relativeTo: .largeTitle) private var largeDigitsSize: CGFloat = 40
    @ScaledMetric(relativeTo: .largeTitle) private var largeUnitSize: CGFloat = 22

    /// Whole calendar days from `start` to `targetDate`; negative once the
    /// event has happened.
    static func dayDifference(from start: Date, to targetDate: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: targetDate)
        ).day ?? 0
    }

    var body: some View {
        // Held at the pause date while paused
        let days = Self.dayDifference(from: countdown.pausedAt ?? now, to: countdown.effectiveTargetDate(at: now))

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

    private var digitsSize: CGFloat {
        switch size {
        case .list: listDigitsSize
        case .large: largeDigitsSize
        }
    }

    private var unitSize: CGFloat {
        switch size {
        case .list: listUnitSize
        case .large: largeUnitSize
        }
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
        CountdownBackground(background: background)
            .clipShape(shape)
            .overlay {
                shape
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    .blendMode(.plusLighter)
            }
    }
}

/// What fills a countdown's card on iPhone: its cover emoji's colour, or
/// its photo blurred.
struct CountdownBackground: View {
    let background: WatchCountdown.Background

    var body: some View {
        switch background {
        case .color(let hue, let saturation, let brightness):
            Color(hue: hue, saturation: saturation, brightness: brightness)
        case .photo(let data):
            // In an overlay, so the photo fills its space without sizing it
            Color.clear
                .overlay {
                    if let photo = UIImage(data: data) {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            // As blurred for a row's width as the card's
                            // photo is for its own on iPhone
                            .blur(radius: 12, opaque: true)
                            // Darkened a touch for the text, as on iPhone
                            .overlay(Color.black.opacity(0.25))
                    }
                }
        }
    }
}
