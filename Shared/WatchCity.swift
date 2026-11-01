//
//  WatchCity.swift
//  touchtime
//
//  The saved cities the iPhone app sends to the Apple Watch app over
//  WatchConnectivity, and the application context keys they travel under.
//

import Foundation

/// A saved city as the watch shows it. The name is resolved on the iPhone,
/// custom names and localization included, so the watch doesn't need the
/// app's string catalog to show it.
struct WatchCity: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let timeZoneIdentifier: String
}

extension WatchCity {
    init(_ clock: WorldClock) {
        self.init(id: clock.id, name: clock.localizedCityName, timeZoneIdentifier: clock.timeZoneIdentifier)
    }
}

/// A city's latest condition, kept with its fetch time so the watch can discard
/// stale weather while the iPhone is out of reach.
struct WatchWeatherCondition: Codable {
    let conditionRawValue: String
    let fetchedAt: Date

    static let maxAge: TimeInterval = 3 * 60 * 60
}

nonisolated enum WatchSyncKeys {
    /// JSON-encoded `[WatchCity]`, in the iPhone's order.
    static let cities = "cities"
    /// The iPhone's date style: "Relative", "With Weekday" or "Date Only".
    static let dateStyle = "dateStyle"
    /// Whether Weather is enabled on the iPhone.
    static let showWeather = "showWeather"
    /// JSON-encoded `[String: WatchWeatherCondition]`, keyed by time zone.
    static let weatherConditions = "weatherConditions"
}
