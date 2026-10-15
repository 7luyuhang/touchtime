//
//  CurrentWeatherCard.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI
import WeatherKit

/// The current condition and temperature with today's low. Tap to show or
/// hide the coming days' forecast and precipitation.
struct CurrentWeatherCard: View {
    let weather: CurrentWeather
    let dailyWeather: DayWeather?
    @Binding var isExpanded: Bool

    @AppStorage("useCelsius") private var useCelsius = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("show10DaysWeather") private var storedIsExpanded = false

    var body: some View {
        HStack {
            HStack(spacing: 12){
                Image(systemName: weather.condition.icon)
                    .symbolRenderingMode(.multicolor)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .frame(width: 24, height: 24)

                Text(weather.condition.displayName)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
            }

            Spacer()

            // Temperature
            let temp = useCelsius ?
            weather.temperature.converted(to: .celsius) :
            weather.temperature.converted(to: .fahrenheit)
            let tempValue = Int(temp.value)

            HStack(spacing: 10) {
                // Temps
                HStack(spacing: 6){
                    Text("\(tempValue)°")
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(), value: tempValue)

                    // Minimum temperature
                    if let daily = dailyWeather {
                        let minTemp = useCelsius ?
                        daily.lowTemperature.converted(to: .celsius) :
                        daily.lowTemperature.converted(to: .fahrenheit)
                        let minTempValue = Int(minTemp.value)

                        Text("\(minTempValue)°")
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.spring(), value: minTempValue)
                            .foregroundStyle(.secondary)
                            .blendMode(.plusLighter)
                    }
                }
                // Chevron icon
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 14, height: 14)
                    .foregroundStyle(isExpanded ? .primary : .tertiary)
                    .blendMode(.plusLighter)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0), anchor: .center)
            }
        }
        .detailsSheetCard()
        .contentShape(Rectangle())
        .onTapGesture {
            if hapticEnabled {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
            let newValue = !isExpanded
            withAnimation(.snappy(duration: 0.50)) { // weekly weather animation
                isExpanded = newValue
            }
            storedIsExpanded = newValue
        }
    }
}
