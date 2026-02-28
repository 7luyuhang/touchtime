//
//  WindDirectionIndicator.swift
//  touchtime
//
//  Created on 28/02/2026.
//

import SwiftUI
import WeatherKit

struct WindDirectionIndicator: View {
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool
    private let previewWindFromDegrees: Double?

    @EnvironmentObject private var weatherManager: WeatherManager

    init(
        timeZone: TimeZone = .current,
        size: CGFloat = 100,
        useMaterialBackground: Bool = false,
        previewWindFromDegrees: Double? = nil
    ) {
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
        self.previewWindFromDegrees = previewWindFromDegrees
    }

    private var sourceDirectionDegrees: Double {
        previewWindFromDegrees ?? weatherManager.windDirectionDegrees(for: timeZone.identifier) ?? 0
    }

    private var directionDegrees: Double {
        (sourceDirectionDegrees + 180).truncatingRemainder(dividingBy: 360)
    }

    private var hasWindData: Bool {
        weatherManager.windDirectionDegrees(for: timeZone.identifier) != nil
    }

    var body: some View {
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
                .fill(.white.opacity(0.10))
                .frame(width: size, height: 1)
                .blendMode(.plusLighter)

            Capsule()
                .fill(.white.opacity(0.10))
                .frame(width: 1, height: size)
                .blendMode(.plusLighter)

            GeometryReader { geometry in
                let baseSize = min(geometry.size.width, geometry.size.height)
                let lineWidth = max(2, baseSize * 0.03)
                let lineHeight = baseSize * 0.60
                let triangleSize = max(8, baseSize * 0.15)
                let strokeOpacity = hasWindData ? 1.0 : 0.50
                let endDotSize = baseSize * 0.125

                VStack(spacing: -triangleSize * 0.50) {
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: triangleSize * 1.50))
                        .foregroundStyle(.white.opacity(strokeOpacity))
                        .zIndex(1)

                    VStack(spacing: -lineWidth * 0.5) {
                        Capsule(style: .continuous)
                            .fill(.white.opacity(strokeOpacity))
                            .frame(width: lineWidth, height: lineHeight)

                        Circle()
                            .stroke(.white.opacity(strokeOpacity), lineWidth: max(1.5, lineWidth * 1.0))
                            .frame(width: endDotSize, height: endDotSize)
                    }
                }
                .padding(.bottom, size * 0.025) // Optical alignment
                .frame(width: geometry.size.width, height: geometry.size.height)
                .rotationEffect(.degrees(directionDegrees), anchor: .center)
            }
            .scaleEffect(0.85)
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

        WindDirectionIndicator(
            timeZone: .current,
            size: 64,
            previewWindFromDegrees: 180
        )
            .environmentObject(WeatherManager())
    }
}
