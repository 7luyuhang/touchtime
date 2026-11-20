//
//  WatchCityStore.swift
//  touchtimeWatch
//
//  The iPhone app's saved cities and collections, date style, first day of
//  the week, temperature, wind speed and pressure units, countdowns and the
//  unit they count in, and recent timers, received over WatchConnectivity.
//

import Foundation
import Observation
import WatchConnectivity

/// The cities, countdowns and recent timers the watch shows: the iPhone
/// app's saved lists, kept in the watch's own defaults so they're there
/// right away on the next launch, even with the iPhone out of reach.
@Observable
final class WatchCityStore: NSObject, WCSessionDelegate {
    private(set) var cities: [WatchCity]
    /// The iPhone app's collections, in the order its menu lists them.
    private(set) var collections: [WatchCollection]
    /// The iPhone app's date style, for `Date.formattedDate(style:)`.
    private(set) var dateStyle: String
    /// The iPhone app's first day of the week, for the moon calendar's weeks:
    /// 1 = Sunday, 2 = Monday, ...
    private(set) var firstWeekday: Int
    /// The iPhone app's temperature unit: Celsius, or Fahrenheit when false.
    private(set) var useCelsius: Bool
    /// The iPhone app's wind speed unit.
    private(set) var windSpeedUnit: WindSpeedUnit
    /// The iPhone app's pressure unit.
    private(set) var pressureUnit: PressureUnit
    /// The iPhone app's countdowns, in the order its countdown sheet lists
    /// them.
    private(set) var countdowns: [WatchCountdown]
    /// The unit the countdowns count in: the largest one switched on in the
    /// iPhone app's countdown sheet's Time Display.
    private(set) var countdownUnit: CountdownUnit
    /// The timers started on the iPhone, in the order its timer sheet lists
    /// them under Recents.
    private(set) var recentTimers: [WatchRecentTimer]

    private static let citiesKey = "cities"
    private static let collectionsKey = "collections"
    private static let dateStyleKey = "dateStyle"
    private static let firstWeekdayKey = "firstWeekday"
    private static let useCelsiusKey = "useCelsius"
    private static let windSpeedUnitKey = "windSpeedUnit"
    private static let pressureUnitKey = "pressureUnit"
    private static let countdownsKey = "countdowns"
    private static let countdownUnitKey = "countdownUnit"
    private static let recentTimersKey = "recentTimers"

