//
//  WatchCityStore.swift
//  touchtimeWatch
//
//  The iPhone app's saved cities and collections, date style, first day of
//  the week, temperature, wind speed and pressure units, countdowns and the
//  unit they count in, and recent timers, received over WatchConnectivity,
//  and the timers started or removed here, sent back for its Recents.
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
    /// The timers started on the iPhone or here, in the order its timer
    /// sheet lists them under Recents, those started or removed here that
    /// it's yet to hear of put in or taken out as it will.
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
        WatchWidgetStore.save(countdowns: countdowns, unit: countdownUnit)

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
        WatchWidgetStore.save(countdowns: countdowns, unit: self.countdownUnit)
        if let recentTimersData,
           let receivedRecentTimers = try? JSONDecoder().decode([WatchRecentTimer].self, from: recentTimersData) {
            let timers = Self.unsentChanges().reduce(receivedRecentTimers) { timers, change in
                switch change {
                case .started(let timer): Self.inserting(timer, into: timers)
                case .removed(let timer): Self.removing(timer, from: timers)
                }
            }
            if timers != recentTimers {
                recentTimers = timers
            }
            defaults.set(try? JSONEncoder().encode(timers), forKey: Self.recentTimersKey)
        }
    }

    /// Puts a timer started here from the pickers in Recents, and sends it to
    /// the iPhone for its own, which come back with it.
    func rememberTimer(durationSeconds: Int) {
        guard durationSeconds > 0 else { return }
        let timer = WatchRecentTimer(id: UUID(), name: nil, durationSeconds: durationSeconds)
        let timers = Self.inserting(timer, into: recentTimers)
        if timers != recentTimers {
            recentTimers = timers
            UserDefaults.standard.set(try? JSONEncoder().encode(timers), forKey: Self.recentTimersKey)
        }

        // Kept until the iPhone's in reach, and its app running
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              let timerData = try? JSONEncoder().encode(timer) else { return }
        WCSession.default.transferUserInfo([WatchSyncKeys.startedTimer: timerData])
    }

    /// Takes a timer out of Recents, and sends it to the iPhone to take out
    /// of its own, which come back without it.
    func removeTimer(_ timer: WatchRecentTimer) {
        let timers = Self.removing(timer, from: recentTimers)
        if timers != recentTimers {
            recentTimers = timers
            UserDefaults.standard.set(try? JSONEncoder().encode(timers), forKey: Self.recentTimersKey)
        }

        // Kept until the iPhone's in reach, and its app running
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              let timerData = try? JSONEncoder().encode(timer) else { return }
        WCSession.default.transferUserInfo([WatchSyncKeys.removedTimer: timerData])
    }

    /// `timers` with `timer` first, unless one as long and named the same is
    /// there already, which stays where it is, as the iPhone keeps Recents.
    private static func inserting(_ timer: WatchRecentTimer, into timers: [WatchRecentTimer]) -> [WatchRecentTimer] {
        guard !timers.contains(where: { $0.durationSeconds == timer.durationSeconds && $0.name == timer.name }) else {
            return timers
        }
        return Array(([timer] + timers).prefix(WatchRecentTimer.maxCount))
    }

    /// `timers` without the one as long and named the same as `timer`, as
    /// the iPhone takes it out of Recents.
    private static func removing(_ timer: WatchRecentTimer, from timers: [WatchRecentTimer]) -> [WatchRecentTimer] {
        timers.filter { $0.durationSeconds != timer.durationSeconds || $0.name != timer.name }
    }

    /// A timer started or removed here, on its way to the iPhone.
    private enum UnsentChange {
        case started(WatchRecentTimer)
        case removed(WatchRecentTimer)
    }

    /// The timers started or removed here still on their way to the iPhone,
    /// in the order they were, so a timer removed and started again is back.
    private static func unsentChanges() -> [UnsentChange] {
        guard WCSession.isSupported() else { return [] }
        let decoder = JSONDecoder()
        return WCSession.default.outstandingUserInfoTransfers.compactMap { transfer in
            if let data = transfer.userInfo[WatchSyncKeys.startedTimer] as? Data,
               let timer = try? decoder.decode(WatchRecentTimer.self, from: data) {
                return .started(timer)
            }
            if let data = transfer.userInfo[WatchSyncKeys.removedTimer] as? Data,
               let timer = try? decoder.decode(WatchRecentTimer.self, from: data) {
                return .removed(timer)
            }
            return nil
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
