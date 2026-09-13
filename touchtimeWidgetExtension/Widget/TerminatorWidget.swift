//
//  TerminatorWidget.swift
//  touchtimeWidgetExtension
//
//  Medium widget: the app's dotted world map with the chosen city
//  highlighted and the solar terminator (the day/night line) for the current
//  time. The city's time sits in the bottom-left corner and its name on the
//  right, over the city's sky gradient background.
//

import WidgetKit
import SwiftUI
import AppIntents
import WeatherKit

// MARK: - Intent

struct TerminatorWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Day & Night"
    static let description = IntentDescription("Choose a city to display.")

    // Same city picker as the City Time widget (CityComplicationIntent).
    @Parameter(title: "City")
    var city: CityEntity?
}

// MARK: - Timeline

struct TerminatorWidgetEntry: TimelineEntry {
    let date: Date
    let cityName: String
    let timeZoneIdentifier: String
    let use24Hour: Bool
    var weatherCondition: WeatherCondition? = nil
}

struct TerminatorWidgetProvider: AppIntentTimelineProvider {
    // Only honour the configured city if it still exists in the app's saved
    // list; otherwise (deleted in the app) fall back to the first saved city.
    private func resolveCity(for configuration: TerminatorWidgetIntent) -> CityEntity? {
        let savedCities = SharedWidgetStore.loadWorldClocks().map { CityEntity(clock: $0) }
        if let selected = configuration.city,
           savedCities.contains(where: { $0.id == selected.id }) {
            return selected
        }
        return savedCities.first
    }

    private func makeEntry(
        city: CityEntity?,
        date: Date,
        weatherCondition: WeatherCondition?
    ) -> TerminatorWidgetEntry {
        TerminatorWidgetEntry(
            date: date,
            cityName: city?.cityName ?? "London",
            timeZoneIdentifier: city?.timeZoneIdentifier ?? "Europe/London",
            use24Hour: SharedWidgetStore.use24HourFormat(),
            weatherCondition: weatherCondition
        )
    }

    func placeholder(in context: Context) -> TerminatorWidgetEntry {
        TerminatorWidgetEntry(
            date: Date(),
            cityName: "London",
            timeZoneIdentifier: "Europe/London",
            use24Hour: false
        )
    }

    func snapshot(for configuration: TerminatorWidgetIntent, in context: Context) async -> TerminatorWidgetEntry {
        // Snapshots must render fast: use the stored condition, no fetching.
        let city = resolveCity(for: configuration)
        let condition = (city?.timeZoneIdentifier).flatMap { SharedWidgetStore.weatherCondition(for: $0) }
        return makeEntry(city: city, date: Date(), weatherCondition: condition)
    }

    func timeline(for configuration: TerminatorWidgetIntent, in context: Context) async -> Timeline<TerminatorWidgetEntry> {
        let city = resolveCity(for: configuration)

        // Refresh the weather sky once per timeline reload so rain skies
        // keep working even when the app hasn't been opened for hours.
        let timeZoneIdentifier = city?.timeZoneIdentifier ?? "Europe/London"
        let condition = await WidgetWeatherFetcher.conditions(for: [timeZoneIdentifier])[timeZoneIdentifier]

        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        // One entry per minute for the next hour, aligned to minute boundaries
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let start = calendar.date(from: components) ?? now

        var entries: [TerminatorWidgetEntry] = []
        for minuteOffset in 0..<60 {
            if let date = calendar.date(byAdding: .minute, value: minuteOffset, to: start) {
                entries.append(makeEntry(city: city, date: date, weatherCondition: condition))
            }
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - View

struct TerminatorWidgetView: View {
    var entry: TerminatorWidgetEntry

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

    var body: some View {
        ZStack(alignment: .bottom) {
            // Stretched over the whole 8pt-inset content area, so the full
            // ±90° canvas is visible and the terminator turns around inside
            // the widget exactly as it does in the app's map; the medium
            // family (about 2.3:1 here vs the canvas's 16:9) squashes the
            // map vertically by about a fifth to get there.
            DotsWorldMapCanvas(
                timeZoneIdentifiers: [entry.timeZoneIdentifier],
                date: entry.date,
                sizing: .stretch
            )

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(timeString)
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()

                Spacer(minLength: 0)

                // Keeps any emoji in the name shaded in the Clear and
                // Tinted modes instead of a flattened white blob.
                ColorEmojiText(entry.cityName)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            // 16pt from the widget's sides and 24pt from its bottom once the
            // 8pt content inset below is added: that puts the text in the
            // Southern Ocean band of the stretched map (about 50°S–65°S),
            // above Antarctica's dot rows and the terminator's southern
            // turnaround instead of on top of them.
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .foregroundStyle(.white)
        .padding(8)
        .containerBackground(for: .widget) {
            WidgetSkyBackground(
                date: entry.date,
                timeZoneIdentifier: entry.timeZoneIdentifier,
                weatherCondition: entry.weatherCondition
            )
        }
    }
}

// MARK: - Widget

struct TerminatorWidget: Widget {
    let kind: String = "TerminatorWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TerminatorWidgetIntent.self,
            provider: TerminatorWidgetProvider()
        ) { entry in
            TerminatorWidgetView(entry: entry)
        }
        .configurationDisplayName("Day & Night")
        .description("Shows a city's time on the world map with the day/night line.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}
