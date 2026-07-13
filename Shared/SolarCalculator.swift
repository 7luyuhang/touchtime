//
//  SolarCalculator.swift
//  touchtime
//
//  Pure-math NOAA solar calculator, replacing SunKit.
//
//  SunKit allocated and ran a DateFormatter for every internal property
//  access, which made a single Sun init cost 5-15 ms and dominated
//  main-thread CPU (~20%) while scrubbing time (Instruments, 2026-07-10).
//  The NOAA equations below are the ones behind the NOAA Solar Calculator;
//  they are accurate to well under a minute for event times, and run in
//  microseconds because they never touch Foundation date parsing.
//

import Foundation

enum SolarCalculator {

    // MARK: - Public API

    struct Position {
        /// Degrees clockwise from true north, in 0..<360.
        let azimuth: Double
        /// Degrees above the horizon (negative when the sun is below it).
        let altitude: Double
    }

    struct DayEvents {
        let solarNoon: Date
        let sunrise: Date
        let sunset: Date
        let civilDawn: Date
        let civilDusk: Date
        let nauticalDawn: Date
        let nauticalDusk: Date
        let astronomicalDawn: Date
        let astronomicalDusk: Date
        /// Evening golden hour: sun elevation +6° down to −4° (matches SunKit).
        let eveningGoldenHourStart: Date
        let eveningGoldenHourEnd: Date
    }

    /// Sun azimuth/altitude at an exact instant. Timezone-independent.
    static func position(latitude: Double, longitude: Double, date: Date) -> Position {
        let angles = solarAngles(julianCentury: julianCentury(for: date))
        let haRad = hourAngleDegrees(date: date, longitude: longitude, eqTimeMinutes: angles.eqTimeMinutes) * .pi / 180
        let latRad = latitude * .pi / 180
        let decl = angles.declinationRad

        let cosZenith = sin(latRad) * sin(decl) + cos(latRad) * cos(decl) * cos(haRad)
        let zenithRad = acos(min(max(cosZenith, -1), 1))
        let altitude = 90 - zenithRad * 180 / .pi

        // Azimuth measured from south (positive towards west), then rotated to from-north.
        let azimuthSouthRad = atan2(sin(haRad), cos(haRad) * sin(latRad) - tan(decl) * cos(latRad))
        var azimuth = azimuthSouthRad * 180 / .pi + 180
        azimuth = azimuth.truncatingRemainder(dividingBy: 360)
        if azimuth < 0 { azimuth += 360 }

        return Position(azimuth: azimuth, altitude: altitude)
    }

    /// All sun event times for the local day containing `date` in `timeZone`.
    ///
    /// Every event is clamped into the local day (last instant 23:59:59),
    /// matching SunKit's behavior at high latitudes where a dusk event can be
    /// missing (polar day/night) or fall past local midnight. Downstream code
    /// (e.g. SkyColorGradient) relies on dawn < noon < dusk ordering within
    /// one local day, so the clamp is load-bearing, not just cosmetic.
    static func events(latitude: Double, longitude: Double, date: Date, timeZone: TimeZone) -> DayEvents {
        guard let dayInterval = calendar(for: timeZone).dateInterval(of: .day, for: date) else {
            let noon = date
            return DayEvents(
                solarNoon: noon, sunrise: noon, sunset: noon,
                civilDawn: noon, civilDusk: noon,
                nauticalDawn: noon, nauticalDusk: noon,
                astronomicalDawn: noon, astronomicalDusk: noon,
                eveningGoldenHourStart: noon, eveningGoldenHourEnd: noon
            )
        }
        let startOfDay = dayInterval.start
        let lastInstantOfDay = dayInterval.end.addingTimeInterval(-1)

        // Solar noon: start from local clock noon and cancel out the hour angle.
        // Two passes are enough; equation-of-time drift between passes is < 1 s.
        var noon = startOfDay.addingTimeInterval(12 * 3600)
        for _ in 0..<2 {
            let angles = solarAngles(julianCentury: julianCentury(for: noon))
            let ha = hourAngleDegrees(date: noon, longitude: longitude, eqTimeMinutes: angles.eqTimeMinutes)
            noon = noon.addingTimeInterval(-ha * 4 * 60)
        }

        // Sun crossing of a given zenith angle on the morning or evening side
        // of noon, clamped into the local day.
        func crossing(zenithDegrees: Double, morning: Bool) -> Date {
            let latRad = latitude * .pi / 180
            let cosZenith = cos(zenithDegrees * .pi / 180)
            var result = noon
            for _ in 0..<2 {
                let decl = solarAngles(julianCentury: julianCentury(for: result)).declinationRad
                let cosHa = (cosZenith - sin(latRad) * sin(decl)) / (cos(latRad) * cos(decl))
                if cosHa > 1 {
                    return noon // polar night for this threshold: zero-length day
                }
                if cosHa < -1 {
                    // Polar day: no crossing; pin to the edges of the local day.
                    return morning ? startOfDay : lastInstantOfDay
                }
                let haMinutes = acos(cosHa) * 180 / .pi * 4
                result = noon.addingTimeInterval((morning ? -haMinutes : haMinutes) * 60)
            }
            return min(max(result, startOfDay), lastInstantOfDay)
        }

        // 90.833° = 90° + atmospheric refraction (34') + solar radius (16').
        return DayEvents(
            solarNoon: noon,
            sunrise: crossing(zenithDegrees: 90.833, morning: true),
            sunset: crossing(zenithDegrees: 90.833, morning: false),
            civilDawn: crossing(zenithDegrees: 96, morning: true),
            civilDusk: crossing(zenithDegrees: 96, morning: false),
            nauticalDawn: crossing(zenithDegrees: 102, morning: true),
            nauticalDusk: crossing(zenithDegrees: 102, morning: false),
            astronomicalDawn: crossing(zenithDegrees: 108, morning: true),
            astronomicalDusk: crossing(zenithDegrees: 108, morning: false),
            eveningGoldenHourStart: crossing(zenithDegrees: 84, morning: false),
            eveningGoldenHourEnd: crossing(zenithDegrees: 94, morning: false)
        )
    }

