//
//  CityComplicationWidget.swift
//  touchtimeWidgetExtension
//
//  Small widget: city name on top, complication in the center (90x90),
//  time at the bottom, sky gradient background.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct CityComplicationEntry: TimelineEntry {
    let date: Date
    let cityName: String
    let timeZoneIdentifier: String
    let complication: WidgetComplicationKind
    let use24Hour: Bool
}

struct CityComplicationProvider: AppIntentTimelineProvider {
    private func makeEntry(for configuration: CityComplicationIntent, date: Date) -> CityComplicationEntry {
        let savedCities = SharedWidgetStore.loadWorldClocks().map { CityEntity(clock: $0) }

        // Only honour the configured city if it still exists in the app's saved
        // list; otherwise (deleted in the app) fall back to the first saved city.
        let city: CityEntity?
        if let selected = configuration.city,
           savedCities.contains(where: { $0.id == selected.id }) {
            city = selected
        } else {
            city = savedCities.first
        }
        return CityComplicationEntry(
            date: date,
            cityName: city?.cityName ?? "London",
            timeZoneIdentifier: city?.timeZoneIdentifier ?? "Europe/London",
            complication: configuration.complication,
            use24Hour: SharedWidgetStore.use24HourFormat()
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
        makeEntry(for: configuration, date: Date())
    }

    func timeline(for configuration: CityComplicationIntent, in context: Context) async -> Timeline<CityComplicationEntry> {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        // One entry per minute for the next hour, aligned to minute boundaries
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let start = calendar.date(from: components) ?? now

        var entries: [CityComplicationEntry] = []
        for minuteOffset in 0..<60 {
            if let date = calendar.date(byAdding: .minute, value: minuteOffset, to: start) {
                entries.append(makeEntry(for: configuration, date: date))
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
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 8)

                Spacer(minLength: 0)

                Text(timeString)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .containerBackground(for: .widget) {
            let gradient = SkyColorGradient(
                date: entry.date,
                timeZoneIdentifier: entry.timeZoneIdentifier
            )
            gradient.linearGradient()
                .overlay {
                    Color.black.opacity(0.20)
                        .blendMode(.plusDarker)
                }
                .overlay {
                    if gradient.starOpacity > 0 {
                        WidgetStarsView(seed: entry.timeZoneIdentifier)
                            .opacity(gradient.starOpacity)
                            .blendMode(.plusLighter)
                    }
                }
        }
    }

    @ViewBuilder
    private var complicationView: some View {
        let size = Self.complicationSize
        switch entry.complication {
        case .analogClock:
            AnalogClockView(date: entry.date, size: size, timeZone: timeZone)
        case .sunPosition:
            SunPositionIndicator(date: entry.date, timeZone: timeZone, size: size)
        case .sunriseSunset:
            SunriseSunsetIndicator(date: entry.date, timeZone: timeZone, size: size)
        case .sunAzimuth:
            SunAzimuthIndicator(date: entry.date, timeZone: timeZone, size: size)
        case .solarCurve:
            SolarCurve(date: entry.date, timeZone: timeZone, size: size)
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
