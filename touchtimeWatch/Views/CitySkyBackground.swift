//
//  CitySkyBackground.swift
//  touchtimeWatch
//

import SwiftUI

/// The sky over a city at `date`, stars and all, as the iPhone app shows it,
/// in rain's grays while it's raining there now.
struct CitySkyBackground: View {
    let date: Date
    let timeZone: TimeZone
    /// How many stars show at night.
    var starCount = 25

    @Environment(WatchWeatherStore.self) private var weatherStore

    var body: some View {
        let sky = SkyColorGradient(
            date: date,
            timeZoneIdentifier: timeZone.identifier,
            weatherCondition: weatherStore.weather[timeZone.identifier]?.current.condition
        )

        ZStack {
            Rectangle()
                .fill(sky.linearGradientOverBlack(opacity: 0.65))
                .animation(.easeInOut(duration: 0.5), value: sky.animationValue)

            if sky.starOpacity > 0 {
                StarsView(starCount: starCount)
                    .opacity(sky.starOpacity)
                    .blendMode(.plusLighter)
                    .animation(.easeInOut(duration: 0.5), value: sky.starOpacity)
            }
        }
        // Every quarter hour, in case the weather has gone stale.
        .onChange(of: Int(date.timeIntervalSinceReferenceDate / 900), initial: true) {
            weatherStore.update(for: timeZone)
        }
        .onChange(of: timeZone) {
            weatherStore.update(for: timeZone)
        }
    }
}
