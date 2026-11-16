//
//  CountdownListView.swift
//  touchtimeWatch
//

import SwiftUI
import UIKit

/// The iPhone app's countdowns, a swipe across from the list of cities. Each
/// row is laid out like a city's, and filled like the countdown's card on
/// iPhone: with its cover emoji's colour, or its photo blurred. It opens the
/// countdown's details, where the cover itself shows.
struct CountdownListView: View {
    @Binding var selection: WatchCountdown.ID?

    @Environment(WatchCityStore.self) private var cityStore

    var body: some View {
        if cityStore.countdowns.isEmpty {
            emptyState("No Countdowns")
        } else {
            // Each minute, so the counts turn over at midnight
            TimelineView(.everyMinute) { context in
                List(cityStore.countdowns, selection: $selection) { countdown in
                    NavigationLink(value: countdown.id) {
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

/// The countdown's title and date above its count and, as on its card on
/// iPhone, the arrow back or ahead, or the repeat or pause symbol.
private struct CountdownRow: View {
    let countdown: WatchCountdown
    let now: Date

    var body: some View {
        let targetDate = countdown.effectiveTargetDate(at: now)
        // The year only for a date a year or more from today, leaving the
        // title more of the row: nearer, the count and the symbol
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

            HStack(alignment: .lastTextBaseline) {
                CountdownDays(countdown: countdown, now: now)

                Spacer(minLength: 4)

                CountdownStatusSymbol(countdown: countdown, now: now)
            }
        }
        // As a city's row, less below, as the digits leave the space under
        // their baseline empty
        .padding(.top, 12)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
    }
}

/// A countdown's count, in the unit its card on iPhone counts in.
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

    @Environment(WatchCityStore.self) private var cityStore
    @Environment(\.fontResolutionContext) private var fontResolutionContext

    @ScaledMetric(relativeTo: .largeTitle) private var listDigitsSize: CGFloat = 36
    @ScaledMetric(relativeTo: .largeTitle) private var listUnitSize: CGFloat = 20
    @ScaledMetric(relativeTo: .largeTitle) private var largeDigitsSize: CGFloat = 40
    @ScaledMetric(relativeTo: .largeTitle) private var largeUnitSize: CGFloat = 22

    private static let unitSpacing: CGFloat = 2

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
        countText(cityStore.countdownUnit.count(from: countdown.pausedAt ?? now, to: countdown.effectiveTargetDate(at: now)))
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

    /// Proportional, unlike a clock's digits, as the count doesn't tick.
    private var digitsFont: Font {
        .system(size: digitsSize, design: .rounded)
    }

    private var unitFont: Font {
        .system(size: unitSize, design: .rounded)
    }

    /// The years, months or days to go, or gone, with the unit after them;
    /// Today on the day itself.
    @ViewBuilder
    private func countText(_ count: CountdownCount) -> some View {
        if count.value == 0 {
            Text("Today")
                .font(digitsFont)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        } else {
            let digits = "\(abs(count.value))"
            let unit = Self.unitSymbol(for: count.unit)
            let inkInset = leadingInkInset(of: digits, before: unit)
            HStack(alignment: .lastTextBaseline, spacing: Self.unitSpacing) {
                Text(verbatim: digits)
                    .font(digitsFont)
                Text(unit)
                    .font(unitFont)
                    // Ideographs sink about a tenth of their size below the
                    // Latin baseline, so a CJK unit is lifted onto the
                    // digits' as a Latin one sits
                    .baselineOffset(unit.unicodeScalars.contains { $0.properties.isIdeographic } ? unitSize * 0.09 : 0)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            // The first digit's ink, rather than its box, starts at the
            // leading edge, in line with the title; a share of the width, as
            // the count can shrink to fit
            .visualEffect { content, geometry in
                content.offset(x: -inkInset * geometry.size.width)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.spokenCount(count))
        }
    }

    /// How far in from the leading edge the ink of `digits` starts, as a share
    /// of the count's width, with `unit` after them.
    private func leadingInkInset(of digits: String, before unit: String) -> CGFloat {
        let digitsMetrics = digitsFont.resolve(in: fontResolutionContext).metrics(of: digits)
        let unitWidth = unitFont.resolve(in: fontResolutionContext).metrics(of: unit).width
        return digitsMetrics.leadingInkInset / (digitsMetrics.width + Self.unitSpacing + unitWidth)
    }

    /// Localized compact unit after the count: "y", "mo" or "d" in English,
    /// "年", "个月" or "天" in Chinese.
    private static func unitSymbol(for unit: CountdownUnit) -> String {
        switch unit {
        case .years: String(localized: "y")
        case .months: String(localized: "mo")
        case .days: String(localized: "d")
        }
    }

    /// The count in words, e.g. "6 months".
    private static func spokenCount(_ count: CountdownCount) -> String {
        var components = DateComponents()
        switch count.unit {
        case .years: components.year = abs(count.value)
        case .months: components.month = abs(count.value)
        case .days: components.day = abs(count.value)
        }
        return DateComponentsFormatter.localizedString(from: components, unitsStyle: .full) ?? ""
    }
}

/// As on a countdown's card on iPhone: the repeat symbol for a repeating
/// countdown, pause while paused, otherwise the arrow back once the event
/// has happened, or ahead to it.
struct CountdownStatusSymbol: View {
    let countdown: WatchCountdown
    let now: Date

    var body: some View {
        let status = self.status
        Image(systemName: status.symbolName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .blendMode(.plusLighter)
            .accessibilityLabel(Text(status.label))
    }

    private var status: (symbolName: String, label: LocalizedStringKey) {
        if countdown.repeatFrequency != .never {
            return ("repeat", "Repeat")
        }
        if countdown.pausedAt != nil {
            return ("pause", "Paused")
        }
        return CountdownDays.dayDifference(from: now, to: countdown.effectiveTargetDate(at: now)) < 0
            ? ("arrow.left", "Happened")
            : ("arrow.right", "Happening")
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

/// What fills a countdown's card on iPhone: its cover emoji's colour, here
/// as the system's gradient of it, or its photo blurred.
struct CountdownBackground: View {
    let background: WatchCountdown.Background

    var body: some View {
        switch background {
        case .color(let hue, let saturation, let brightness):
            Rectangle()
                .fill(Color(hue: hue, saturation: saturation, brightness: brightness).gradient)
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
