//
//  WidgetSkyBackground.swift
//  touchtimeWidgetExtension
//
//  The one sky background shared by every TouchTime widget: sky gradient,
//  darkening overlay and star field in a single component, so all widget
//  families render an identical sky. Rainy conditions switch the gradient
//  to its nimbostratus palette and force starOpacity to 0, so stars never
//  show through rain.
//

import SwiftUI
import WeatherKit

struct WidgetSkyBackground: View {
    let date: Date
    let timeZoneIdentifier: String
    var weatherCondition: WeatherCondition? = nil

    // One star per this many square points: the small widget (~155 x 155 pt)
    // keeps its original 25 stars, larger families scale to the same visual
    // density instead of looking sparser.
    private static let areaPerStar: CGFloat = 960

    var body: some View {
        let gradient = SkyColorGradient(
            date: date,
            timeZoneIdentifier: timeZoneIdentifier,
            weatherCondition: weatherCondition
        )
        GeometryReader { geometry in
            gradient.linearGradient()
                .overlay {
                    Color.black.opacity(0.20)
                        .blendMode(.plusDarker)
                }
                .overlay {
                    if gradient.starOpacity > 0 {
                        WidgetStarsView(
                            seed: timeZoneIdentifier,
                            starCount: Self.starCount(for: geometry.size)
                        )
                        .opacity(gradient.starOpacity)
                        .blendMode(.plusLighter)
                    }
                }
        }
    }

    private static func starCount(for size: CGSize) -> Int {
        max(25, Int((size.width * size.height) / areaPerStar))
    }
}
