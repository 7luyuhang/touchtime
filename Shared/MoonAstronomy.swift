//
//  MoonAstronomy.swift
//  touchtime
//
//  Moon math shared by the app (moon details sheet, phase calendar cache,
//  moon complications) and the widget extension (Moon Phase and Moon
//  Calendar widgets). Lives in Shared/ so both targets compile it.
//
//  Practical Astronomy (Duffett-Smith) low-precision moon theory, the same
//  one MoonKit implemented. Everything here is plain arithmetic on the Unix
//  timestamp: no Calendar or DateComponents round-trips, so a full sky
//  position costs a few microseconds and moonrise/moonset can be bisected
//  instead of scanned minute by minute. Cheap enough to evaluate on every
//  frame while scrubbing through time.
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

/// Where the moon is in the sky for an observer.
struct MoonPosition {
    /// Degrees clockwise from true north, in 0..<360.
    let azimuth: Double
    /// Degrees above the horizon (negative when the moon is below it).
    let altitude: Double
}

/// Moonrise and moonset within one local day. The moon rises about 50
/// minutes later each day, so most months have a day without a moonrise
/// and one without a moonset; those are nil.
struct MoonDayEvents {
    let moonrise: Date?
    let moonset: Date?
}

/// The moon's phase for one whole local day, the granularity every phase
/// label in the app uses so the details sheet, complications, widgets and
/// the moon calendar always agree.
///
/// The four principal phases (new, first quarter, full, last quarter) are
/// instants; each labels exactly the day it falls in. Every other day is a
/// crescent or gibbous day, judged by the moon's age at local midday.
struct MoonDay {
    /// Age of the moon in days at the start of the day.
    let ageDaysAtStart: Double
    let isNewMoonDay: Bool
    let isFirstQuarterDay: Bool
    let isFullMoonDay: Bool
    let isLastQuarterDay: Bool
    let phase: MoonPhase

    /// Classifies a day from the moon's age at its start and at its end
    /// (the start of the following day).
    init(ageDaysAtStart: Double, ageDaysAtEnd: Double) {
        let quarterCycle = MoonAstronomy.synodicMonthDays / 4

        // The age wraps back to zero at new moon; the other principal phases
        // are the quarter-cycle marks the age crosses during the day
        isNewMoonDay = ageDaysAtEnd < ageDaysAtStart
        isFirstQuarterDay = ageDaysAtStart <= quarterCycle && ageDaysAtEnd > quarterCycle
        isFullMoonDay = ageDaysAtStart <= quarterCycle * 2 && ageDaysAtEnd > quarterCycle * 2
        isLastQuarterDay = ageDaysAtStart <= quarterCycle * 3 && ageDaysAtEnd > quarterCycle * 3
        self.ageDaysAtStart = ageDaysAtStart

        if isNewMoonDay {
            phase = .newMoon
        } else if isFullMoonDay {
            phase = .fullMoon
        } else if isFirstQuarterDay {
            phase = .firstQuarter
        } else if isLastQuarterDay {
            phase = .lastQuarter
        } else {
            // Between two principal phases. Midday is always at least half a
            // day from the nearest one, so the quarter marks split the days cleanly.
            let middayAgeDays = (ageDaysAtStart + ageDaysAtEnd) / 2
            if middayAgeDays < quarterCycle {
                phase = .waxingCrescent
            } else if middayAgeDays < quarterCycle * 2 {
                phase = .waxingGibbous
            } else if middayAgeDays < quarterCycle * 3 {
                phase = .waningGibbous
            } else {
                phase = .waningCrescent
            }
        }
    }

    /// The local day containing `date` in `calendar`'s time zone.
    init(containing date: Date, calendar: Calendar) {
        let dayStart = calendar.startOfDay(for: date)
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)
        self.init(
            ageDaysAtStart: MoonAstronomy.snapshot(for: dayStart).ageDays,
            ageDaysAtEnd: MoonAstronomy.snapshot(for: nextDayStart).ageDays
        )
    }
}

enum MoonAstronomy {

    /// Mean length of the synodic month (new moon to new moon) in days.
    static let synodicMonthDays = 29.53058867
    /// Conversion factor between the moon's age in degrees and in days.
    static let degreesPerAgeDay = 12.1907

    // MARK: - Public API

