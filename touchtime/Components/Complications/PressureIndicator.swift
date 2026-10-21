//
//  PressureIndicator.swift
//  touchtime
//
//  Created on 15/10/2026.
//
//  Pressure complication, in the style of the Daylight Curve:
//  - a dot on the ring marks the current sea-level pressure, from low
//    pressure (left) through standard pressure (top) to high pressure (right)
//  - light spreads from the dot to both sides, fading along the ring
//  - the gap below shows the trend (rising, falling or steady)
//

import SwiftUI
import WeatherKit

struct PressureIndicator: View {
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool

    @EnvironmentObject private var weatherManager: WeatherManager
    @State private var displayedAngle: Double = 0

    // The scale covers standard pressure ± 40 hPa, deep lows to strong highs;
    // readings beyond that rest at its ends
    private static let standardPressure: Double = 1013.25
    private static let pressureRange: Double = 40
    // Degrees from 12 o'clock to either end of the scale
    private static let scaleHalfSweep: Double = 135
    // Degrees the light fades over on each side of the dot
    private static let glowHalfSpread: Double = 55

    init(timeZone: TimeZone = .current, size: CGFloat = 100, useMaterialBackground: Bool = false) {
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
    }

    private var weather: CurrentWeather? {
        weatherManager.weatherData[timeZone.identifier]
    }

    // Clockwise from 12 o'clock: -135° at the low end, 135° at the high end
    private var markerAngle: Double {
        guard let pressure = weather?.pressure.converted(to: .hectopascals).value else { return 0 }
        let offset = (pressure - Self.standardPressure) / Self.pressureRange
        return min(max(offset, -1), 1) * Self.scaleHalfSweep
    }

    private var trendSymbolName: String {
        weather?.pressureTrend.symbolName ?? "equal"
    }

    var body: some View {
        let orbitRadius: CGFloat = size * 0.375
        let lineWidth: CGFloat = size * 0.125
        let markerSize: CGFloat = size * 0.125

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

            PressureGlow(
                halfSpread: Self.glowHalfSpread,
                size: size,
                orbitRadius: orbitRadius,
                lineWidth: lineWidth
            )
            .rotationEffect(.degrees(displayedAngle))
            .opacity(0.90)
            .blur(radius: size * 0.035)
            .blendMode(.plusLighter)
            .drawingGroup()

            Circle()
                .fill(.white)
                .frame(width: markerSize, height: markerSize)
                .offset(y: -orbitRadius)
                .rotationEffect(.degrees(displayedAngle))
                .blendMode(.plusLighter)

            Image(systemName: trendSymbolName)
                .font(.system(size: size * 0.25, weight: .bold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .animation(.spring(), value: trendSymbolName)
                .offset(y: size * 0.25)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .onAppear {
            displayedAngle = markerAngle
        }
        .onChange(of: markerAngle) { _, newAngle in
            withAnimation(.spring()) {
                displayedAngle = newAngle
            }
        }
        .task {
            await weatherManager.getWeather(for: timeZone.identifier)
        }
    }
}

private struct PressureGlow: View {
    let halfSpread: Double
    let size: CGFloat
    let orbitRadius: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        // Centred on 12 o'clock; SwiftUI measures angles from 3 o'clock
        let startAngle = Angle.degrees(-halfSpread - 90)
        let endAngle = Angle.degrees(halfSpread - 90)

        Path { path in
            path.addArc(
                center: CGPoint(x: size / 2, y: size / 2),
                radius: orbitRadius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: false
            )
        }
        .stroke(
            AngularGradient(
                colors: [.white.opacity(0.0), .white.opacity(1.0), .white.opacity(0.0)],
                center: .center,
                startAngle: startAngle,
                endAngle: endAngle
            ),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
        .frame(width: size, height: size)
    }
}

extension PressureTrend {
    var symbolName: String {
        switch self {
        case .rising: return "arrow.up"
        case .falling: return "arrow.down"
        default: return "equal"
        }
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        PressureIndicator(timeZone: .current, size: 64)
            .environmentObject(WeatherManager.shared)
    }
}
