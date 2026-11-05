//
//  CityMoonCalendarPage.swift
//  touchtimeWatch
//

import SwiftUI

/// The selected day's month as a grid of its moons, laid out like the
/// iPhone's Moon Calendar widget: weeks start on the iPhone app's first day
/// of the week, under the weekdays' initials, and a dot marks the selected day.
struct CityMoonCalendarPage: View {
    let date: Date
    let timeZone: TimeZone
    /// 1 = Sunday, 2 = Monday, ...
    let firstWeekday: Int

    @Environment(\.locale) private var locale
    /// The weekday initials' size: caption2 on iPhone, smaller than any of
    /// the watch's text styles, and scaled with the wearer's text size.
    @ScaledMetric(relativeTo: .caption2) private var initialsSize: CGFloat = 11

    // The moon disc only spans ~86% of the photo. Scaling it inside the
    // circular clip crops the black margin away, as in the widget.
    private static let discCropScale: CGFloat = 1.18

    private static let columnSpacing: CGFloat = 4
    private static let rowSpacing: CGFloat = 2
    private static let dotGap: CGFloat = 2
    private static let dotSize: CGFloat = 3

    private struct Day {
        let start: Date
        let imageName: String
        let phase: MoonPhase
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = timeZone
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    var body: some View {
        let calendar = calendar
        let weeks = weeks(in: calendar)
        let selectedDayStart = calendar.startOfDay(for: date)
        // The symbols start on Sunday
        let initials = calendar.veryShortStandaloneWeekdaySymbols
        let orderedInitials = Array(initials[(firstWeekday - 1)...] + initials[..<(firstWeekday - 1)])

        VStack(spacing: 6) {
            HStack(spacing: Self.columnSpacing) {
                ForEach(orderedInitials.indices, id: \.self) { index in
                    Text(orderedInitials[index])
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.system(size: initialsSize, weight: .semibold))
            .foregroundStyle(.secondary)
            .blendMode(.plusLighter)
            .lineLimit(1)
            .accessibilityHidden(true)

            // Months span four to six weeks, so the moons shrink to fit six
            GeometryReader { geometry in
                let cellWidth = (geometry.size.width - Self.columnSpacing * 6) / 7
                let rowHeight = (geometry.size.height - Self.rowSpacing * CGFloat(weeks.count - 1)) / CGFloat(weeks.count)
                let moonSize = max(0, min(cellWidth, rowHeight - Self.dotGap - Self.dotSize))

                VStack(spacing: Self.rowSpacing) {
                    ForEach(weeks.indices, id: \.self) { week in
                        HStack(spacing: Self.columnSpacing) {
                            ForEach(weeks[week].indices, id: \.self) { weekday in
                                cell(weeks[week][weekday], moonSize: moonSize, selectedDayStart: selectedDayStart)
                                    .frame(width: cellWidth)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .scenePadding(.navigationBar, edges: .horizontal)
        .padding(.bottom, 8)
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private func cell(_ day: Day?, moonSize: CGFloat, selectedDayStart: Date) -> some View {
        if let day {
            VStack(spacing: Self.dotGap) {
                Image(day.imageName)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(Self.discCropScale)
                    .clipShape(.circle)
                    .grayscale(1)
                    .frame(width: moonSize, height: moonSize)

                // In every cell, so all the weeks are the same height
                Circle()
                    .fill(.white)
                    .frame(width: Self.dotSize, height: Self.dotSize)
                    .opacity(day.start == selectedDayStart ? 1 : 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(day.start.formatted(
                Date.FormatStyle(locale: locale, timeZone: timeZone).month(.wide).day()
            ))
            .accessibilityValue(day.phase.localizedName)
            .accessibilityAddTraits(day.start == selectedDayStart ? .isSelected : [])
        } else {
            // A blank before the 1st, under the weekdays before its own
            Color.clear
                .frame(width: moonSize, height: moonSize + Self.dotGap + Self.dotSize)
        }
    }

    /// The month's days in weeks of seven, with blanks before the 1st.
    private func weeks(in calendar: Calendar) -> [[Day?]] {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let dayCount = calendar.range(of: .day, in: .month, for: date)?.count else {
            return []
        }
        let leadingBlanks = (calendar.component(.weekday, from: month.start) - calendar.firstWeekday + 7) % 7

        var days: [Day?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<dayCount {
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: month.start) else { continue }
            let moonDay = MoonDay(containing: dayStart, calendar: calendar)
            // The age at the day's start, rounded, as in the iPhone's moon
            // calendar and widget. It wraps back to new moon after ~29.5 days.
            days.append(Day(
                start: dayStart,
                imageName: String(format: "moon_age_%02d", Int(moonDay.ageDaysAtStart.rounded()) % 30),
                phase: moonDay.phase
            ))
        }
        return stride(from: 0, to: days.count, by: 7).map {
            Array(days[$0..<min($0 + 7, days.count)])
        }
    }
}
