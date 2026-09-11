//
//  MoonPhase.swift
//  touchtime
//
//  The eight moon phases. Days are classified by MoonDay (MoonAstronomy.swift)
//  so every phase label in the app follows the same day-level rule.
//  Lives in Shared/ so both the app and the widget extension compile it.
//

import Foundation

enum MoonPhase {
    case newMoon
    case waxingCrescent
    case firstQuarter
    case waxingGibbous
    case fullMoon
    case waningGibbous
    case lastQuarter
    case waningCrescent

    /// SF Symbol of the phase.
    var symbolName: String {
        switch self {
        case .newMoon:
            return "moonphase.new.moon"
        case .waxingCrescent:
            return "moonphase.waxing.crescent"
        case .firstQuarter:
            return "moonphase.first.quarter"
        case .waxingGibbous:
            return "moonphase.waxing.gibbous"
        case .fullMoon:
            return "moonphase.full.moon"
        case .waningGibbous:
            return "moonphase.waning.gibbous"
        case .lastQuarter:
            return "moonphase.last.quarter"
        case .waningCrescent:
            return "moonphase.waning.crescent"
        }
    }

    /// User-facing name of the phase.
    var localizedName: String {
        switch self {
        case .newMoon:
            return String(localized: "New Moon")
        case .waxingCrescent:
            return String(localized: "Waxing Crescent")
        case .firstQuarter:
            return String(localized: "First Quarter")
        case .waxingGibbous:
            return String(localized: "Waxing Gibbous")
        case .fullMoon:
            return String(localized: "Full Moon")
        case .waningGibbous:
            return String(localized: "Waning Gibbous")
        case .lastQuarter:
            return String(localized: "Last Quarter")
        case .waningCrescent:
            return String(localized: "Waning Crescent")
        }
    }
}
