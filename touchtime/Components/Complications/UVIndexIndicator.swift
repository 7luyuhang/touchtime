//
//  UVIndexIndicator.swift
//  touchtime
//
//  Created on 26/02/2026.
//

import SwiftUI
import WeatherKit

struct UVIndexIndicator: View {
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool

    @EnvironmentObject private var weatherManager: WeatherManager

    init(timeZone: TimeZone = .current, size: CGFloat = 100, useMaterialBackground: Bool = false) {
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
    }

    private var uvValue: Double {
        guard let uvIndex = weatherManager.weatherData[timeZone.identifier]?.uvIndex else {
            return 0
        }
        return Double(uvIndex.value)
    }

    private var progress: CGFloat {
        CGFloat(max(0, min(1, uvValue / 11.0)))
    }

    var body: some View {
        let trackWidth = size * 0.75
        let trackHeight = max(3, size * 0.065)
        let indicatorSize = max(8, size * 0.14)
        // Keep the triangle center within the track width.
        let indicatorOffset = (-trackWidth / 2 + indicatorSize / 2) + ((trackWidth - indicatorSize) * progress)
        // Align the triangle's bottom edge to the capsule's bottom edge.
        let indicatorYOffset = trackHeight / 2 - indicatorSize / 2

        ZStack {
            if useMaterialBackground {
                Circle()
                    .fill(.black.opacity(0.05))
                    .blendMode(.plusDarker)
            } else {
                Circle()
                    .fill(.clear)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.10))
                            .glassEffect(.clear)
                    )
            }

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.green, .yellow, .orange, .red, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: trackWidth, height: trackHeight)

            Image(systemName: "triangle.fill")
                .font(.system(size: indicatorSize, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(180))
                .offset(x: indicatorOffset, y: indicatorYOffset)
        }
        .frame(width: size, height: size)
        .task {
            await weatherManager.getWeather(for: timeZone.identifier)
        }
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        UVIndexIndicator(timeZone: .current, size: 64)
            .environmentObject(WeatherManager())
    }
}