    /// Age, illumination and distance at an exact instant. Location-independent.
    static func snapshot(for date: Date) -> MoonSnapshot {
        let orbit = orbitalElements(for: date)

        // Age of the moon: elongation of the true longitudes
        let ageDegrees = mod360(orbit.trueLongitude - orbit.sunLongitude)
        let ageDays = ageDegrees / degreesPerAgeDay
        let illuminatedFraction = (1 - cos(rad(ageDegrees))) / 2

        // Distance from the orbit ellipse evaluated at the corrected anomaly
        let eccentricity = 0.0549
        let semiMajorAxisKm = 384401.0
        let distanceKilometers = semiMajorAxisKm * (1 - eccentricity * eccentricity)
            / (1 + eccentricity * cos(rad(orbit.correctedAnomaly + orbit.equationOfCentre)))

        return MoonSnapshot(
            ageDegrees: ageDegrees,
            ageDays: ageDays,
            illuminatedFraction: illuminatedFraction,
            distanceKilometers: distanceKilometers
        )
    }

    /// Moon azimuth/altitude at an exact instant for an observer. Timezone-independent.
    static func position(latitude: Double, longitude: Double, date: Date) -> MoonPosition {
        let orbit = orbitalElements(for: date)

        // Ecliptic coordinates: the true longitude is measured along the moon's
        // orbit, tilted by the inclination around the ascending node
        let inclination = rad(5.1453964)
        let nodeDistance = rad(orbit.trueLongitude - orbit.ascendingNode)
        let eclipticLongitude = rad(mod360(
            deg(atan2(sin(nodeDistance) * cos(inclination), cos(nodeDistance))) + orbit.ascendingNode
        ))
        let eclipticLatitude = asin(sin(nodeDistance) * sin(inclination))

        // Ecliptic to equatorial
        let obliquity = rad(23.439292)
        let declination = asin(
            sin(eclipticLatitude) * cos(obliquity)
                + cos(eclipticLatitude) * sin(obliquity) * sin(eclipticLongitude)
        )
        let rightAscension = atan2(
            sin(eclipticLongitude) * cos(obliquity) - tan(eclipticLatitude) * sin(obliquity),
            cos(eclipticLongitude)
        )

        // Equatorial to horizon via the observer's local sidereal time
        let hourAngle = rad(localSiderealTimeDegrees(julianDayUT: orbit.julianDayUT, longitude: longitude))
            - rightAscension
        let latitudeRad = rad(latitude)

        let sinAltitude = sin(declination) * sin(latitudeRad)
            + cos(declination) * cos(latitudeRad) * cos(hourAngle)
        let altitude = asin(min(max(sinAltitude, -1), 1))

        // Azimuth measured from south (positive towards west), then rotated to from-north
        let azimuthFromSouth = atan2(
            sin(hourAngle),
            cos(hourAngle) * sin(latitudeRad) - tan(declination) * cos(latitudeRad)
        )
        let azimuth = mod360(deg(azimuthFromSouth) + 180)

        return MoonPosition(azimuth: azimuth, altitude: deg(altitude))
    }

    /// Moonrise and moonset for the local day containing `date` in `timeZone`.
    ///
    /// Samples the altitude hourly across the day and bisects each horizon
    /// crossing down to a fraction of a second: 25 samples plus 20 steps
    /// per crossing, all of them microseconds.
    static func riseAndSet(latitude: Double, longitude: Double, date: Date, timeZone: TimeZone) -> MoonDayEvents {
        guard let day = calendar(for: timeZone).dateInterval(of: .day, for: date) else {
            return MoonDayEvents(moonrise: nil, moonset: nil)
        }

        // Height of the moon above its rise/set altitude: negative before
        // moonrise and after moonset, positive while it is up
        func height(at instant: Date) -> Double {
            position(latitude: latitude, longitude: longitude, date: instant).altitude - riseSetAltitude
        }

        // The instant the height changes sign somewhere inside (start, end)
        func crossing(between start: Date, and end: Date, rising: Bool) -> Date {
            var lowerBound = start
            var upperBound = end
            for _ in 0..<20 {
                let midpoint = lowerBound.addingTimeInterval(upperBound.timeIntervalSince(lowerBound) / 2)
                let isUpAtMidpoint = height(at: midpoint) >= 0
                if isUpAtMidpoint == rising {
                    upperBound = midpoint
                } else {
                    lowerBound = midpoint
                }
            }
            return upperBound
        }

        var moonrise: Date?
        var moonset: Date?
        var windowStart = day.start
        var heightAtStart = height(at: windowStart)

        while windowStart < day.end {
            let windowEnd = min(windowStart.addingTimeInterval(3600), day.end)
            let heightAtEnd = height(at: windowEnd)

            if heightAtStart < 0, heightAtEnd >= 0, moonrise == nil {
                moonrise = crossing(between: windowStart, and: windowEnd, rising: true)
            } else if heightAtStart >= 0, heightAtEnd < 0, moonset == nil {
                moonset = crossing(between: windowStart, and: windowEnd, rising: false)
            }

            windowStart = windowEnd
            heightAtStart = heightAtEnd
        }

        return MoonDayEvents(moonrise: moonrise, moonset: moonset)
    }

