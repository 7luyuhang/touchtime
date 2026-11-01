//
//  WatchCityStore.swift
//  touchtimeWatch
//
//  The iPhone app's saved cities, date style and weather, received over
//  WatchConnectivity.
//

import Foundation
import Observation
import WatchConnectivity
import WeatherKit

/// The cities the watch shows: the iPhone app's saved list, kept in the
/// watch's own defaults so it's there right away on the next launch, even
/// with the iPhone out of reach.
@Observable
final class WatchCityStore: NSObject, WCSessionDelegate {
    private(set) var cities: [WatchCity]
    /// The iPhone app's date style, for `Date.formattedDate(style:)`.
    private(set) var dateStyle: String
    private(set) var showWeather: Bool
    private var weatherConditions: [String: WatchWeatherCondition]

    private static let citiesKey = "cities"
    private static let dateStyleKey = "dateStyle"
    private static let showWeatherKey = "showWeather"
    private static let weatherConditionsKey = "weatherConditions"

    override init() {
        let defaults = UserDefaults.standard
        let savedCities = defaults.data(forKey: Self.citiesKey)
            .flatMap { try? JSONDecoder().decode([WatchCity].self, from: $0) }
        // Until the iPhone first syncs, the cities the iPhone app starts with
        cities = savedCities ?? WorldClockData.defaultClocks.map { WatchCity($0) }
        dateStyle = defaults.string(forKey: Self.dateStyleKey) ?? "Relative"
        showWeather = defaults.bool(forKey: Self.showWeatherKey)
        weatherConditions = defaults.data(forKey: Self.weatherConditionsKey)
            .flatMap { try? JSONDecoder().decode([String: WatchWeatherCondition].self, from: $0) } ?? [:]
        super.init()

        if savedCities == nil {
            // Saved, so the selected city is still there after a relaunch
            defaults.set(try? JSONEncoder().encode(cities), forKey: Self.citiesKey)
        }

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    /// Missing or expired weather falls back to the solar sky, like the widgets.
    func weatherCondition(for identifier: String, now: Date = .now) -> WeatherCondition? {
        guard showWeather,
              let stored = weatherConditions[identifier],
              now.timeIntervalSince(stored.fetchedAt) < WatchWeatherCondition.maxAge else { return nil }
        return WeatherCondition(rawValue: stored.conditionRawValue)
    }

    private func apply(citiesData: Data?, dateStyle: String?, showWeather: Bool?, weatherData: Data?) {
        let defaults = UserDefaults.standard
        if let citiesData,
           let receivedCities = try? JSONDecoder().decode([WatchCity].self, from: citiesData) {
            if receivedCities != cities {
                cities = receivedCities
            }
            defaults.set(citiesData, forKey: Self.citiesKey)
        }
        if let dateStyle {
            if dateStyle != self.dateStyle {
                self.dateStyle = dateStyle
            }
            defaults.set(dateStyle, forKey: Self.dateStyleKey)
        }
        if let showWeather {
            self.showWeather = showWeather
            defaults.set(showWeather, forKey: Self.showWeatherKey)
        }
        if let weatherData,
           let receivedConditions = try? JSONDecoder().decode([String: WatchWeatherCondition].self, from: weatherData) {
            weatherConditions = receivedConditions
            defaults.set(weatherData, forKey: Self.weatherConditionsKey)
        }
    }

    nonisolated private func receive(_ context: [String: Any]) {
        let citiesData = context[WatchSyncKeys.cities] as? Data
        let dateStyle = context[WatchSyncKeys.dateStyle] as? String
        let showWeather = context[WatchSyncKeys.showWeather] as? Bool
        let weatherData = context[WatchSyncKeys.weatherConditions] as? Data
        Task { @MainActor in
            self.apply(citiesData: citiesData, dateStyle: dateStyle, showWeather: showWeather, weatherData: weatherData)
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // The latest list the iPhone sent while this app wasn't running
        receive(session.receivedApplicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(applicationContext)
    }
}
