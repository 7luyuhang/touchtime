//
//  CityCardWidget.swift
//  touchtimeWatchWidgetExtension
//
//  A city's card from the watch app's list, for the Smart Stack: its name,
//  date, time and time shift, over the sky there.
//

import SwiftUI
import WeatherKit
import WidgetKit

// MARK: - Timeline

struct CityCardEntry: TimelineEntry {
    let date: Date
    let city: ClockCity
    let dateStyle: String
    let weatherCondition: WeatherCondition?
}

struct CityCardProvider: AppIntentTimelineProvider {
    /// None, which has the watch ask for the city when the widget's added,
    /// rather than offer a widget for each.
    func recommendations() -> [AppIntentRecommendation<CityCardIntent>] {
        []
    }

    func placeholder(in context: Context) -> CityCardEntry {
        entries(for: CityCardIntent(), from: .now, count: 1)[0]
    }

    func snapshot(for configuration: CityCardIntent, in context: Context) async -> CityCardEntry {
        entries(for: configuration, from: .now, count: 1)[0]
    }

    func timeline(for configuration: CityCardIntent, in context: Context) async -> Timeline<CityCardEntry> {
        // A minute at a time for the next hour, from the start of this one
        let start = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
        return Timeline(entries: entries(for: configuration, from: start, count: 60), policy: .atEnd)
    }

    /// The configured city a minute apart from `start`, in the iPhone's date
    /// style, under the weather the app last fetched there.
    private func entries(for configuration: CityCardIntent, from start: Date, count: Int) -> [CityCardEntry] {
        // The watch's own clock once the city is gone from the iPhone's list
        let city = WatchWidgetStore.cities.first { $0.id == configuration.city?.id } ?? .local
        let dateStyle = WatchWidgetStore.dateStyle
        let weatherCondition = WatchWidgetStore.weatherCondition(for: city.timeZone.identifier)
        return (0..<count).map { minute in
            CityCardEntry(
                date: start.addingTimeInterval(TimeInterval(minute * 60)),
                city: city,
                dateStyle: dateStyle,
                weatherCondition: weatherCondition
            )
        }
    }
}

// MARK: - View

struct CityCardWidgetView: View {
    let entry: CityCardEntry

    var body: some View {
        // Less space around the name than in the list's rows, which are
        // taller, so the time is as big
        CityCard(city: entry.city, date: entry.date, now: entry.date, dateStyle: entry.dateStyle, spacing: 10, timeSize: .widget)
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 2)
            .defaultAppStorage(WatchWidgetStore.defaults)
            .containerBackground(for: .widget) {
                CityCardSky(date: entry.date, timeZone: entry.city.timeZone, weatherCondition: entry.weatherCondition)
            }
    }
}

/// The sky over the city, as its row in the app's list shows it.
private struct CityCardSky: View {
    let date: Date
    let timeZone: TimeZone
    let weatherCondition: WeatherCondition?

    var body: some View {
        let sky = SkyColorGradient(
            date: date,
            timeZoneIdentifier: timeZone.identifier,
            weatherCondition: weatherCondition
        )

        ZStack {
            Rectangle()
                .fill(sky.linearGradientOverBlack(opacity: 0.65))

            if sky.starOpacity > 0 {
                // As many as on the list's rows, which are about as big
                WidgetStarsView(seed: timeZone.identifier, starCount: 12)
                    .opacity(sky.starOpacity)
                    .blendMode(.plusLighter)
            }
        }
    }
}

// MARK: - Widget

struct CityCardWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "CityCardWidget",
            intent: CityCardIntent.self,
            provider: CityCardProvider()
        ) { entry in
            CityCardWidgetView(entry: entry)
        }
        .configurationDisplayName("City Time")
        .description("Shows a city's time, date and sky.")
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
    }
}
