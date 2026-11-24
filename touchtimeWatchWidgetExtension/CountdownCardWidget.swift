//
//  CountdownCardWidget.swift
//  touchtimeWatchWidgetExtension
//
//  A countdown's card from the watch app's list, for the Smart Stack: its
//  title, date, count and symbol, over its cover's colour or photo.
//

import SwiftUI
import WidgetKit

// MARK: - Timeline

struct CountdownCardEntry: TimelineEntry {
    let date: Date
    /// Nil while the iPhone has no countdowns.
    let countdown: WatchCountdown?
    let unit: CountdownUnit
}

struct CountdownCardProvider: AppIntentTimelineProvider {
    /// None, which has the watch ask for the countdown when the widget's
    /// added, rather than offer a widget for each.
    func recommendations() -> [AppIntentRecommendation<CountdownCardIntent>] {
        []
    }

    func placeholder(in context: Context) -> CountdownCardEntry {
        entries(for: CountdownCardIntent(), from: .now)[0]
    }

    func snapshot(for configuration: CountdownCardIntent, in context: Context) async -> CountdownCardEntry {
        entries(for: configuration, from: .now)[0]
    }

    func timeline(for configuration: CountdownCardIntent, in context: Context) async -> Timeline<CountdownCardEntry> {
        Timeline(entries: entries(for: configuration, from: .now), policy: .atEnd)
    }

    /// The configured countdown from `start`, then at each of the next seven
    /// midnights, when its count, and a repeating one's date, turn over.
    private func entries(for configuration: CountdownCardIntent, from start: Date) -> [CountdownCardEntry] {
        let countdowns = WatchWidgetStore.countdowns
        // The iPhone's first countdown once the picked one is gone from its list
        let countdown = countdowns.first { $0.id == configuration.countdown?.id } ?? countdowns.first
        let unit = WatchWidgetStore.countdownUnit
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: start)
        let midnights = (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        return ([start] + midnights).map { date in
            CountdownCardEntry(date: date, countdown: countdown, unit: unit)
        }
    }
}

// MARK: - View

struct CountdownCardWidgetView: View {
    let entry: CountdownCardEntry

    var body: some View {
        Group {
            if let countdown = entry.countdown {
                // Spaced as the City Time widget's card, which leaves the
                // count as big as in the list
                CountdownCard(countdown: countdown, now: entry.date, unit: entry.unit, spacing: 7, countSize: .widget)
            } else {
                Text("No Countdowns")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 7)
        .padding(.bottom, 2)
        .containerBackground(for: .widget) {
            if let background = entry.countdown?.background {
                CountdownBackground(background: background)
            } else {
                Rectangle()
                    .fill(.fill.tertiary)
            }
        }
    }
}

// MARK: - Widget

struct CountdownCardWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "CountdownCardWidget",
            intent: CountdownCardIntent.self,
            provider: CountdownCardProvider()
        ) { entry in
            CountdownCardWidgetView(entry: entry)
        }
        .configurationDisplayName("Countdown")
        .description("Shows the time to an event and its date.")
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
    }
}
