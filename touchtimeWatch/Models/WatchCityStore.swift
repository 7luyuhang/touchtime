//
//  WatchCityStore.swift
//  touchtimeWatch
//
//  The iPhone app's saved cities, date style, first day of the week and
//  temperature unit, received over WatchConnectivity.
//

import Foundation
import Observation
import WatchConnectivity

/// The cities the watch shows: the iPhone app's saved list, kept in the
/// watch's own defaults so it's there right away on the next launch, even
/// with the iPhone out of reach.
@Observable
final class WatchCityStore: NSObject, WCSessionDelegate {
    private(set) var cities: [WatchCity]
    /// The iPhone app's date style, for `Date.formattedDate(style:)`.
    private(set) var dateStyle: String
    /// The iPhone app's first day of the week, for the moon calendar's weeks:
    /// 1 = Sunday, 2 = Monday, ...
    private(set) var firstWeekday: Int
    /// The iPhone app's temperature unit: Celsius, or Fahrenheit when false.
    private(set) var useCelsius: Bool

    private static let citiesKey = "cities"
    private static let dateStyleKey = "dateStyle"
    private static let firstWeekdayKey = "firstWeekday"
    private static let useCelsiusKey = "useCelsius"

    override init() {
        let defaults = UserDefaults.standard
        let savedCities = defaults.data(forKey: Self.citiesKey)
            .flatMap { try? JSONDecoder().decode([WatchCity].self, from: $0) }
        // Until the iPhone first syncs, the cities the iPhone app starts with
        cities = savedCities ?? WorldClockData.defaultClocks.map { WatchCity($0) }
        dateStyle = defaults.string(forKey: Self.dateStyleKey) ?? "Relative"
        // Monday, as on the iPhone until its Calendar settings pick another day
        let savedFirstWeekday = defaults.integer(forKey: Self.firstWeekdayKey)
        firstWeekday = (1...7).contains(savedFirstWeekday) ? savedFirstWeekday : 2
        // Celsius, as on the iPhone until its settings pick Fahrenheit
        useCelsius = defaults.object(forKey: Self.useCelsiusKey) as? Bool ?? true
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

    private func apply(citiesData: Data?, dateStyle: String?, firstWeekday: Int?, useCelsius: Bool?) {
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
        if let firstWeekday, (1...7).contains(firstWeekday) {
            if firstWeekday != self.firstWeekday {
                self.firstWeekday = firstWeekday
            }
            defaults.set(firstWeekday, forKey: Self.firstWeekdayKey)
        }
        if let useCelsius {
            if useCelsius != self.useCelsius {
                self.useCelsius = useCelsius
            }
            defaults.set(useCelsius, forKey: Self.useCelsiusKey)
        }
    }

    nonisolated private func receive(_ context: [String: Any]) {
        let citiesData = context[WatchSyncKeys.cities] as? Data
        let dateStyle = context[WatchSyncKeys.dateStyle] as? String
        let firstWeekday = context[WatchSyncKeys.firstWeekday] as? Int
        let useCelsius = context[WatchSyncKeys.useCelsius] as? Bool
        Task { @MainActor in
            self.apply(citiesData: citiesData, dateStyle: dateStyle, firstWeekday: firstWeekday, useCelsius: useCelsius)
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
