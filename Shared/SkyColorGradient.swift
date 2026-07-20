//
//  SkyColorGradient.swift
//  touchtime
//
//  Physically based sky gradient driven by solar elevation angle.
//
//  Astronomy — the sky's appearance is, to first order, a pure function of how
//  far the sun sits above or below the horizon. Solar elevation is computed
//  with the NOAA equations in SolarCalculator (microseconds, no Foundation
//  date parsing), so seasons, latitude, polar day/night and "white nights"
//  all fall out correctly with no special cases.
//
//  Atmospheric optics — the color keyframes below encode:
//  - Rayleigh scattering (λ⁻⁴): saturated blue zenith, paler horizon where the
//    slant path and multiple scattering desaturate the blue.
//  - Ozone Chappuis-band absorption: keeps the twilight zenith blue instead of
//    gray once direct sunlight only grazes the stratosphere.
//  - Mie/aerosol scattering: bright whitish horizon haze by day, and the
//    amplified gold/orange of the twilight arch near sunrise/sunset.
//  - Airglow + scattered starlight: the near-black blue floor of true night.
//
//  Meteorology — dawn and dusk are intentionally asymmetric: aerosols settle
//  overnight so dawns run cooler and pinker, while daytime convection loads
//  the boundary layer with dust and moisture, making dusks warmer and more
//  orange. Rain swaps in a nimbostratus palette where wavelength-independent
//  Mie scattering flattens everything to soft, cool grays.
//
//  Rendering — keyframes are interpolated with smoothstep easing in the OKLab
//  perceptual color space, so the whole day is one continuous, seam-free ramp
//  with no muddy gray dead zones between hues.
//

import SwiftUI
import WeatherKit

struct SkyColorGradient {
    let date: Date
    let timeZoneIdentifier: String
    let weatherCondition: WeatherCondition?

    // Whether current weather is a rainy condition
    private let isRainy: Bool

    // Solar elevation in degrees above the horizon (negative below it).
    private let solarAltitude: Double

    // 0 = pure dawn palette, 1 = pure dusk palette. Crosses 0.5 exactly at
    // solar noon and solar midnight so the handoff never produces a seam.
    private let duskFactor: Double

    init(date: Date, timeZoneIdentifier: String, weatherCondition: WeatherCondition? = nil) {
        self.date = date
        self.timeZoneIdentifier = timeZoneIdentifier
        self.weatherCondition = weatherCondition
        self.isRainy = weatherCondition?.isRainy ?? false

        let coords = TimeZoneCoordinates.getCoordinate(for: timeZoneIdentifier)
            ?? (latitude: 51.5074, longitude: -0.1278)
        let altitude = SolarCalculator.position(
            latitude: coords.latitude,
            longitude: coords.longitude,
            date: date
        ).altitude
        self.solarAltitude = altitude.isFinite ? altitude : 40.0

        let hourAngle = SolarCalculator.hourAngle(longitude: coords.longitude, date: date)
        let hoursFromNoon = hourAngle.isFinite ? hourAngle / 15.0 : -6.0
        self.duskFactor = Self.duskFactor(hoursFromSolarNoon: hoursFromNoon)
    }

    // MARK: - Public API

    // Star visibility: stars wash out as twilight sky brightness overtakes
    // them — fully visible in astronomical night, mostly gone by mid-nautical
    // twilight, only planets left near civil twilight. At latitudes where the
    // sun never drops below -16° (white nights), stars correctly never reach
    // full strength. Rain clouds block all starlight via Mie scattering.
    var starOpacity: Double {
        if isRainy { return 0.0 }
        return 1.0 - Self.smoothstep(from: -16.0, to: -4.5, value: solarAltitude)
    }

    // Five vertical stops, zenith → horizon.
    var colors: [Color] {
        labStops.map { Self.color(fromOKLab: $0) }
    }

    // The same five stops in OKLab, zenith → horizon, for callers that need
    // to run their own color math (e.g. smoothing across time samples)
    // before converting to display colors.
    var oklabStops: [SIMD3<Double>] {
        labStops
    }

