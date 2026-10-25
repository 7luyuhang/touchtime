//
//  WindSpeedIndicator.swift
//  touchtime
//
//  Created on 25/10/2026.
//
//  Wind speed complication, on a compass face with north at the top:
//  - the current wind speed in the middle, in the unit picked in
//    Settings → Units
//  - two markers on the ring point the way the wind blows: the tail on the
//    side it comes from, the head on the side it goes to
//

import SwiftUI
import WeatherKit

struct WindSpeedIndicator: View {
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool
    private let previewWindFromDegrees: Double?
    private let previewSpeed: Measurement<UnitSpeed>?
    @State private var displayedArrowDegrees: Double

    @EnvironmentObject private var weatherManager: WeatherManager
    @AppStorage(WindSpeedUnit.storageKey) private var windSpeedUnit = WindSpeedUnit.kilometersPerHour

    init(
        timeZone: TimeZone = .current,
        size: CGFloat = 100,
        useMaterialBackground: Bool = false,
        previewWindFromDegrees: Double? = nil,
        previewSpeed: Measurement<UnitSpeed>? = nil
    ) {
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
        self.previewWindFromDegrees = previewWindFromDegrees
        self.previewSpeed = previewSpeed
        let initialArrowDegrees = ((previewWindFromDegrees ?? 0) + 180).truncatingRemainder(dividingBy: 360)
        _displayedArrowDegrees = State(initialValue: initialArrowDegrees)
    }

    private var speedText: String {
        guard let speed = previewSpeed ?? weatherManager.weatherData[timeZone.identifier]?.wind.speed else {
            return "-"
        }
        return speed.converted(to: windSpeedUnit.unit).value
            .formatted(.number.precision(.fractionLength(0)))
    }

    // Clockwise from north, the way the wind blows: opposite where it comes from
    private var arrowDegrees: Double {
        let fromDegrees = previewWindFromDegrees ?? weatherManager.windDirectionDegrees(for: timeZone.identifier) ?? 0
        return (fromDegrees + 180).truncatingRemainder(dividingBy: 360)
    }

    var body: some View {
        let markerHeight = size * 0.165

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

            // Ticks at NE, SE, SW and NW
            Path { path in
                let center = size / 2
                // Horizontal and vertical distances from the centre to each end of a tick
                let innerOffset = size * 0.36 / 2.squareRoot()
                let outerOffset = size * 0.4375 / 2.squareRoot()
                for (dx, dy) in [(1.0, -1.0), (1.0, 1.0), (-1.0, 1.0), (-1.0, -1.0)] {
                    path.move(to: CGPoint(x: center + dx * innerOffset, y: center + dy * innerOffset))
                    path.addLine(to: CGPoint(x: center + dx * outerOffset, y: center + dy * outerOffset))
                }
            }
            .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
            .blendMode(.plusLighter)

            ZStack {
                // Tail, pointing in from the side the wind comes from
                RoundedTriangle(cornerRadius: size * 0.02)
                    .frame(width: size * 0.18, height: markerHeight)
                    .offset(y: size * 0.3625)

                // Head, pointing out to the side the wind goes to
                RoundedTriangle(cornerRadius: size * 0.015)
                    .frame(width: size * 0.105, height: markerHeight)
                    .offset(y: -size * 0.4185)
            }
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(displayedArrowDegrees))

            Text(speedText)
                .font(.system(size: size * 0.285, weight: .semibold))
                .monospacedDigit()
                .fontDesign(.rounded)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: size * 0.5)
                .contentTransition(.numericText())
                .animation(.spring(), value: speedText)
        }
        .frame(width: size, height: size)
        .onAppear {
            displayedArrowDegrees = arrowDegrees
        }
        .onChange(of: arrowDegrees) { _, newValue in
            withAnimation(.spring(duration: 0.5)) {
                displayedArrowDegrees = shortestRotationTarget(from: displayedArrowDegrees, to: newValue)
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

/// A triangle pointing up, with rounded corners
private struct RoundedTriangle: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let apex = CGPoint(x: rect.midX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)

        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addArc(tangent1End: bottomRight, tangent2End: apex, radius: cornerRadius)
        path.addArc(tangent1End: apex, tangent2End: bottomLeft, radius: cornerRadius)
        path.addArc(tangent1End: bottomLeft, tangent2End: bottomRight, radius: cornerRadius)
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        WindSpeedIndicator(
            timeZone: .current,
            size: 64,
            previewWindFromDegrees: 270,
            previewSpeed: Measurement(value: 5, unit: .kilometersPerHour)
        )
        .environmentObject(WeatherManager.shared)
    }
}
