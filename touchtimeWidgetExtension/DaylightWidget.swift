//
//  DaylightWidget.swift
//  touchtimeWidgetExtension
//
//  Small widget: the city's 24-hour sky wrapped into a ring (same colors
//  as the app's Daylight sheet), a sun indicator at the current time, and
//  the city's time and name in the center.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Intent

struct DaylightWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Daylight"
    static let description = IntentDescription("Choose a city to display.")

    @Parameter(title: "City")
    var city: CityEntity?
}

// MARK: - Timeline

struct DaylightWidgetEntry: TimelineEntry {
    let date: Date
    let cityName: String
    let timeZoneIdentifier: String
    let use24Hour: Bool
}

struct DaylightWidgetProvider: AppIntentTimelineProvider {
    // Only honour the configured city if it still exists in the app's saved
    // list; otherwise (deleted in the app) fall back to the first saved city.
    private func resolveCity(for configuration: DaylightWidgetIntent) -> CityEntity? {
        let savedCities = SharedWidgetStore.loadWorldClocks().map { CityEntity(clock: $0) }
        if let selected = configuration.city,
           savedCities.contains(where: { $0.id == selected.id }) {
            return selected
        }
        return savedCities.first
    }

    private func makeEntry(city: CityEntity?, date: Date) -> DaylightWidgetEntry {
        DaylightWidgetEntry(
            date: date,
            cityName: city?.cityName ?? "London",
            timeZoneIdentifier: city?.timeZoneIdentifier ?? "Europe/London",
            use24Hour: SharedWidgetStore.use24HourFormat()
        )
    }

    func placeholder(in context: Context) -> DaylightWidgetEntry {
        DaylightWidgetEntry(
            date: Date(),
            cityName: "London",
            timeZoneIdentifier: "Europe/London",
            use24Hour: false
        )
    }

    func snapshot(for configuration: DaylightWidgetIntent, in context: Context) async -> DaylightWidgetEntry {
        makeEntry(city: resolveCity(for: configuration), date: Date())
    }

    func timeline(for configuration: DaylightWidgetIntent, in context: Context) async -> Timeline<DaylightWidgetEntry> {
        let city = resolveCity(for: configuration)

        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        // One entry per minute for the next hour, aligned to minute boundaries
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let start = calendar.date(from: components) ?? now

        var entries: [DaylightWidgetEntry] = []
        for minuteOffset in 0..<60 {
            if let date = calendar.date(byAdding: .minute, value: minuteOffset, to: start) {
                entries.append(makeEntry(city: city, date: date))
            }
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - View

struct DaylightWidgetView: View {
    var entry: DaylightWidgetEntry

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme

    private var timeZone: TimeZone {
        TimeZone(identifier: entry.timeZoneIdentifier) ?? .current
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = entry.use24Hour ? "HH:mm" : "h:mm"
        return formatter.string(from: entry.date)
    }

    // City-local date via the app's shared formatter, weekday omitted.
    private var dateString: String {
        entry.date.formattedDate(style: "Date Only", timeZone: timeZone)
    }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let ringWidth = side * 0.20
            let holeDiameter = side - ringWidth * 2

            ZStack {
                DaylightRing(
                    date: entry.date,
                    timeZoneIdentifier: entry.timeZoneIdentifier,
                    size: side,
                    ringWidth: ringWidth,
                    monochrome: renderingMode != .fullColor
                )

                VStack(spacing: 0) {
                    Text(timeString)
                        .font(.system(size: 15, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    Text(dateString)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(width: holeDiameter * 0.75)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            // Explicit white/black instead of systemBackground: widgets can
            // resolve the "elevated" dark variant (#1C1C1E) otherwise.
            colorScheme == .dark ? Color.black : Color.white
        }
    }
}

// The 24-hour sky ring itself (DaylightRing) lives in Shared/, so the
// app's widget intro sheet can render the same ring in its preview.

// MARK: - Widget

struct DaylightWidget: Widget {
    let kind: String = "DaylightWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: DaylightWidgetIntent.self,
            provider: DaylightWidgetProvider()
        ) { entry in
            DaylightWidgetView(entry: entry)
        }
        .configurationDisplayName("Daylight")
        .description("Shows a city's time at the center of its 24-hour sky ring.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