    // Converts an OKLab value (such as a smoothed `oklabStops` sample) into
    // a display color.
    static func color(fromOKLab lab: SIMD3<Double>) -> Color {
        let rgb = labToSrgb(lab)
        return Color(red: rgb.x, green: rgb.y, blue: rgb.z)
    }

    private var labStops: [Lab] {
        if isRainy {
            return Self.interpolatedStops(at: solarAltitude, in: Self.rainFrames)
        }
        if duskFactor <= 0.0 {
            return Self.interpolatedStops(at: solarAltitude, in: Self.clearDawnFrames)
        }
        if duskFactor >= 1.0 {
            return Self.interpolatedStops(at: solarAltitude, in: Self.clearDuskFrames)
        }
        let dawn = Self.interpolatedStops(at: solarAltitude, in: Self.clearDawnFrames)
        let dusk = Self.interpolatedStops(at: solarAltitude, in: Self.clearDuskFrames)
        return zip(dawn, dusk).map { $0 + ($1 - $0) * duskFactor }
    }

    // Get linear gradient with specified opacity (default 1.0 for full opacity)
    func linearGradient(opacity: Double = 1.0) -> LinearGradient {
        let gradientColors = opacity < 1.0 ? colors.map { $0.opacity(opacity) } : colors
        return LinearGradient(
            colors: gradientColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Animation trigger quantized to 0.5° of solar elevation: fires every few
    // minutes during fast twilight color changes, almost never at midday or
    // deep night when the sky is static. Encodes rain state so weather
    // changes also animate.
    var animationValue: Int {
        let band = Int(((solarAltitude + 90.0) * 2.0).rounded())
        return band * 2 + (isRainy ? 1 : 0)
    }

    // MARK: - Dawn/dusk blending

    // Smooth crossfade between the dawn and dusk palettes. Away from solar
    // noon/midnight the branches are used pure; within ±1 h of either the
    // weights ease through 0.5 so high-latitude low-noon days and midnight-sun
    // nights blend instead of snapping.
    private static func duskFactor(hoursFromSolarNoon t: Double) -> Double {
        let u = abs(t)
        if u <= 1.0 {
            let s = smoothstep01(u)
            return t >= 0 ? 0.5 + 0.5 * s : 0.5 - 0.5 * s
        }
        if u >= 11.0 {
            let s = smoothstep01(u - 11.0)
            return t >= 0 ? 1.0 - 0.5 * s : 0.5 * s
        }
        return t >= 0 ? 1.0 : 0.0
    }

    // MARK: - Palette keyframes

    private typealias RGB = SIMD3<Double> // sRGB, 0...1
    private typealias Lab = SIMD3<Double> // OKLab (L, a, b)

    private struct Keyframe {
        let altitude: Double // solar elevation in degrees
        let stops: [Lab]     // 5 stops, zenith → horizon, pre-converted to OKLab
    }

    private static func lab(_ r: Double, _ g: Double, _ b: Double) -> Lab {
        srgbToLab(RGB(r, g, b))
    }

    // Shared anchors: below -18° there is no solar contribution, so dawn and
    // dusk converge on the same night sky; above +15° both converge on the
    // same daytime Rayleigh blue. This guarantees seam-free branch blending.

    // Deep night (sun ≤ -24°): airglow, starlight and typical skyglow only.
    private static let deepNightStops: [Lab] = [
        lab(0.003, 0.005, 0.014),
        lab(0.005, 0.008, 0.022),
        lab(0.008, 0.012, 0.032),
        lab(0.012, 0.018, 0.045),
        lab(0.018, 0.026, 0.058),
    ]

    // Astronomical night boundary (-18°): last measurable trace of twilight.
    private static let nightStops: [Lab] = [
        lab(0.004, 0.007, 0.019),
        lab(0.007, 0.011, 0.029),
        lab(0.011, 0.017, 0.042),
        lab(0.017, 0.025, 0.058),
        lab(0.025, 0.035, 0.076),
    ]

    // Mid sun (+15°): fully developed clear-sky Rayleigh gradient.
    private static let dayLowStops: [Lab] = [
        lab(0.14, 0.40, 0.76),
        lab(0.27, 0.52, 0.83),
        lab(0.47, 0.66, 0.89),
        lab(0.68, 0.80, 0.93),
        lab(0.85, 0.89, 0.94),
    ]

    // High sun (+30°): deepest zenith blue, shortest optical path.
    private static let dayMidStops: [Lab] = [
        lab(0.12, 0.40, 0.79),
        lab(0.24, 0.52, 0.86),
        lab(0.43, 0.65, 0.91),
        lab(0.66, 0.80, 0.95),
        lab(0.83, 0.90, 0.97),
    ]

    // Overhead sun (≥ +50°, tropical/summer noon): maximum brightness.
    private static let dayHighStops: [Lab] = [
        lab(0.13, 0.42, 0.81),
        lab(0.26, 0.54, 0.88),
        lab(0.46, 0.68, 0.93),
        lab(0.69, 0.83, 0.96),
        lab(0.85, 0.92, 0.98),
    ]

    // Dawn branch: overnight aerosol settling gives a cleaner atmosphere —
    // cooler, rosier, more delicate colors than the evening equivalents.
    private static let clearDawnFrames: [Keyframe] = [
        Keyframe(altitude: -24.0, stops: deepNightStops),
        Keyframe(altitude: -18.0, stops: nightStops),
        // Astronomical → nautical dawn: first scattered light, deep indigo.
        Keyframe(altitude: -12.0, stops: [
            lab(0.014, 0.028, 0.095),
            lab(0.026, 0.048, 0.145),
            lab(0.045, 0.075, 0.210),
            lab(0.080, 0.110, 0.285),
            lab(0.130, 0.155, 0.350),
        ]),
        // Civil dawn / blue hour: Chappuis-band blue with first warm hint.
        Keyframe(altitude: -6.0, stops: [
            lab(0.045, 0.095, 0.27),
            lab(0.085, 0.150, 0.37),
            lab(0.160, 0.230, 0.49),
            lab(0.300, 0.320, 0.57),
            lab(0.520, 0.410, 0.54),
        ]),
        // Dawn glow: rose-lavender twilight arch over a coral horizon.
        Keyframe(altitude: -4.0, stops: [
            lab(0.08, 0.16, 0.37),
            lab(0.17, 0.25, 0.48),
            lab(0.37, 0.35, 0.57),
            lab(0.64, 0.47, 0.59),
            lab(0.90, 0.59, 0.50),
        ]),
        // Sunrise (disc on horizon, -0.833° = refraction + solar radius).
        Keyframe(altitude: -0.833, stops: [
            lab(0.14, 0.28, 0.54),
            lab(0.32, 0.40, 0.62),
            lab(0.60, 0.52, 0.65),
            lab(0.88, 0.62, 0.57),
            lab(1.00, 0.72, 0.47),
        ]),
        // Morning golden hour: long slant path still reddens the horizon.
        Keyframe(altitude: 2.0, stops: [
            lab(0.17, 0.35, 0.64),
            lab(0.37, 0.49, 0.72),
            lab(0.64, 0.64, 0.78),
            lab(0.88, 0.76, 0.74),
            lab(1.00, 0.84, 0.66),
        ]),
        // Low morning sun: warmth drains, ivory haze lingers at the horizon.
        Keyframe(altitude: 6.0, stops: [
            lab(0.16, 0.38, 0.71),
            lab(0.32, 0.51, 0.79),
            lab(0.55, 0.66, 0.85),
            lab(0.78, 0.79, 0.87),
            lab(0.94, 0.88, 0.81),
        ]),
        Keyframe(altitude: 15.0, stops: dayLowStops),
        Keyframe(altitude: 30.0, stops: dayMidStops),
        Keyframe(altitude: 50.0, stops: dayHighStops),
    ]

    // Dusk branch: daytime convection loads the air with aerosols and
    // moisture — richer golds, burnt oranges and violet in the twilight arch.
    private static let clearDuskFrames: [Keyframe] = [
        Keyframe(altitude: -24.0, stops: deepNightStops),
        Keyframe(altitude: -18.0, stops: nightStops),
        // Nautical dusk: last violet glow, slightly warmer than dawn indigo.
        Keyframe(altitude: -12.0, stops: [
            lab(0.015, 0.027, 0.090),
            lab(0.028, 0.046, 0.140),
            lab(0.050, 0.072, 0.200),
            lab(0.088, 0.100, 0.270),
            lab(0.150, 0.140, 0.320),
        ]),
        // Civil dusk / blue hour: fading rose-violet over deep blue.
        Keyframe(altitude: -6.0, stops: [
            lab(0.040, 0.085, 0.25),
            lab(0.075, 0.135, 0.35),
            lab(0.150, 0.200, 0.46),
            lab(0.310, 0.280, 0.52),
            lab(0.570, 0.370, 0.44),
        ]),
        // Sunset afterglow: violet arch over rose-red and burnt orange.
        Keyframe(altitude: -4.0, stops: [
            lab(0.075, 0.145, 0.34),
            lab(0.160, 0.220, 0.44),
            lab(0.390, 0.310, 0.52),
            lab(0.700, 0.410, 0.47),
            lab(0.940, 0.510, 0.35),
        ]),
        // Sunset (disc on horizon): maximum reddening, air mass ≈ 38.
        Keyframe(altitude: -0.833, stops: [
            lab(0.16, 0.27, 0.50),
            lab(0.36, 0.37, 0.56),
            lab(0.68, 0.47, 0.55),
            lab(0.95, 0.55, 0.43),
            lab(1.00, 0.62, 0.33),
        ]),
        // Evening golden hour: aerosol-rich gold, warmer than the morning.
        Keyframe(altitude: 2.0, stops: [
            lab(0.20, 0.35, 0.61),
            lab(0.42, 0.48, 0.67),
            lab(0.70, 0.61, 0.69),
            lab(0.93, 0.72, 0.60),
            lab(1.00, 0.78, 0.50),
        ]),
        // Low evening sun: warm ivory horizon under a softening blue.
        Keyframe(altitude: 6.0, stops: [
            lab(0.18, 0.38, 0.69),
            lab(0.35, 0.51, 0.77),
            lab(0.59, 0.65, 0.82),
            lab(0.82, 0.77, 0.81),
            lab(0.97, 0.86, 0.73),
        ]),
        Keyframe(altitude: 15.0, stops: dayLowStops),
        Keyframe(altitude: 30.0, stops: dayMidStops),
        Keyframe(altitude: 50.0, stops: dayHighStops),
    ]

    // Rain (nimbostratus): droplet Mie scattering is wavelength-independent,
    // so hue collapses to cool neutral grays whose brightness simply tracks
    // solar elevation. Warm sunrise/sunset hues never reach the cloud base.
    // Symmetric — no dawn/dusk split.
    private static let rainFrames: [Keyframe] = [
        // Night rain: dark slate, cloud base faintly lit by skyglow.
        Keyframe(altitude: -18.0, stops: [
            lab(0.070, 0.080, 0.110),
            lab(0.090, 0.100, 0.135),
            lab(0.110, 0.120, 0.160),
            lab(0.135, 0.145, 0.190),
            lab(0.165, 0.175, 0.225),
        ]),
        // Nautical twilight: darkness lifts into cold steel-blue.
        Keyframe(altitude: -12.0, stops: [
            lab(0.085, 0.095, 0.130),
            lab(0.105, 0.115, 0.155),
            lab(0.130, 0.140, 0.185),
            lab(0.160, 0.170, 0.220),
            lab(0.195, 0.205, 0.255),
        ]),
        // Civil twilight: diffuse light grows, still neutral-cool.
        Keyframe(altitude: -6.0, stops: [
            lab(0.115, 0.125, 0.170),
            lab(0.145, 0.155, 0.205),
            lab(0.175, 0.185, 0.240),
            lab(0.215, 0.225, 0.280),
            lab(0.255, 0.265, 0.315),
        ]),
        // Sun at horizon: brighter from geometry alone, no warmth.
        Keyframe(altitude: -0.833, stops: [
            lab(0.175, 0.190, 0.245),
            lab(0.220, 0.235, 0.290),
            lab(0.265, 0.280, 0.335),
            lab(0.315, 0.330, 0.380),
            lab(0.365, 0.375, 0.420),
        ]),
        // Low sun: silver-blue overcast building toward full daylight.
        Keyframe(altitude: 6.0, stops: [
            lab(0.285, 0.305, 0.365),
            lab(0.345, 0.365, 0.420),
            lab(0.405, 0.425, 0.475),
            lab(0.465, 0.485, 0.525),
            lab(0.515, 0.535, 0.575),
        ]),
        // Mid sun: high diffuse skylight through the cloud deck.
        Keyframe(altitude: 15.0, stops: [
            lab(0.365, 0.385, 0.450),
            lab(0.430, 0.450, 0.505),
            lab(0.490, 0.510, 0.555),
            lab(0.545, 0.565, 0.605),
            lab(0.590, 0.610, 0.650),
        ]),
        // High sun: brightest the overcast sky gets, still desaturated.
        Keyframe(altitude: 30.0, stops: [
            lab(0.420, 0.440, 0.510),
            lab(0.480, 0.500, 0.545),
            lab(0.530, 0.550, 0.590),
            lab(0.575, 0.595, 0.630),
            lab(0.610, 0.630, 0.670),
        ]),
    ]

    // MARK: - Keyframe interpolation

    // Smoothstep easing inside each altitude segment gives zero-slope joins
    // at every keyframe, so the ramp is C¹-continuous across the whole day.
    private static func interpolatedStops(at altitude: Double, in frames: [Keyframe]) -> [Lab] {
        guard let first = frames.first, let last = frames.last else { return [] }
        if altitude <= first.altitude { return first.stops }
        if altitude >= last.altitude { return last.stops }
        for index in 1..<frames.count where altitude < frames[index].altitude {
            let lower = frames[index - 1]
            let upper = frames[index]
            let t = smoothstep01((altitude - lower.altitude) / (upper.altitude - lower.altitude))
            return zip(lower.stops, upper.stops).map { $0 + ($1 - $0) * t }
        }
        return last.stops
    }

    // MARK: - OKLab color space (Björn Ottosson)

    // Interpolating in OKLab keeps perceived lightness and hue moving
    // uniformly — sRGB lerps would pass through muddy gray between the
    // saturated twilight hues.

    private static func srgbToLinear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private static func linearToSrgb(_ c: Double) -> Double {
        let v = max(0.0, c)
        return v <= 0.0031308 ? v * 12.92 : 1.055 * pow(v, 1.0 / 2.4) - 0.055
    }

    private static func srgbToLab(_ rgb: RGB) -> Lab {
        let r = srgbToLinear(rgb.x)
        let g = srgbToLinear(rgb.y)
        let b = srgbToLinear(rgb.z)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return Lab(
            0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        )
    }

    private static func labToSrgb(_ lab: Lab) -> RGB {
        let l0 = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z
        let m0 = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z
        let s0 = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z
        let l = l0 * l0 * l0
        let m = m0 * m0 * m0
        let s = s0 * s0 * s0
        let r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        return RGB(
            clamp01(linearToSrgb(r)),
            clamp01(linearToSrgb(g)),
            clamp01(linearToSrgb(b))
        )
    }

    // MARK: - Math helpers

    private static func clamp01(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }

    private static func smoothstep01(_ x: Double) -> Double {
        let t = clamp01(x)
        return t * t * (3.0 - 2.0 * t)
    }

    private static func smoothstep(from edge0: Double, to edge1: Double, value: Double) -> Double {
        smoothstep01((value - edge0) / (edge1 - edge0))
    }
}
