//
//  SkyDotView.swift
//  touchtime
//
//  Created on 25/09/2025.
//

import SwiftUI
import WeatherKit

struct SkyDotView: View {
    let date: Date
    let timeZoneIdentifier: String
    var weatherCondition: WeatherCondition? = nil
    
    // Create sky color gradient instance
    private var skyColorGradient: SkyColorGradient {
        SkyColorGradient(date: date, timeZoneIdentifier: timeZoneIdentifier, weatherCondition: weatherCondition)
    }
    
    var body: some View {
        // Reuse a single `SkyColorGradient` instead of constructing one per access
        // (each init does Calendar copies + dateComponents).
        let gradient = skyColorGradient
        Capsule(style: .continuous)
            .fill(gradient.linearGradient())
            .frame(width: 24, height: 16)
//            .overlay(
//                Capsule(style: .continuous)
//                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
//                    .blendMode(.plusLighter)
//            )
            .glassEffect(.clear)
            .animation(.easeInOut(duration: 0.5), value: gradient.animationValue)
    }
}
