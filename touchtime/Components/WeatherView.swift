//
//  WeatherView.swift
//  touchtime
//
//  Created on 01/11/2025.
//

import SwiftUI
import WeatherKit

struct WeatherView: View {
    let weather: CurrentWeather?
    let useCelsius: Bool
    let showDivider: Bool = true
    
    var body: some View {
        if let weather = weather {
            HStack(spacing: 4) {
                Text(formatTemperature(weather.temperature))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .contentTransition(.numericText())
                
                if showDivider {
                    Text("·")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .contentTransition(.numericText())
                }
            }
        }
    }
    
    private func formatTemperature(_ temperature: Measurement<UnitTemperature>) -> String {
        let temp = useCelsius ? temperature.converted(to: .celsius) : temperature.converted(to: .fahrenheit)
        return "\(Int(temp.value))°"
    }
}
