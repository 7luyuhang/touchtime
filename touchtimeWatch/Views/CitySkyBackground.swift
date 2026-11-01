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

    @Environment(WatchCityStore.self) private var cityStore

    var body: some View {
        let condition = cityStore.weatherCondition(for: timeZone.identifier)
        let sky = SkyColorGradient(date: date, timeZoneIdentifier: timeZone.identifier, weatherCondition: condition)

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
        .overlay {
            CityRainOverlay(intensity: condition?.rainIntensity ?? 0)
        }
    }
}

/// Rain on glass for watchOS, where SwiftUI's Metal layer effects are unavailable.
struct CityRainOverlay: View {
    let intensity: Float

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var startDate = Date()

    var body: some View {
        if intensity > 0 {
            TimelineView(.animation(
                minimumInterval: 1.0 / 15,
                paused: !isVisible || scenePhase != .active || isLuminanceReduced || reduceMotion
            )) { timeline in
                let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSince(startDate)
                Canvas { context, size in
                    let count = max(8, min(56, Int(size.width * size.height / 1_100 * CGFloat(intensity))))
                    let travel = size.height + 30
                    for index in 0..<count {
                        let seed = CGFloat((index * 37 + 11) % 101) / 101
                        let phase = CGFloat((index * 61 + 23) % 103) / 103
                        let radius = 0.8 + seed * 1.2
                        let x = seed * size.width
                        let y = (CGFloat(elapsed) * (8 + seed * 12) + phase * travel)
                            .truncatingRemainder(dividingBy: travel) - 15
                        let drop = Path(ellipseIn: CGRect(x: x - radius, y: y, width: radius * 2, height: radius * 3))
                        context.fill(drop, with: .color(.black.opacity(0.18)))
                        context.stroke(drop, with: .color(.white.opacity(0.35)), lineWidth: 0.5)

                        let top = CGPoint(x: x, y: y - 8 - radius * 4)
                        let bottom = CGPoint(x: x, y: y)
                        var trail = Path()
                        trail.move(to: top)
                        trail.addLine(to: bottom)
                        context.stroke(trail, with: .linearGradient(
                            Gradient(colors: [.clear, .white.opacity(0.18)]),
                            startPoint: top,
                            endPoint: bottom
                        ), lineWidth: radius * 0.7)
                    }
                }
            }
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
        }
    }
}
