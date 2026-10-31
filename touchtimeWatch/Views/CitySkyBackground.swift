//
//  CitySkyBackground.swift
//  touchtimeWatch
//

import SwiftUI

/// The sky over a city at `date`, stars and all, as the iPhone app shows it.
struct CitySkyBackground: View {
    let date: Date
    let timeZone: TimeZone
    /// How many stars show at night.
    var starCount = 25

    var body: some View {
        let sky = SkyColorGradient(date: date, timeZoneIdentifier: timeZone.identifier)

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
    }
}
