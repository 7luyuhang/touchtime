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
    let weatherCondition: WeatherCondition?
    let showAnalogClock: Bool
    let analogClockShowScale: Bool
    let showSunPosition: Bool
    let showWeatherCondition: Bool
    let showSunAzimuth: Bool
    let showSunriseSunset: Bool
    let showDaylight: Bool
    let showSolarCurve: Bool
    let additionalTimeDisplay: String
    let showSkyDot: Bool
    let additionalTimeText: String
    
    private var hasComplication: Bool {
        showAnalogClock || showSunPosition || showWeatherCondition || showSunAzimuth || showSunriseSunset || showDaylight || showSolarCurve
    }
    
    private var skyColorGradient: SkyColorGradient {
        SkyColorGradient(date: date, timeZoneIdentifier: timeZoneIdentifier, weatherCondition: weatherCondition)
    }
    
    var body: some View {
        ZStack {
            
            // Sky Background
            Color.black // Black Background
            Rectangle()
                .fill(skyColorGradient.linearGradient(opacity: 0.65))
            Color.black.opacity(0.015)
                .blendMode(.plusDarker)
            
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
                    showSunAzimuth: showSunAzimuth,
                    showSunriseSunset: showSunriseSunset,
                    showDaylight: showDaylight,
                    showSolarCurve: showSolarCurve,
                    bottomPadding: 0
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                SkyBackgroundView(
                    date: date,
                    timeZoneIdentifier: timeZoneIdentifier,
                    weatherCondition: weatherCondition
                )
            )
            .padding(.horizontal, 8)
        }
        .frame(width: 360, height: 360) // Ovarall Image Size
    }
}
