//
//  MoonCalendarWidget.swift
//  touchtimeWidgetExtension
//
//  Small widget: the current month as a grid of moon phases in the same
//  Monday-first weekday-aligned layout as the app's Moon Phase calendar —
//  just the moons, no weekday headers or day numbers — with a small dot
//  under today's moon. Same grayscale disc treatment as the app.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct MoonCalendarWidgetEntry: TimelineEntry {
    let date: Date
    /// One cell per grid slot in the app calendar's Monday-first layout:
    /// nil for the blank slots before the 1st, then one image name
    /// (moon_age_00...29) per day of the month.
    let cells: [String?]
    /// Index of today's cell within `cells`.
    let todayIndex: Int
}

struct MoonCalendarWidgetProvider: TimelineProvider {
    // The whole month is computed with the lightweight MoonAstronomy math
    // (a handful of trig calls per day) instead of MoonKit's Moon, whose
    // per-day moonrise/moonset search across 31 days could push the
    // timeline past WidgetKit's budget on slow devices.
    private func makeEntry(for date: Date) -> MoonCalendarWidgetEntry {
        let calendar = Calendar.current
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)
        ) ?? date
        let dayCount = calendar.range(of: .day, in: .month, for: date)?.count ?? 30

        // Blank slots align day 1 to its weekday column, Monday-first,
        // mirroring the app's moon phase calendar (MoonPhaseView).
        let weekdayOfFirst = calendar.component(.weekday, from: monthStart) // 1 = Sunday
        let leadingBlanks = (weekdayOfFirst + 5) % 7

        var cells: [String?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<dayCount {
            let dayStart = calendar.date(byAdding: .day, value: offset, to: monthStart) ?? monthStart
            // Same day-start age rounding as the app's moon phase calendar
            // (MoonPhaseCache), so the grid always matches it. The age wraps
            // at the end of the synodic cycle (~29.5 days) back to new moon.
            let age = MoonAstronomy.snapshot(for: dayStart).ageDays
            cells.append(String(format: "moon_age_%02d", Int(age.rounded()) % 30))
        }

        return MoonCalendarWidgetEntry(
            date: date,
            cells: cells,
            todayIndex: leadingBlanks + calendar.component(.day, from: date) - 1
        )
    }

    func placeholder(in context: Context) -> MoonCalendarWidgetEntry {
        makeEntry(for: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (MoonCalendarWidgetEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoonCalendarWidgetEntry>) -> Void) {
        // The grid only changes at local midnight (the dot moves, and on the
        // first of a month the whole grid turns over): one entry now plus one
        // at each of the next few midnights, each computed for its own day.
        let now = Date()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)

        var dates = [now]
        for day in 1...7 {
            if let midnight = calendar.date(byAdding: .day, value: day, to: todayStart) {
                dates.append(midnight)
            }
        }

        completion(Timeline(entries: dates.map(makeEntry(for:)), policy: .atEnd))
    }
}

// MARK: - View

struct MoonCalendarWidgetView: View {
    var entry: MoonCalendarWidgetEntry

    // The moon disc only spans ~86% of the source photo (626px of 730px),
    // the rest is black margin. Scaling inside the circular clip crops that
    // margin away, matching MoonPhaseWidget and the app's calendar cells.
    private static let discCropScale: CGFloat = 1.18

    private static let columnSpacing: CGFloat = 4
    private static let rowSpacing: CGFloat = 2
    private static let dotGap: CGFloat = 2
    private static let dotSize: CGFloat = 3

    private var rows: [[(index: Int, imageName: String?)]] {
        let cells = entry.cells.enumerated().map { (index: $0.offset, imageName: $0.element) }
        return stride(from: 0, to: cells.count, by: 7).map {
            Array(cells[$0..<min($0 + 7, cells.count)])
        }
    }

    // No blend mode here on purpose: WidgetKit composites the content and
    // the container background in separate layers, so a plusLighter moon
    // can end up blending against nothing and vanish (see MoonPhaseWidget).
    var body: some View {
        // Weekday-aligned months span 4 to 6 rows, so the cell size is
        // computed from the available space instead of letting a grid
        // overflow the widget on 6-row months.
        GeometryReader { geometry in
            let rows = self.rows
            let rowCount = CGFloat(rows.count)
            let cellWidth = (geometry.size.width - Self.columnSpacing * 6) / 7
            let cellHeight = (geometry.size.height - Self.rowSpacing * (rowCount - 1)) / rowCount
            let moonSize = min(cellWidth, cellHeight - Self.dotGap - Self.dotSize)

            VStack(spacing: Self.rowSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: Self.columnSpacing) {
                        ForEach(row, id: \.index) { cell in
                            VStack(spacing: Self.dotGap) {
                                if let imageName = cell.imageName {
                                    Image(imageName)
                                        .resizable()
                                        .widgetAccentedRenderingMode(.desaturated)
                                        .scaledToFit()
                                        .scaleEffect(Self.discCropScale)
                                        .clipShape(Circle())
                                        .grayscale(1)
                                        .frame(width: moonSize, height: moonSize)
                                } else {
                                    // Blank slot before the 1st of the month
                                    Color.clear
                                        .frame(width: moonSize, height: moonSize)
                                }

                                // Today marker; kept in every cell (opacity 0
                                // elsewhere) so all rows keep the same height.
                                Circle()
                                    .fill(.white)
                                    .frame(width: Self.dotSize, height: Self.dotSize)
                                    .opacity(cell.index == entry.todayIndex ? 1 : 0)
                            }
                            .frame(width: cellWidth, height: cellHeight)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            // Keep the widget black in both color schemes, matching the
            // night-sky look of the app's moon sheet.
            Color.black
        }
    }
}

// MARK: - Widget

struct MoonCalendarWidget: Widget {
    let kind: String = "MoonCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: MoonCalendarWidgetProvider()
        ) { entry in
            MoonCalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("Moon Calendar")
        .description("Shows this month's moon phases with today marked.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
