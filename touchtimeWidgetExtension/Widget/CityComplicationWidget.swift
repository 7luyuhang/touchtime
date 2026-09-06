//
//  CityComplicationWidget.swift
//  touchtimeWidgetExtension
//
//  Small widget: city name on top, complication in the center (90x90),
//  time at the bottom, sky gradient background.
//

import WidgetKit
import SwiftUI
import WeatherKit

// MARK: - Timeline

struct CityComplicationEntry: TimelineEntry {
    let date: Date
    let cityName: String
    let timeZoneIdentifier: String
    let complication: WidgetComplicationKind
    let use24Hour: Bool
    var weatherCondition: WeatherCondition? = nil
    // Complication customisations mirrored from the app via the App Group
    var analogClockShowScale: Bool = false
    var analogClockShowUTCHand: Bool = false
    var solarCurveShowSun: Bool = false
}

struct CityComplicationProvider: AppIntentTimelineProvider {
    // Only honour the configured city if it still exists in the app's saved
    // list; otherwise (deleted in the app) fall back to the first saved city.
    private func resolveCity(for configuration: CityComplicationIntent) -> CityEntity? {
        let savedCities = SharedWidgetStore.loadWorldClocks().map { CityEntity(clock: $0) }
        if let selected = configuration.city,
           savedCities.contains(where: { $0.id == selected.id }) {
            return selected
        }
        return savedCities.first
    }

    private func makeEntry(
        for configuration: CityComplicationIntent,
        city: CityEntity?,
        date: Date,
        weatherCondition: WeatherCondition?
    ) -> CityComplicationEntry {
        CityComplicationEntry(
            date: date,
            cityName: city?.cityName ?? "London",
            timeZoneIdentifier: city?.timeZoneIdentifier ?? "Europe/London",
            complication: configuration.complication,
            use24Hour: SharedWidgetStore.use24HourFormat(),
            weatherCondition: weatherCondition,
            analogClockShowScale: SharedWidgetStore.analogClockShowScale(),
            analogClockShowUTCHand: SharedWidgetStore.analogClockShowUTCHand(),
            solarCurveShowSun: SharedWidgetStore.solarCurveShowSun()
        )
    }

    func placeholder(in context: Context) -> CityComplicationEntry {
        CityComplicationEntry(
            date: Date(),
            cityName: "London",
            timeZoneIdentifier: "Europe/London",
            complication: .sunriseSunset,
            use24Hour: false
        )
    }

    func snapshot(for configuration: CityComplicationIntent, in context: Context) async -> CityComplicationEntry {
        // Snapshots must render fast: use the stored condition, no fetching.
        let city = resolveCity(for: configuration)
        let condition = (city?.timeZoneIdentifier).flatMap { SharedWidgetStore.weatherCondition(for: $0) }
        return makeEntry(for: configuration, city: city, date: Date(), weatherCondition: condition)
    }

    func timeline(for configuration: CityComplicationIntent, in context: Context) async -> Timeline<CityComplicationEntry> {
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

        var entries: [CityComplicationEntry] = []
        for minuteOffset in 0..<60 {
            if let date = calendar.date(byAdding: .minute, value: minuteOffset, to: start) {
                entries.append(makeEntry(for: configuration, city: city, date: date, weatherCondition: condition))
            }
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - View

struct CityComplicationWidgetView: View {
    var entry: CityComplicationEntry

    @Environment(\.redactionReasons) private var redactionReasons

    private static let complicationSize: CGFloat = 80

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
        ZStack {
            Group {
                if redactionReasons.contains(.placeholder) {
                    // Loading/placeholder state
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
            .frame(width: Self.complicationSize, height: Self.complicationSize)

            VStack {
                Text(entry.cityName)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 8)

                Spacer(minLength: 0)

                Text(timeString)
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .containerBackground(for: .widget) {
            WidgetSkyBackground(
                date: entry.date,
                timeZoneIdentifier: entry.timeZoneIdentifier,
                weatherCondition: entry.weatherCondition
            )
        }
    }

    @ViewBuilder
    private var complicationView: some View {
        let size = Self.complicationSize
        switch entry.complication {
        case .analogClock:
            AnalogClockView(
                date: entry.date,
                size: size,
                timeZone: timeZone,
                showScale: entry.analogClockShowScale,
                showUTCHand: entry.analogClockShowUTCHand
            )
        case .sunPosition:
            SunPositionIndicator(date: entry.date, timeZone: timeZone, size: size)
        case .sunriseSunset:
            SunriseSunsetIndicator(date: entry.date, timeZone: timeZone, size: size)
        case .sunAzimuth:
            SunAzimuthIndicator(date: entry.date, timeZone: timeZone, size: size)
        case .solarCurve:
            SolarCurve(date: entry.date, timeZone: timeZone, size: size, showSun: entry.solarCurveShowSun)
        }
    }
}

// MARK: - Widget

struct CityComplicationWidget: Widget {
    let kind: String = "CityComplicationWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: CityComplicationIntent.self,
            provider: CityComplicationProvider()
        ) { entry in
            CityComplicationWidgetView(entry: entry)
        }
        .configurationDisplayName("City Time")
        .description("Shows a city's time with a complication in the center.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
