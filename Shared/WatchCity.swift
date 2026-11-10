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

nonisolated enum WatchSyncKeys {
    /// JSON-encoded `[WatchCity]`, in the iPhone's order.
    static let cities = "cities"
    /// The iPhone's date style: "Relative", "With Weekday" or "Date Only".
    static let dateStyle = "dateStyle"
    /// The iPhone's first day of the week, chosen in its Calendar settings:
    /// 1 = Sunday, 2 = Monday, ...
    static let firstWeekday = "firstWeekday"
    /// The iPhone app's temperature unit: true for Celsius, false for
    /// Fahrenheit.
    static let useCelsius = "useCelsius"
    /// The iPhone app's wind speed unit: a `WindSpeedUnit`'s raw value.
    static let windSpeedUnit = "windSpeedUnit"
    /// The iPhone app's pressure unit: a `PressureUnit`'s raw value.
    static let pressureUnit = "pressureUnit"
}
