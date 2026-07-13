//
//  SharedWidgetStore.swift
//  touchtime
//
//  Shares saved world clocks between the main app and the widget extension
//  through an App Group container.
//

import Foundation

enum SharedWidgetStore {
    static let appGroupIdentifier = "group.com.time.touchtime"
    static let worldClocksKey = "savedWorldClocks"
    static let use24HourKey = "use24HourFormat"

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

    // App side: mirror standard defaults into the shared container
    static func syncFromApp() {
        guard let shared = sharedDefaults else { return }
        let standard = UserDefaults.standard
        if let data = standard.data(forKey: worldClocksKey) {
            shared.set(data, forKey: worldClocksKey)
        }
        shared.set(standard.bool(forKey: use24HourKey), forKey: use24HourKey)
    }
}
