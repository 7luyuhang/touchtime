//
//  WeeklyForecastRow.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI
import WeatherKit

/// The coming days' highs, lows and conditions, scrolling sideways.
struct WeeklyForecastRow: View {
    let days: [DayWeather]
    let timeZoneIdentifier: String

    @AppStorage("useCelsius") private var useCelsius = true

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 5) {
                        // High temperature
                        let highTemp = useCelsius ?
                        day.highTemperature.converted(to: .celsius) :
                        day.highTemperature.converted(to: .fahrenheit)
                        Text("\(Int(highTemp.value))°")
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()

                        // Low temperature
                        let lowTemp = useCelsius ?
                        day.lowTemperature.converted(to: .celsius) :
                        day.lowTemperature.converted(to: .fahrenheit)
                        Text("\(Int(lowTemp.value))°")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .blendMode(.plusLighter)
                            .monospacedDigit()

                        // Weather icon
                        Image(systemName: day.condition.icon)
                            .symbolRenderingMode(.multicolor)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .blendMode(.plusLighter)
                            .frame(height: 28)

                        // Day of week
                        Text(dayOfWeek(day.date))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .blendMode(.plusLighter)
                            .padding(.top, 5)
                    }
                    .frame(width: 64)
                    .padding(.vertical, 12)
                    .detailsSheetCardChrome()
                }
            }
        }
        .horizontalScrollEdgeFade()
        // The fade mask composites the row offscreen, so the cards'
        // plusLighter blend is reapplied to the whole row
        .blendMode(.plusLighter)
    }

    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale.current

        // Use very short weekday format (M, T, W, etc.)
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }
}
