//
//  TemperatureIndicator.swift
//  touchtime
//
//  Created on 07/03/2026.
//

import SwiftUI
import WeatherKit

struct TemperatureIndicator: View {
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool

    @EnvironmentObject private var weatherManager: WeatherManager
    @State private var displayedAngle: Double
    private let trimStart: Double = 0.15
    private let trimEnd: Double = 0.85

    init(timeZone: TimeZone = .current, size: CGFloat = 100, useMaterialBackground: Bool = false) {
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
        _displayedAngle = State(initialValue: 0)
    }

    private enum TemperatureBand: Int {
        case hot = 0
        case warm = 1
        case mild = 2
        case temperate = 3
        case cool = 4
        case cold = 5
        case frigid = 6

        static func from(celsius: Double) -> TemperatureBand {
            switch celsius {
            case 38...:
                return .hot
            case 30..<38:
                return .warm
            case 22..<30:
                return .mild
            case 14..<22:
                return .temperate
            case 6..<14:
                return .cool
            case -2..<6:
                return .cold
            default:
                return .frigid
            }
        }

        // frigid -> 0.0, hot -> 1.0
        var normalizedProgress: Double {
            Double(TemperatureBand.frigid.rawValue - rawValue) / Double(TemperatureBand.frigid.rawValue)
        }
    }

    private var celsiusTemperature: Double? {
        weatherManager.weatherData[timeZone.identifier]?.temperature
            .converted(to: .celsius)
            .value
    }

    private var currentBand: TemperatureBand {
        guard let celsiusTemperature else { return .temperate }
        return TemperatureBand.from(celsius: celsiusTemperature)
    }

    private var markerProgress: Double {
        currentBand.normalizedProgress
    }

    private var markerOpacity: Double {
        markerProgress
    }

    private var markerAngle: Double {
        let markerFraction = trimStart + markerProgress * (trimEnd - trimStart)
        // Circle trim starts at trailing edge; +180 aligns with the trimmed + rotated center arc.
        return markerFraction * 360.0 + 180.0
    }

    var body: some View {
        let centerGlyphSize = size * 0.60
        let centerGlyphLineWidth = size * 0.125 // 64x64 -> 8pt
        let markerSize = max(8, size * 0.125)
        let arcOuterRadius = centerGlyphSize * 0.45 + centerGlyphLineWidth * 0.5
        let markerOrbitRadius = arcOuterRadius + markerSize * 0.15 // Keep marker closer to the arc

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

            Circle()
                .trim(from: trimStart, to: trimEnd)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            .white.opacity(0.0), // left / low
                            .white.opacity(1.0)  // right / high
                        ]),
                        center: .center,
                        startAngle: .degrees(trimStart * 360),
                        endAngle: .degrees(trimEnd * 360)
                    ),
                    style: StrokeStyle(
                        lineWidth: centerGlyphLineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .opacity(0.50)
                .blur(radius: 2.5)
                .blendMode(.plusLighter)
                .rotationEffect(.degrees(90))
                .frame(width: centerGlyphSize, height: centerGlyphSize)

            Image(systemName: "triangle.fill") // Temp indicator
                .font(.system(size: markerSize, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(180)) // Base orientation: point inward when at top
                .offset(y: -markerOrbitRadius)
                .rotationEffect(.degrees(displayedAngle)) // Orbit position; tip still points to center
            
        }
        .frame(width: size, height: size)
        .onAppear {
            displayedAngle = markerAngle
        }
        .onChange(of: markerAngle) { _, newAngle in
            withAnimation(.spring()) {
                displayedAngle = shortestRotationTarget(from: displayedAngle, to: newAngle)
            }
        }
        .task {
            await weatherManager.getWeather(for: timeZone.identifier)
        }
    }

    private func shortestRotationTarget(from current: Double, to target: Double) -> Double {
        let delta = ((target - current).truncatingRemainder(dividingBy: 360) + 540)
            .truncatingRemainder(dividingBy: 360) - 180
        return current + delta
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        TemperatureIndicator(timeZone: .current, size: 64)
            .environmentObject(WeatherManager())
    }
}
