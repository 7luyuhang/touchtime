//
//  WatchWidgetStore.swift
//  touchtimeWatch
//
//  What the City Time and Countdown widgets show, copied by the watch app
//  into the App Group it shares with its widget extension, which can't read
//  the app's own defaults: the iPhone's cities, date style, countdowns and
//  the unit they count in, the 24-Hour Format and Additional Time settings,
//  and each city's weather as last fetched.
//

import Foundation
import WeatherKit
import WidgetKit

enum WatchWidgetStore {
    /// The widget reads the settings through its AppStorage, under the keys
    /// the app keeps them in.
    static let defaults = UserDefaults(suiteName: "group.com.time.touchtime") ?? .standard

    private static let citiesKey = "cities"
    private static let dateStyleKey = "dateStyle"
    private static let countdownsKey = "countdowns"
    private static let countdownUnitKey = "countdownUnit"
    private static let weatherConditionsKey = "weatherConditions"
    private static let settingsKeys = [WatchTimeFormat.use24HourFormatKey, AdditionalTime.storageKey]
    /// Weather fetched longer ago than this no longer shows, as stale rain is
    /// worse than none.
    private static let weatherConditionMaxAge: TimeInterval = 60 * 60

    private struct StoredWeatherCondition: Codable {
        let rawValue: String
        let fetchDate: Date
    }

    // MARK: - Widget side

    /// The clocks the app lists, in its order: the watch's own, then the
    /// iPhone's cities, once the app has copied them.
    static var cities: [ClockCity] {
        [.local] + (savedCities ?? []).map { ClockCity($0) }
    }

    /// The iPhone app's date style, for `Date.formattedDate(style:)`.
    static var dateStyle: String {
        defaults.string(forKey: dateStyleKey) ?? "Relative"
    }

    /// The iPhone's countdowns, in the order the app lists them, once the
    /// app has copied them.
    static var countdowns: [WatchCountdown] {
        savedCountdowns ?? []
    }

    /// The unit the countdowns count in: days, as in the app, until it has
    /// copied the iPhone's.
    static var countdownUnit: CountdownUnit {
        defaults.string(forKey: countdownUnitKey).flatMap(CountdownUnit.init(rawValue:)) ?? .days
    }

    /// The weather the app last fetched for `timeZoneIdentifier`, unless that
    /// was too long ago.
    static func weatherCondition(for timeZoneIdentifier: String) -> WeatherCondition? {
        guard let stored = savedWeatherConditions()[timeZoneIdentifier],
              Date.now.timeIntervalSince(stored.fetchDate) < weatherConditionMaxAge else {
            return nil
        }
        return WeatherCondition(rawValue: stored.rawValue)
    }

    // MARK: - App side

    /// Copies the cities and date style the iPhone sent, and has the widget
    /// show them.
    static func save(cities: [WatchCity], dateStyle: String) {
        guard cities != savedCities || dateStyle != defaults.string(forKey: dateStyleKey) else { return }
        defaults.set(try? JSONEncoder().encode(cities), forKey: citiesKey)
        defaults.set(dateStyle, forKey: dateStyleKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Copies the countdowns the iPhone sent and the unit they count in, and
    /// has the widget show them.
    static func save(countdowns: [WatchCountdown], unit: CountdownUnit) {
        guard countdowns != savedCountdowns || unit.rawValue != defaults.string(forKey: countdownUnitKey) else { return }
        defaults.set(try? JSONEncoder().encode(countdowns), forKey: countdownsKey)
        defaults.set(unit.rawValue, forKey: countdownUnitKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Copies the 24-Hour Format and Additional Time settings, or their
    /// absence, so the widget falls back to the same defaults as the app, and
    /// has the widget show them.
    static func saveSettings() {
        var changed = false
        for key in settingsKeys {
            let value = UserDefaults.standard.object(forKey: key)
            if value as? NSObject != defaults.object(forKey: key) as? NSObject {
                defaults.set(value, forKey: key)
                changed = true
            }
        }
        if changed {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Copies the weather just fetched for `timeZoneIdentifier`, and has the
    /// widget's sky turn gray, or clear, as rain starts or stops there.
    static func save(_ condition: WeatherCondition, for timeZoneIdentifier: String) {
        let wasRaining = weatherCondition(for: timeZoneIdentifier)?.isRainy ?? false
        var conditions = savedWeatherConditions().filter {
            Date.now.timeIntervalSince($0.value.fetchDate) < weatherConditionMaxAge
        }
        conditions[timeZoneIdentifier] = StoredWeatherCondition(rawValue: condition.rawValue, fetchDate: .now)
        defaults.set(try? JSONEncoder().encode(conditions), forKey: weatherConditionsKey)
        if condition.isRainy != wasRaining {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Stored values

    private static var savedCities: [WatchCity]? {
        defaults.data(forKey: citiesKey).flatMap { try? JSONDecoder().decode([WatchCity].self, from: $0) }
    }

    private static var savedCountdowns: [WatchCountdown]? {
        defaults.data(forKey: countdownsKey).flatMap { try? JSONDecoder().decode([WatchCountdown].self, from: $0) }
    }

    private static func savedWeatherConditions() -> [String: StoredWeatherCondition] {
        defaults.data(forKey: weatherConditionsKey)
            .flatMap { try? JSONDecoder().decode([String: StoredWeatherCondition].self, from: $0) } ?? [:]
    }
}
