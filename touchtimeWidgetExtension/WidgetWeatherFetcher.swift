//
//  WidgetWeatherFetcher.swift
//  touchtimeWidgetExtension
//
//  Keeps the widgets' weather skies alive between app launches. The app only
//  mirrors conditions into the App Group while it runs, so after ~3 hours the
//  widgets would silently fall back to clear skies. Timeline reloads call
//  this instead: reuse a recent stored condition, otherwise fetch the current
//  one from WeatherKit and write it back for other widgets to share.
//

import Foundation
import WeatherKit
import CoreLocation

enum WidgetWeatherFetcher {
    // Conditions younger than this are reused instead of re-fetched,
    // matching the app's own 1-hour weather cache.
    static let refreshInterval: TimeInterval = 60 * 60

    // Best-available conditions for the given cities. Respects the app's
    // weather toggle: when weather is off, returns nothing so skies stay
    // purely solar-driven, exactly like the app.
    static func conditions(for timeZoneIdentifiers: [String]) async -> [String: WeatherCondition] {
        guard SharedWidgetStore.showWeather() else { return [:] }

        var conditions: [String: WeatherCondition] = [:]
        var fetched: [String: SharedWidgetStore.StoredWeatherCondition] = [:]

        for identifier in Set(timeZoneIdentifiers) {
            if let recent = SharedWidgetStore.weatherCondition(for: identifier, maxAge: refreshInterval) {
                conditions[identifier] = recent
                continue
            }
            guard let coords = TimeZoneCoordinates.getCoordinate(for: identifier) else { continue }
            let location = CLLocation(latitude: coords.latitude, longitude: coords.longitude)
            do {
                let current = try await WeatherService.shared.weather(for: location, including: .current)
                conditions[identifier] = current.condition
                fetched[identifier] = SharedWidgetStore.StoredWeatherCondition(
                    conditionRawValue: current.condition.rawValue,
                    fetchedAt: Date()
                )
            } catch {
                // Offline or throttled: fall back to the last stored condition
                // within the normal staleness window rather than none at all.
                if let stale = SharedWidgetStore.weatherCondition(for: identifier) {
                    conditions[identifier] = stale
                }
            }
        }

        if !fetched.isEmpty {
            SharedWidgetStore.saveWeatherConditions(fetched)
        }
        return conditions
    }
}
