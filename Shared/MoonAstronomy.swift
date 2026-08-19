//
//  MoonAstronomy.swift
//  touchtime
//
//  Lightweight moon math shared by the app (moon details sheet, phase
//  calendar cache) and the widget extension (Moon Calendar widget).
//  Lives in Shared/ so both targets compile it.
//

import Foundation

/// Instantaneous moon values for a given moment.
struct MoonSnapshot {
    /// Age of the moon in degrees within the synodic cycle [0, 360).
    let ageDegrees: Double
    /// Age of the moon in days (0 = new moon, ~14.77 = full moon).
    let ageDays: Double
    /// Illuminated fraction of the disc [0, 1].
    let illuminatedFraction: Double
    /// Earth-Moon distance in kilometers.
    let distanceKilometers: Double
}

/// Practical Astronomy (Duffett-Smith) moon computation using the same
/// constants and steps as MoonKit's coordinate math, but without the
/// expensive moonrise/moonset search. Cheap enough to evaluate on every
/// frame while scrubbing through time.
enum MoonAstronomy {
    static func snapshot(for date: Date) -> MoonSnapshot {
        // Days since the J2000 epoch, in Terrestrial Time
        // (MoonKit applies the same fixed 63.8 s ΔT correction).
        let julianDay = date.timeIntervalSince1970 / 86400.0 + 2440587.5 + 63.8 / 86400.0
        let d = julianDay - 2451545.0

        func mod360(_ value: Double) -> Double {
            let m = value.truncatingRemainder(dividingBy: 360)
            return m < 0 ? m + 360 : m
        }
        func rad(_ degrees: Double) -> Double { degrees * .pi / 180 }

        // Sun: mean anomaly and true ecliptic longitude
        let sunMeanAnomaly = mod360(360.0 / 365.242191 * d + 280.466069 - 282.938346)
        let sunEquationOfCentre = 360.0 / Double.pi * 0.016708 * sin(rad(sunMeanAnomaly))
        let sunLongitude = mod360(sunMeanAnomaly + sunEquationOfCentre + 282.938346)

        // Moon: mean elements
        let meanLongitude = mod360(13.176339686 * d + 218.316433)
        let meanAnomaly = mod360(meanLongitude - 0.1114041 * d - 83.353451)

        // Corrections: annual equation, evection, equation of the centre, variation
        let annualEquation = 0.1858 * sin(rad(sunMeanAnomaly))
        let evection = 1.2739 * sin(rad(2 * (meanLongitude - sunLongitude) - meanAnomaly))
        let correctedAnomaly = meanAnomaly + evection - annualEquation - 0.37 * sin(rad(sunMeanAnomaly))
        let equationOfCentre = 6.2886 * sin(rad(correctedAnomaly)) + 0.214 * sin(rad(2 * correctedAnomaly))
        let correctedLongitude = meanLongitude + evection + equationOfCentre - annualEquation
        let variation = 0.6583 * sin(rad(2 * (correctedLongitude - sunLongitude)))
        let trueLongitude = correctedLongitude + variation

        // Age of the moon: elongation of the true longitudes
        let ageDegrees = mod360(trueLongitude - sunLongitude)
        let ageDays = ageDegrees / 12.1907
        let illuminatedFraction = (1 - cos(rad(ageDegrees))) / 2

        // Distance from the orbit ellipse evaluated at the corrected anomaly
        let eccentricity = 0.0549
        let semiMajorAxisKm = 384401.0
        let distanceKilometers = semiMajorAxisKm * (1 - eccentricity * eccentricity)
            / (1 + eccentricity * cos(rad(correctedAnomaly + equationOfCentre)))

        return MoonSnapshot(
            ageDegrees: ageDegrees,
            ageDays: ageDays,
            illuminatedFraction: illuminatedFraction,
            distanceKilometers: distanceKilometers
        )
    }
}
