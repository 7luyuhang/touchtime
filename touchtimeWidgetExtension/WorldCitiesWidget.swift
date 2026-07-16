//
//  WorldCitiesWidget.swift
//  touchtimeWidgetExtension
//
//  Medium widget: the first four saved cities side by side, each column
//  showing a configurable complication with name / time below. Tapping a
//  city repaints the whole background with that city's sky colours
//  (defaults to the first city).
//

import WidgetKit
import SwiftUI
import AppIntents
import WeatherKit

// MARK: - Configuration

struct WorldCitiesIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "World Cities"
    static let description = IntentDescription("Choose a complication to display.")

    @Parameter(title: "Complication", default: .analogClock)
    var complication: WidgetComplicationKind
}

// MARK: - Timeline

struct WorldCityItem: Identifiable {
    let id: String
    let cityName: String
    let timeZoneIdentifier: String

    init(id: String, cityName: String, timeZoneIdentifier: String) {
        self.id = id
        self.cityName = cityName
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    // Same stable id scheme as CityEntity: "<cityName>|<timeZoneIdentifier>"
    init(clock: WorldClock) {
        self.init(
            id: "\(clock.cityName)|\(clock.timeZoneIdentifier)",
            cityName: clock.localizedCityName,
            timeZoneIdentifier: clock.timeZoneIdentifier
        )
    }
}

struct WorldCitiesEntry: TimelineEntry {
    let date: Date
    let cities: [WorldCityItem]
    let selectedCityId: String?
    let complication: WidgetComplicationKind
    let use24Hour: Bool
    var weatherCondition: WeatherCondition? = nil

    var selectedCity: WorldCityItem? {
        cities.first { $0.id == selectedCityId } ?? cities.first
    }
}

struct WorldCitiesProvider: AppIntentTimelineProvider {
    private struct ResolvedCities {
        let cities: [WorldCityItem]
        let selected: WorldCityItem?
    }

    // First four saved cities, plus the last tapped one if it still exists
    // in the list; otherwise (never tapped, or deleted in the app) the
    // selection defaults to the first city.
    private func resolveCities() -> ResolvedCities {
        let cities = SharedWidgetStore.loadWorldClocks().prefix(4).map { WorldCityItem(clock: $0) }
        let storedId = SharedWidgetStore.worldCitiesSelectedCityId()
        let selected = cities.first { $0.id == storedId } ?? cities.first
        return ResolvedCities(cities: Array(cities), selected: selected)
    }

    private func makeEntry(
        for configuration: WorldCitiesIntent,
        resolved: ResolvedCities,
        date: Date,
        weatherCondition: WeatherCondition?
    ) -> WorldCitiesEntry {
        WorldCitiesEntry(
            date: date,
            cities: resolved.cities,
            selectedCityId: resolved.selected?.id,
            complication: configuration.complication,
            use24Hour: SharedWidgetStore.use24HourFormat(),
            weatherCondition: weatherCondition
        )
    }

    func placeholder(in context: Context) -> WorldCitiesEntry {
        WorldCitiesEntry(
            date: Date(),
            cities: WorldClockData.defaultClocks.prefix(4).map { WorldCityItem(clock: $0) },
            selectedCityId: nil,
            complication: .analogClock,
            use24Hour: false
        )
    }

    func snapshot(for configuration: WorldCitiesIntent, in context: Context) async -> WorldCitiesEntry {
        // Snapshots must render fast: use the stored condition, no fetching.
        let resolved = resolveCities()
        let condition = resolved.selected.flatMap { SharedWidgetStore.weatherCondition(for: $0.timeZoneIdentifier) }
        return makeEntry(for: configuration, resolved: resolved, date: Date(), weatherCondition: condition)
    }

    func timeline(for configuration: WorldCitiesIntent, in context: Context) async -> Timeline<WorldCitiesEntry> {
        let resolved = resolveCities()

        // Refresh all four cities per reload (not just the selected one) so a
        // tap on any city finds a fresh cached condition and repaints its
        // weather sky instantly, without waiting on WeatherKit.
        let conditions = await WidgetWeatherFetcher.conditions(for: resolved.cities.map(\.timeZoneIdentifier))
        let condition = resolved.selected.flatMap { conditions[$0.timeZoneIdentifier] }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        // One entry per minute for the next hour, aligned to minute boundaries
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let start = calendar.date(from: components) ?? now

        var entries: [WorldCitiesEntry] = []
        for minuteOffset in 0..<60 {
            if let date = calendar.date(byAdding: .minute, value: minuteOffset, to: start) {
                entries.append(makeEntry(for: configuration, resolved: resolved, date: date, weatherCondition: condition))
            }
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - View

struct WorldCitiesWidgetView: View {
    var entry: WorldCitiesEntry

    @Environment(\.redactionReasons) private var redactionReasons

    var body: some View {
        HStack(spacing: 8) {
            ForEach(entry.cities) { city in
                Button(intent: SelectWorldCityIntent(cityId: city.id)) {
                    WorldCityColumn(
                        city: city,
                        date: entry.date,
                        complication: entry.complication,
                        use24Hour: entry.use24Hour,
                        isSelected: city.id == entry.selectedCity?.id,
                        isPlaceholder: redactionReasons.contains(.placeholder)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .containerBackground(for: .widget) {
            // Sky of the selected city.
            WidgetSkyBackground(
                date: entry.date,
                timeZoneIdentifier: entry.selectedCity?.timeZoneIdentifier ?? "Europe/London",
                weatherCondition: entry.weatherCondition
            )
        }
    }
}

private struct WorldCityColumn: View {
    let city: WorldCityItem
    let date: Date
    let complication: WidgetComplicationKind
    let use24Hour: Bool
    let isSelected: Bool
    let isPlaceholder: Bool

    private static let clockSize: CGFloat = 68

    private var timeZone: TimeZone {
        TimeZone(identifier: city.timeZoneIdentifier) ?? .current
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mm"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if isPlaceholder {
                    Circle()
                        .fill(.white.opacity(0.10))
                } else {
                    complicationView
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.10), lineWidth: 1.50)
                                .blendMode(.plusLighter)
                        }
                }
            }
            .frame(width: Self.clockSize, height: Self.clockSize)
            
            VStack(spacing: 0) {
                Text(city.cityName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text(timeString)
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? HierarchicalShapeStyle.primary : .secondary)
                    .blendMode(.plusLighter)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var complicationView: some View {
        let size = Self.clockSize
        switch complication {
        case .analogClock:
            AnalogClockView(date: date, size: size, timeZone: timeZone)
        case .sunPosition:
            SunPositionIndicator(date: date, timeZone: timeZone, size: size)
        case .sunriseSunset:
            SunriseSunsetIndicator(date: date, timeZone: timeZone, size: size)
        case .sunAzimuth:
            SunAzimuthIndicator(date: date, timeZone: timeZone, size: size)
        case .solarCurve:
            SolarCurve(date: date, timeZone: timeZone, size: size)
        }
    }
}

// MARK: - Widget

struct WorldCitiesWidget: Widget {
    static let kind = "WorldCitiesWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: WorldCitiesIntent.self,
            provider: WorldCitiesProvider()
        ) { entry in
            WorldCitiesWidgetView(entry: entry)
        }
        .configurationDisplayName("World Cities")
        .description("Shows four cities at a glance. Tap one to switch the sky background.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}
