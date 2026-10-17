//
//  PressureUnit.swift
//  touchtime
//
//  Created on 17/10/2026.
//

import Foundation

/// The unit air pressure is shown in, picked in Settings → Units
/// alongside the temperature and wind speed units.
enum PressureUnit: String, CaseIterable, Identifiable {
    case millibars
    case hectopascals
    case kilopascals
    case millimetersOfMercury
    case inchesOfMercury

    static let storageKey = "pressureUnit"

    var id: String { rawValue }

    var unit: UnitPressure {
        switch self {
        case .millibars:
            return .millibars
        case .hectopascals:
            return .hectopascals
        case .kilopascals:
            return .kilopascals
        case .millimetersOfMercury:
            return .millimetersOfMercury
        case .inchesOfMercury:
            return .inchesOfMercury
        }
    }

    /// Decimal places a reading is shown with, e.g. "1,033 mbar",
    /// "103.3 kPa" or "30.51 inHg".
    var fractionDigits: Int {
        switch self {
        case .millibars, .hectopascals, .millimetersOfMercury:
            return 0
        case .kilopascals:
            return 1
        case .inchesOfMercury:
            return 2
        }
    }

    /// The unit as written after a formatted pressure, e.g. "mbar" or "inHg".
    var localizedSymbol: String {
        let formatted = Measurement(value: 0, unit: unit)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided).attributed)
        return formatted.runs
            .filter { $0.measurement == .unit }
            .map { String(formatted[$0.range].characters) }
            .joined()
    }
}
