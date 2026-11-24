//
//  CountdownCard.swift
//  touchtimeWatch
//

import SwiftUI
import UIKit

/// A countdown's title and date above its count and, as on its card on
/// iPhone, the arrow back or ahead, or the repeat or pause symbol, as the
/// countdown list's rows and the Countdown widget show them.
struct CountdownCard: View {
    let countdown: WatchCountdown
    let now: Date
    /// The unit its card on iPhone counts in.
    let unit: CountdownUnit
    /// Between the title and the count.
    var spacing: CGFloat = 16
    var countSize: CountdownDays.Size = .list

    var body: some View {
        let targetDate = countdown.effectiveTargetDate(at: now)
        // The year only for a date a year or more from today, leaving the
        // title more of the row: nearer, the count and the symbol
        // beside it tell which year
        let dateFormat: Date.FormatStyle = abs(CountdownDays.dayDifference(from: now, to: targetDate)) < 365
            ? .dateTime.month().day()
            : .dateTime.year().month().day()

        VStack(alignment: .leading, spacing: spacing) {
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
                CountdownDays(countdown: countdown, now: now, size: countSize, unit: unit)

                Spacer(minLength: 4)

                CountdownStatusSymbol(countdown: countdown, now: now)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A countdown's count, in the unit its card on iPhone counts in.
struct CountdownDays: View {
    enum Size {
        /// As big as a city's time in the list.
        case list
        /// As big as a city's time in the City Time widget.
        case widget
        /// As big as a city's time in its details.
        case large
    }

    let countdown: WatchCountdown
    let now: Date
    var size: Size = .list
    /// The unit its card on iPhone counts in, or the one a tap on its
    /// details switched it to.
    let unit: CountdownUnit

    @Environment(\.fontResolutionContext) private var fontResolutionContext

    /// The list's digits and unit at the default text size.
    private static let listDigitsDefaultSize: CGFloat = 36
    private static let listUnitDefaultSize: CGFloat = 20

    @ScaledMetric(relativeTo: .largeTitle) private var listDigitsSize = CountdownDays.listDigitsDefaultSize
    @ScaledMetric(relativeTo: .largeTitle) private var listUnitSize = CountdownDays.listUnitDefaultSize
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

    /// `countdown`'s count in `unit`, held at the pause date while paused.
    static func count(of countdown: WatchCountdown, in unit: CountdownUnit, now: Date) -> CountdownCount {
        unit.count(from: countdown.pausedAt ?? now, to: countdown.effectiveTargetDate(at: now))
    }

    var body: some View {
        countText(Self.count(of: countdown, in: unit, now: now))
    }

    private var digitsSize: CGFloat {
        switch size {
        case .list: listDigitsSize
        case .widget: Self.listDigitsDefaultSize
        case .large: largeDigitsSize
        }
    }

    private var unitSize: CGFloat {
        switch size {
        case .list: listUnitSize
        case .widget: Self.listUnitDefaultSize
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
            .contentTransition(.numericText(value: Double(abs(count.value))))
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
