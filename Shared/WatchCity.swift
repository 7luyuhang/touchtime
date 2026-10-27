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
}
