//
//  WidgetStarsView.swift
//  touchtimeWidgetExtension
//
//  Night-sky stars for the widget background. Unlike the app's StarsView
//  (which generates positions in @State via onAppear, something WidgetKit's
//  snapshot rendering can't rely on), positions here are computed
//  deterministically from a stable seed, so stars render in the archived
//  snapshot and stay fixed across timeline entries and process restarts.
//

import SwiftUI

struct WidgetStarsView: View {
    let seed: String
    var starCount: Int = 25

    private struct Star: Identifiable {
        let id: Int
        let x: CGFloat // normalized 0...1
        let y: CGFloat // normalized 0...1
        let size: CGFloat
    }

    // Same distribution as the app's StarsView: 75% small, 22% medium, 3% bright
    private static func makeStars(seed: String, count: Int) -> [Star] {
        var rng = SplitMix64(seed: fnv1aHash(seed))
        return (0..<count).map { index in
            let starType = Double.random(in: 0...1, using: &rng)
            let size: CGFloat
            if starType < 0.75 {
                size = CGFloat.random(in: 0.4...0.8, using: &rng)
            } else if starType < 0.97 {
                size = CGFloat.random(in: 0.8...1.4, using: &rng)
            } else {
                size = CGFloat.random(in: 1.5...2.5, using: &rng)
            }
            return Star(
                id: index,
                x: CGFloat.random(in: 0...1, using: &rng),
                y: CGFloat.random(in: 0...1, using: &rng),
                size: size
            )
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Self.makeStars(seed: seed, count: starCount)) { star in
                    Circle()
                        .fill(star.size > 1.5 ? Color(white: 1.0) : Color(white: 0.95))
                        .frame(width: star.size, height: star.size)
                        .blur(radius: star.size > 1.5 ? 0.3 : 0)
                        .shadow(color: Color(white: 0.9).opacity(0.9), radius: star.size > 1.2 ? 3 : 1)
                        .position(
                            x: star.x * geometry.size.width,
                            y: star.y * geometry.size.height
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// Stable string hash (String.hashValue is randomized per process launch)
private func fnv1aHash(_ string: String) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in string.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3
    }
    return hash
}

private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