    override init() {
        let defaults = UserDefaults.standard
        let savedCities = defaults.data(forKey: Self.citiesKey)
            .flatMap { try? JSONDecoder().decode([WatchCity].self, from: $0) }
        // Until the iPhone first syncs, the cities the iPhone app starts with
        cities = savedCities ?? WorldClockData.defaultClocks.map { WatchCity($0) }
        // None until the iPhone first syncs
        collections = defaults.data(forKey: Self.collectionsKey)
            .flatMap { try? JSONDecoder().decode([WatchCollection].self, from: $0) } ?? []
        dateStyle = defaults.string(forKey: Self.dateStyleKey) ?? "Relative"
        // Monday, as on the iPhone until its Calendar settings pick another day
        let savedFirstWeekday = defaults.integer(forKey: Self.firstWeekdayKey)
        firstWeekday = (1...7).contains(savedFirstWeekday) ? savedFirstWeekday : 2
        // Celsius, as on the iPhone until its settings pick Fahrenheit
        let savedUseCelsius = defaults.object(forKey: Self.useCelsiusKey) as? Bool ?? true
        useCelsius = savedUseCelsius
        // As the iPhone first picks it, until it sends its own: mph with
        // Fahrenheit, and km/h otherwise
        windSpeedUnit = defaults.string(forKey: Self.windSpeedUnitKey).flatMap(WindSpeedUnit.init(rawValue:))
            ?? (savedUseCelsius ? .kilometersPerHour : .milesPerHour)
        // Millibars, as on the iPhone until its settings pick another unit
        pressureUnit = defaults.string(forKey: Self.pressureUnitKey).flatMap(PressureUnit.init(rawValue:))
            ?? .millibars
        // None until the iPhone first syncs
        countdowns = defaults.data(forKey: Self.countdownsKey)
            .flatMap { try? JSONDecoder().decode([WatchCountdown].self, from: $0) } ?? []
        // Days, as on the iPhone until its Time Display picks a larger unit
        countdownUnit = defaults.string(forKey: Self.countdownUnitKey).flatMap(CountdownUnit.init(rawValue:))
            ?? .days
        // None until the iPhone first syncs
        recentTimers = defaults.data(forKey: Self.recentTimersKey)
            .flatMap { try? JSONDecoder().decode([WatchRecentTimer].self, from: $0) } ?? []
        super.init()

        if savedCities == nil {
            // Saved, so the selected city is still there after a relaunch
            defaults.set(try? JSONEncoder().encode(cities), forKey: Self.citiesKey)
        }
        WatchWidgetStore.save(cities: cities, dateStyle: dateStyle)

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    private func apply(
        citiesData: Data?,
        collectionsData: Data?,
        dateStyle: String?,
        firstWeekday: Int?,
        useCelsius: Bool?,
        windSpeedUnit: String?,
        pressureUnit: String?,
        countdownsData: Data?,
        countdownUnit: String?,
        recentTimersData: Data?
    ) {
        let defaults = UserDefaults.standard
        if let citiesData,
           let receivedCities = try? JSONDecoder().decode([WatchCity].self, from: citiesData) {
            if receivedCities != cities {
                cities = receivedCities
            }
            defaults.set(citiesData, forKey: Self.citiesKey)
        }
        if let collectionsData,
           let receivedCollections = try? JSONDecoder().decode([WatchCollection].self, from: collectionsData) {
            if receivedCollections != collections {
                collections = receivedCollections
            }
            defaults.set(collectionsData, forKey: Self.collectionsKey)
        }
        if let dateStyle {
            if dateStyle != self.dateStyle {
                self.dateStyle = dateStyle
            }
            defaults.set(dateStyle, forKey: Self.dateStyleKey)
        }
        WatchWidgetStore.save(cities: cities, dateStyle: self.dateStyle)
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
        if let windSpeedUnit = windSpeedUnit.flatMap(WindSpeedUnit.init(rawValue:)) {
            if windSpeedUnit != self.windSpeedUnit {
                self.windSpeedUnit = windSpeedUnit
            }
            defaults.set(windSpeedUnit.rawValue, forKey: Self.windSpeedUnitKey)
        }
        if let pressureUnit = pressureUnit.flatMap(PressureUnit.init(rawValue:)) {
            if pressureUnit != self.pressureUnit {
                self.pressureUnit = pressureUnit
            }
            defaults.set(pressureUnit.rawValue, forKey: Self.pressureUnitKey)
        }
        if let countdownsData,
           let receivedCountdowns = try? JSONDecoder().decode([WatchCountdown].self, from: countdownsData) {
            if receivedCountdowns != countdowns {
                countdowns = receivedCountdowns
            }
            defaults.set(countdownsData, forKey: Self.countdownsKey)
        }
        if let countdownUnit = countdownUnit.flatMap(CountdownUnit.init(rawValue:)) {
            if countdownUnit != self.countdownUnit {
                self.countdownUnit = countdownUnit
            }
            defaults.set(countdownUnit.rawValue, forKey: Self.countdownUnitKey)
        }
        if let recentTimersData,
           let receivedRecentTimers = try? JSONDecoder().decode([WatchRecentTimer].self, from: recentTimersData) {
            if receivedRecentTimers != recentTimers {
                recentTimers = receivedRecentTimers
            }
            defaults.set(recentTimersData, forKey: Self.recentTimersKey)
        }
    }

    nonisolated private func receive(_ context: [String: Any]) {
        let citiesData = context[WatchSyncKeys.cities] as? Data
        let collectionsData = context[WatchSyncKeys.collections] as? Data
        let dateStyle = context[WatchSyncKeys.dateStyle] as? String
        let firstWeekday = context[WatchSyncKeys.firstWeekday] as? Int
        let useCelsius = context[WatchSyncKeys.useCelsius] as? Bool
        let windSpeedUnit = context[WatchSyncKeys.windSpeedUnit] as? String
        let pressureUnit = context[WatchSyncKeys.pressureUnit] as? String
        let countdownsData = context[WatchSyncKeys.countdowns] as? Data
        let countdownUnit = context[WatchSyncKeys.countdownUnit] as? String
        let recentTimersData = context[WatchSyncKeys.recentTimers] as? Data
        Task { @MainActor in
            self.apply(
                citiesData: citiesData,
                collectionsData: collectionsData,
                dateStyle: dateStyle,
                firstWeekday: firstWeekday,
                useCelsius: useCelsius,
                windSpeedUnit: windSpeedUnit,
                pressureUnit: pressureUnit,
                countdownsData: countdownsData,
                countdownUnit: countdownUnit,
                recentTimersData: recentTimersData
            )
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
