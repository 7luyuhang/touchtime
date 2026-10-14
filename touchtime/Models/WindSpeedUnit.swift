//
//  WindSpeedUnit.swift
//  touchtime
//
//  Created on 13/10/2026.
//

import Foundation

/// The unit wind speeds are shown in, picked in Settings → Units
/// alongside the temperature unit.
enum WindSpeedUnit: String, CaseIterable, Identifiable {
    case kilometersPerHour
    case milesPerHour
    case metersPerSecond
    case knots

    static let storageKey = "windSpeedUnit"

    var id: String { rawValue }

    var unit: UnitSpeed {
        switch self {
        case .kilometersPerHour:
            return .kilometersPerHour
        case .milesPerHour:
            return .milesPerHour
        case .metersPerSecond:
            return .metersPerSecond
        case .knots:
            return .knots
        }
    }

    /// The unit as written after a formatted speed, e.g. "km/h" or "mph".
    var localizedSymbol: String {
        let formatted = Measurement(value: 0, unit: unit)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided).attributed)
        return formatted.runs
            .filter { $0.measurement == .unit }
            .map { String(formatted[$0.range].characters) }
            .joined()
    }

    /// Wind speeds used to follow the temperature unit (mph with Fahrenheit).
    /// Stores that unit once, so changing the temperature unit no longer
    /// changes it.
    static func migrateFromTemperatureUnit() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: storageKey) == nil else { return }

        let useCelsius = defaults.object(forKey: "useCelsius") as? Bool ?? true
        let unit: WindSpeedUnit = useCelsius ? .kilometersPerHour : .milesPerHour
        defaults.set(unit.rawValue, forKey: storageKey)
    }
}
