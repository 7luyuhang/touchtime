//
//  SharedWidgetStore.swift
//  touchtime
//
//  Shares saved world clocks between the main app and the widget extension
//  through an App Group container.
//

import Foundation
import WeatherKit

enum SharedWidgetStore {
    static let appGroupIdentifier = "group.com.time.touchtime"
    static let worldClocksKey = "savedWorldClocks"
    static let use24HourKey = "use24HourFormat"
    static let showWeatherKey = "showWeather"
    static let weatherConditionsKey = "widgetWeatherConditions"
    static let worldCitiesSelectedCityKey = "worldCitiesSelectedCityId"

    // Conditions older than this are ignored by the widget: the app may not
    // have been opened for a long time, and stale "rain" is worse than none.
    static let weatherConditionMaxAge: TimeInterval = 3 * 60 * 60

    struct StoredWeatherCondition: Codable {
        let conditionRawValue: String
        let fetchedAt: Date
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    // Widget side: read the user's saved cities.
    // When the app has no saved cities, fall back to London only.
    static func loadWorldClocks() -> [WorldClock] {
        if let data = sharedDefaults?.data(forKey: worldClocksKey),
           let clocks = try? JSONDecoder().decode([WorldClock].self, from: data),
           !clocks.isEmpty {
            return clocks
        }
        return [WorldClock(cityName: "London", timeZoneIdentifier: "Europe/London")]
    }

    static func use24HourFormat() -> Bool {
        sharedDefaults?.bool(forKey: use24HourKey) ?? false
    }

    // Widget side: which city drives the medium widget's sky background.
    static func worldCitiesSelectedCityId() -> String? {
        sharedDefaults?.string(forKey: worldCitiesSelectedCityKey)
    }

    static func setWorldCitiesSelectedCityId(_ id: String) {
        sharedDefaults?.set(id, forKey: worldCitiesSelectedCityKey)
    }

    // Widget side: whether the user has weather enabled in the app. Widgets
    // only paint weather skies (and fetch conditions) when this is on, so
    // they always match what the app itself would show.
    static func showWeather() -> Bool {
        guard let shared = sharedDefaults else { return false }
        if shared.object(forKey: showWeatherKey) == nil {
            // Key not synced yet (app not opened since it was added): infer
            // from whether the app ever cached conditions, which only
            // happens with weather enabled.
            return shared.data(forKey: weatherConditionsKey) != nil
        }
        return shared.bool(forKey: showWeatherKey)
    }

    // Widget side: latest known weather condition for a city, or nil when
    // weather is disabled in the app or nothing fresh enough is stored.
    static func weatherCondition(for timeZoneIdentifier: String) -> WeatherCondition? {
        weatherCondition(for: timeZoneIdentifier, maxAge: weatherConditionMaxAge)
    }

    static func weatherCondition(for timeZoneIdentifier: String, maxAge: TimeInterval) -> WeatherCondition? {
        guard showWeather(),
              let stored = loadStoredWeatherConditions()[timeZoneIdentifier],
              Date().timeIntervalSince(stored.fetchedAt) < maxAge else {
            return nil
        }
        return WeatherCondition(rawValue: stored.conditionRawValue)
    }

    // App side: merge freshly fetched conditions into the shared container so
    // cities fetched at different times don't overwrite each other.
    static func saveWeatherConditions(_ conditions: [String: StoredWeatherCondition]) {
        guard let shared = sharedDefaults else { return }
        var merged = loadStoredWeatherConditions()
        for (identifier, condition) in conditions {
            merged[identifier] = condition
        }
        merged = merged.filter {
            Date().timeIntervalSince($0.value.fetchedAt) < weatherConditionMaxAge
        }
        if let data = try? JSONEncoder().encode(merged) {
            shared.set(data, forKey: weatherConditionsKey)
        }
    }

    private static func loadStoredWeatherConditions() -> [String: StoredWeatherCondition] {
        guard let data = sharedDefaults?.data(forKey: weatherConditionsKey),
              let conditions = try? JSONDecoder().decode([String: StoredWeatherCondition].self, from: data) else {
            return [:]
        }
        return conditions
    }

    // App side: mirror standard defaults into the shared container
    static func syncFromApp() {
        guard let shared = sharedDefaults else { return }
        let standard = UserDefaults.standard
        if let data = standard.data(forKey: worldClocksKey) {
            shared.set(data, forKey: worldClocksKey)
        }
        shared.set(standard.bool(forKey: use24HourKey), forKey: use24HourKey)
        shared.set(standard.bool(forKey: showWeatherKey), forKey: showWeatherKey)
    }
}