    // MARK: - Calendar cache

    // Calendar(identifier:) + timeZone assignment is surprisingly expensive;
    // events() runs on cache misses during time scrubbing, so keep one per zone.
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

    // MARK: - NOAA core equations

    private struct SolarAngles {
        let declinationRad: Double
        let eqTimeMinutes: Double
    }

    private static func julianCentury(for date: Date) -> Double {
        // Julian date = unix / 86400 + 2440587.5; centuries since J2000.0.
        (date.timeIntervalSince1970 / 86400 + 2440587.5 - 2451545.0) / 36525
    }

    private static func solarAngles(julianCentury t: Double) -> SolarAngles {
        let degToRad = Double.pi / 180

        let meanLong = (280.46646 + t * (36000.76983 + t * 0.0003032))
            .truncatingRemainder(dividingBy: 360)
        let meanAnom = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)

        let meanAnomRad = meanAnom * degToRad
        let center = sin(meanAnomRad) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * meanAnomRad) * (0.019993 - 0.000101 * t)
            + sin(3 * meanAnomRad) * 0.000289
        let trueLong = meanLong + center

        let omegaRad = (125.04 - 1934.136 * t) * degToRad
        let apparentLongRad = (trueLong - 0.00569 - 0.00478 * sin(omegaRad)) * degToRad

        let meanObliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let obliquityRad = (meanObliquity + 0.00256 * cos(omegaRad)) * degToRad

        let declinationRad = asin(sin(obliquityRad) * sin(apparentLongRad))

        let y = tan(obliquityRad / 2) * tan(obliquityRad / 2)
        let meanLongRad = meanLong * degToRad
        let eqTimeMinutes = 4 / degToRad * (
            y * sin(2 * meanLongRad)
            - 2 * eccentricity * sin(meanAnomRad)
            + 4 * eccentricity * y * sin(meanAnomRad) * cos(2 * meanLongRad)
            - 0.5 * y * y * sin(4 * meanLongRad)
            - 1.25 * eccentricity * eccentricity * sin(2 * meanAnomRad)
        )

        return SolarAngles(declinationRad: declinationRad, eqTimeMinutes: eqTimeMinutes)
    }

    /// Hour angle in degrees, normalized to [-180, 180). 0 at solar noon,
    /// negative in the morning, positive in the afternoon.
    private static func hourAngleDegrees(date: Date, longitude: Double, eqTimeMinutes: Double) -> Double {
        let minutesIntoUTCDay = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400) / 60
        let trueSolarTime = minutesIntoUTCDay + eqTimeMinutes + 4 * longitude
        var hourAngle = (trueSolarTime / 4 - 180).truncatingRemainder(dividingBy: 360)
        if hourAngle < -180 {
            hourAngle += 360
        } else if hourAngle >= 180 {
            hourAngle -= 360
        }
        return hourAngle
    }
}