    // MARK: - Rise/set altitude

    /// Geocentric altitude of the moon's centre when its upper limb touches
    /// the horizon: horizontal parallax (~57') less atmospheric refraction
    /// (34') and the moon's semi-diameter (16'). Meeus, Astronomical
    /// Algorithms, chapter 15.
    private static let riseSetAltitude = 0.125

    // MARK: - Calendar cache

    // Calendar(identifier:) + timeZone assignment is surprisingly expensive;
    // riseAndSet() runs on cache misses during time scrubbing, so keep one per zone.
    private static let calendarLock = NSLock()
    private static var calendarsByZone: [String: Calendar] = [:]

    private static func calendar(for timeZone: TimeZone) -> Calendar {
        calendarLock.lock()
        defer { calendarLock.unlock() }
        if let cached = calendarsByZone[timeZone.identifier] {
            return cached
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendarsByZone[timeZone.identifier] = calendar
        return calendar
    }

    // MARK: - Orbital elements

    /// Sun and moon ecliptic elements at one instant, all in degrees; the
    /// common ground of every public value above.
    private struct OrbitalElements {
        /// Julian day of the instant in Universal Time.
        let julianDayUT: Double
        let sunLongitude: Double
        let correctedAnomaly: Double
        let equationOfCentre: Double
        /// Moon's true ecliptic longitude measured along its orbit.
        let trueLongitude: Double
        /// Corrected longitude of the moon's ascending node.
        let ascendingNode: Double
    }

    private static func orbitalElements(for date: Date) -> OrbitalElements {
        // Days since the J2000 epoch, in Terrestrial Time
        // (the same fixed 63.8 s ΔT correction MoonKit applied).
        let julianDayUT = date.timeIntervalSince1970 / 86400.0 + 2440587.5
        let d = julianDayUT + 63.8 / 86400.0 - 2451545.0

        // Sun: mean anomaly and true ecliptic longitude
        let sunMeanAnomaly = mod360(360.0 / 365.242191 * d + 280.466069 - 282.938346)
        let sunEquationOfCentre = 360.0 / Double.pi * 0.016708 * sin(rad(sunMeanAnomaly))
        let sunLongitude = mod360(sunMeanAnomaly + sunEquationOfCentre + 282.938346)

        // Moon: mean elements
        let meanLongitude = mod360(13.176339686 * d + 218.316433)
        let meanAnomaly = mod360(meanLongitude - 0.1114041 * d - 83.353451)
        let meanAscendingNode = mod360(125.044522 - 0.0529539 * d)

        // Corrections: annual equation, evection, equation of the centre, variation
        let annualEquation = 0.1858 * sin(rad(sunMeanAnomaly))
        let evection = 1.2739 * sin(rad(2 * (meanLongitude - sunLongitude) - meanAnomaly))
        let correctedAnomaly = meanAnomaly + evection - annualEquation - 0.37 * sin(rad(sunMeanAnomaly))
        let equationOfCentre = 6.2886 * sin(rad(correctedAnomaly)) + 0.214 * sin(rad(2 * correctedAnomaly))
        let correctedLongitude = meanLongitude + evection + equationOfCentre - annualEquation
        let variation = 0.6583 * sin(rad(2 * (correctedLongitude - sunLongitude)))
        let trueLongitude = correctedLongitude + variation
        let ascendingNode = meanAscendingNode - 0.16 * sin(rad(sunMeanAnomaly))

        return OrbitalElements(
            julianDayUT: julianDayUT,
            sunLongitude: sunLongitude,
            correctedAnomaly: correctedAnomaly,
            equationOfCentre: equationOfCentre,
            trueLongitude: trueLongitude,
            ascendingNode: ascendingNode
        )
    }

    /// Greenwich mean sidereal time (Meeus 12.4) carried to the observer's
    /// meridian, in degrees.
    private static func localSiderealTimeDegrees(julianDayUT: Double, longitude: Double) -> Double {
        let daysSinceJ2000 = julianDayUT - 2451545.0
        let centuries = daysSinceJ2000 / 36525.0
        let greenwich = 280.46061837
            + 360.98564736629 * daysSinceJ2000
            + 0.000387933 * centuries * centuries
            - centuries * centuries * centuries / 38710000.0
        return mod360(greenwich + longitude)
    }

    // MARK: - Angle helpers

    private static func mod360(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 360)
        return remainder < 0 ? remainder + 360 : remainder
    }

    private static func rad(_ degrees: Double) -> Double { degrees * .pi / 180 }

    private static func deg(_ radians: Double) -> Double { radians * 180 / .pi }
}
