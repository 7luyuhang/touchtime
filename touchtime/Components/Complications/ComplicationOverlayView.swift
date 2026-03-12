//
//  ComplicationOverlayView.swift
//  touchtime
//
//  Created on 12/03/2026.
//

import SwiftUI

struct ComplicationDisplayOptions: Equatable {
    let showAnalogClock: Bool
    let analogClockShowScale: Bool
    let showSunPosition: Bool
    let showWeatherCondition: Bool
    let showTemperatureIndicator: Bool
    let showUVIndex: Bool
    let showWindDirection: Bool
    let showSunAzimuth: Bool
    let showMoonAzimuth: Bool
    let showMoonSunAzimuth: Bool
    let showSunriseSunset: Bool
    let showDaylight: Bool
    let showSolarCurve: Bool

    var hasVisibleComplication: Bool {
        showAnalogClock ||
        showSunPosition ||
        showWeatherCondition ||
        showTemperatureIndicator ||
        showUVIndex ||
        showWindDirection ||
        showSunAzimuth ||
        showMoonAzimuth ||
        showMoonSunAzimuth ||
        showSunriseSunset ||
        showDaylight ||
        showSolarCurve
    }
}

struct ComplicationOverlayView: View {
    let date: Date
    let timeZone: TimeZone
    let options: ComplicationDisplayOptions
    var size: CGFloat = 64
    var bottomPadding: CGFloat = 0

    @EnvironmentObject private var weatherManager: WeatherManager

    var body: some View {
        Group {
            if options.showAnalogClock {
                AnalogClockView(
                    date: date,
                    size: size,
                    timeZone: timeZone,
                    showScale: options.analogClockShowScale
                )
                .complicationOverlayStyle(bottomPadding: bottomPadding)
            }

            if options.showSunPosition {
                SunPositionIndicator(
                    date: date,
                    timeZone: timeZone,
                    size: size
                )
                .complicationOverlayStyle(bottomPadding: bottomPadding)
            }

            if options.showWeatherCondition {
                WeatherConditionView(
                    timeZone: timeZone,
                    size: size
                )
                .environmentObject(weatherManager)
                .complicationOverlayStyle(bottomPadding: bottomPadding)
            }

            if options.showTemperatureIndicator {
                TemperatureIndicator(
                    timeZone: timeZone,
                    size: size
                )
                .environmentObject(weatherManager)
                .complicationOverlayStyle(bottomPadding: bottomPadding)
            }

            if options.showUVIndex {
                UVIndexIndicator(
                    timeZone: timeZone,
                    size: size
                )
                .environmentObject(weatherManager)
                .complicationOverlayStyle(bottomPadding: bottomPadding)
            }

            if options.showWindDirection {
                WindDirectionIndicator(
                    timeZone: timeZone,
                    size: size
                )
                .environmentObject(weatherManager)
                .complicationOverlayStyle(bottomPadding: bottomPadding)
            }

            if options.showSunAzimuth {
                SunAzimuthIndicator(
                    date: date,
                    timeZone: timeZone,
                    size: size
                )
                .complicationOverlayStyle(bottomPadding: bottomPadding)
            }

            if options.showMoonAzimuth {
                MoonAzimuthIndicator(
                    date: date,
                    timeZone: timeZone,
                    size: size
                )
                .complicationOverlayStyle(bottomPadding: bottomPadding)
            }

            if options.showMoonSunAzimuth {
                MoonSunAzimuthIndicator(
                    date: date,
                    timeZone: timeZone,
                    size: size
                )
                .complicationOverlayStyle(bottomPadding: bottomPadding)
            }

            if options.showSunriseSunset {
                SunriseSunsetIndicator(
                    date: date,
                    timeZone: timeZone,
                    size: size
                )
                .complicationOverlayStyle(bottomPadding: bottomPadding)
            }

            if options.showDaylight {
                DaylightIndicator(
                    date: date,
                    timeZone: timeZone,
                    size: size
                )
                .complicationOverlayStyle(bottomPadding: bottomPadding)
            }

            if options.showSolarCurve {
                SolarCurve(
                    date: date,
                    timeZone: timeZone,
                    size: size
                )
                .complicationOverlayStyle(bottomPadding: bottomPadding)
            }
        }
    }
}

private extension View {
    func complicationOverlayStyle(bottomPadding: CGFloat) -> some View {
        padding(.bottom, bottomPadding)
            .transition(.blurReplace)
    }
}
