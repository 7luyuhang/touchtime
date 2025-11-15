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
    
    private var temperatureValue: Int? {
        guard let weather = weather else { return nil }
        let temp = useCelsius ? 
            weather.temperature.converted(to: .celsius) : 
            weather.temperature.converted(to: .fahrenheit)
        return Int(temp.value)
    }
    
    var body: some View {
        if let tempValue = temperatureValue {
            HStack(spacing: 4) {
                Text("\(tempValue)°")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .contentTransition(.numericText())
                    .animation(.spring(), value: tempValue)
                
                if showDivider {
                    Text("·")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                }
            }
        }
    }
}
