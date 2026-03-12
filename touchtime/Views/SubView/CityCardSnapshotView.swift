//
//  CityCardSnapshotView.swift
//  touchtime
//
//  Created on 15/02/2026.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WeatherKit

private struct SnapshotStar: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
}

private struct SnapshotSeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        // Keep generator non-zero for stable sequence
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }
    
    mutating func next() -> UInt64 {
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return state
    }
}

private struct SnapshotStarsView: View {
    let starCount: Int
    let seed: UInt64
    
    var body: some View {
        GeometryReader { geometry in
            let stars = generateStars(in: geometry.size)
            
            ZStack {
                ForEach(stars) { star in
                    Circle()
                        .fill(
                            star.size > 1.5 ?
                            Color(white: 1.0) :
                            Color(white: 0.95, opacity: 1.0)
                        )
                        .frame(width: star.size, height: star.size)
                        .blur(radius: star.size > 1.5 ? 0.3 : 0)
                        .shadow(color: Color(white: 0.9).opacity(0.9), radius: star.size > 1.2 ? 3 : 1)
                        .position(x: star.x, y: star.y)
                }
            }
            .drawingGroup()
        }
    }
    
    private func generateStars(in size: CGSize) -> [SnapshotStar] {
        guard size.width > 0, size.height > 0 else { return [] }
        
        var generator = SnapshotSeededGenerator(seed: seed)
        
        return (0..<starCount).map { index in
            let starType = Double.random(in: 0...1, using: &generator)
            let starSize: CGFloat
            
            if starType < 0.75 {
                starSize = CGFloat.random(in: 0.4...0.8, using: &generator)
            } else if starType < 0.97 {
                starSize = CGFloat.random(in: 0.8...1.4, using: &generator)
            } else {
                starSize = CGFloat.random(in: 1.5...2.5, using: &generator)
            }
            
            return SnapshotStar(
                id: index,
                x: CGFloat.random(in: 0...size.width, using: &generator),
                y: CGFloat.random(in: 0...size.height, using: &generator),
                size: starSize
            )
        }
    }
}

// Transferable image for sharing via ShareLink
struct CardImage: Transferable {
    let uiImage: UIImage
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { cardImage in
            guard let data = cardImage.uiImage.pngData() else {
                throw CocoaError(.fileWriteUnknown)
            }
            return data
        }
    }
}

// MARK: - City Card Snapshot View for Sharing
struct CityCardSnapshotView: View {
    let cityName: String
    let timeString: String
    let dateString: String
    let date: Date
    let timeZone: TimeZone
    let timeZoneIdentifier: String
    let weather: CurrentWeather?
    let weatherCondition: WeatherCondition?
    let useCelsius: Bool
    let showAnalogClock: Bool
    let analogClockShowScale: Bool
    let showSunPosition: Bool
    let showWeatherCondition: Bool
    let showTemperatureIndicator: Bool
    let showUVIndex: Bool
    let showWindDirection: Bool
    let showSunAzimuth: Bool
    let showMoonAzimuth: Bool
    let showMoonSunAzimuth: Bool
    let showSunriseSunset: Bool
    let showDaylight: Bool
    let showSolarCurve: Bool
    let additionalTimeDisplay: String
    let showSkyDot: Bool
    let additionalTimeText: String
    
    private var hasComplication: Bool {
        showAnalogClock || showSunPosition || showWeatherCondition || showTemperatureIndicator || showUVIndex || showWindDirection || showSunAzimuth || showMoonAzimuth || showMoonSunAzimuth || showSunriseSunset || showDaylight || showSolarCurve
    }
    
    private var skyColorGradient: SkyColorGradient {
        SkyColorGradient(date: date, timeZoneIdentifier: timeZoneIdentifier, weatherCondition: weatherCondition)
    }
    
    private var snapshotStarSeed: UInt64 {
        let timeComponent = UInt64(abs(Int64(date.timeIntervalSince1970.rounded())))
        let zoneComponent = UInt64(abs(timeZoneIdentifier.unicodeScalars.reduce(0) { $0 + Int($1.value) }))
        return timeComponent ^ (zoneComponent << 1)
    }
    
    var body: some View {
        ZStack {
            // Sky Background - only show when Sky Colour is enabled
            Color.black
            if showSkyDot {
                Rectangle()
                    .fill(skyColorGradient.linearGradient(opacity: 0.65))
                if skyColorGradient.starOpacity > 0 {
                    SnapshotStarsView(starCount: 50, seed: snapshotStarSeed)
                        .opacity(skyColorGradient.starOpacity)
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                }
                Color.black.opacity(0.015)
                    .blendMode(.plusDarker)
            }
            
            // Card replica from HomeView, centered vertically
            ZStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Top row: Time difference / SkyDot and Date
                    HStack {
                        if additionalTimeDisplay != "None" {
                            if !additionalTimeText.isEmpty || additionalTimeDisplay == "UTC" {
                                Text(additionalTimeText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .blendMode(.plusLighter)
                            }
                        } else if showSkyDot {
                            SkyDotView(
                                date: date,
                                timeZoneIdentifier: timeZoneIdentifier,
                                weatherCondition: weatherCondition
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                                    .blendMode(.plusLighter)
                            )
                        }
                        
                        Spacer()

                        if weather != nil {
                            WeatherView(
                                weather: weather,
                                useCelsius: useCelsius
                            )
                            .contentTransition(.numericText())
                        }
                        
                        Text(dateString)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .blendMode(.plusLighter)
                    }
                    
                    // Bottom row: City name and Time
                    HStack(alignment: .lastTextBaseline) {
                        Text(cityName)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: hasComplication ? 120 : .infinity, alignment: .leading)
                        
                        Spacer()
                        
                        Text(timeString)
                            .font(.system(size: 36))
                            .fontWeight(.light)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                    }
                    .padding(.bottom, -4)
                    .background {
                        if showSkyDot {
                                if skyColorGradient.starOpacity > 0 {
                                    SnapshotStarsView(starCount: 30, seed: snapshotStarSeed ^ 0xA5A5A5A5)
                                        .opacity(min(1.0, skyColorGradient.starOpacity * 1.15))
                                        .blendMode(.plusLighter)
                                        .allowsHitTesting(false)
                                }
                        }
                    }
                }
                .frame(minHeight: 64)
                
                // Complication Overlays
                ComplicationOverlayView(
                    date: date,
                    timeZone: timeZone,
                    showAnalogClock: showAnalogClock,
                    analogClockShowScale: analogClockShowScale,
                    showSunPosition: showSunPosition,
                    showWeatherCondition: showWeatherCondition,
                    showTemperatureIndicator: showTemperatureIndicator,
                    showUVIndex: showUVIndex,
                    showWindDirection: showWindDirection,
                    showSunAzimuth: showSunAzimuth,
                    showMoonAzimuth: showMoonAzimuth,
                    showMoonSunAzimuth: showMoonSunAzimuth,
                    showSunriseSunset: showSunriseSunset,
                    showDaylight: showDaylight,
                    showSolarCurve: showSolarCurve,
                    bottomPadding: 0
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                if showSkyDot {
                    SkyBackgroundView(
                        date: date,
                        timeZoneIdentifier: timeZoneIdentifier,
                        weatherCondition: weatherCondition
                    )
                } else {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(width: 360, height: 640) // 9:16 share frame ratio
    }
}
