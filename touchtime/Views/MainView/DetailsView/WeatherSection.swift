//
//  WeatherSection.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI
import WeatherKit

/// Current conditions, the coming days' forecast, precipitation, wind, UV
/// index and pressure, or a note when the weather couldn't be loaded.
struct WeatherSection: View {
    let weather: CurrentWeather?
    let dailyWeather: DayWeather?
    let weeklyWeather: [DayWeather]
    let hourlyWeather: [HourWeather]
    let recentPressureTrends: [PressureTrend]
    let loadAttempted: Bool
    let timeZoneIdentifier: String
    let currentDate: Date
    let dateFormat: DetailsDateFormat
    @Binding var isExpanded: Bool

    // Today's precipitation chance, rounded to whole percent
    private var precipitationChancePercent: Int {
        Int(((dailyWeather?.precipitationChance ?? 0) * 100).rounded())
    }

    var body: some View {
        if let weather {
            VStack(alignment: .leading, spacing: 8) {
                CurrentWeatherCard(
                    weather: weather,
                    dailyWeather: dailyWeather,
                    isExpanded: $isExpanded
                )
                .padding(.horizontal, 16)

                // Weekly weather section (expandable)
                if isExpanded && !weeklyWeather.isEmpty {
                    WeeklyForecastRow(days: weeklyWeather, timeZoneIdentifier: timeZoneIdentifier)
                        .padding(.horizontal, 16)
                        .transition(.blurReplace())
                }

                // Precipitation section (expandable), hidden when chance is 0%
                if isExpanded && !hourlyWeather.isEmpty && precipitationChancePercent > 0 {
                    PrecipitationCard(hourlyWeather: hourlyWeather, chancePercent: precipitationChancePercent)
                        .padding(.horizontal, 16)
                        .transition(.blurReplace())
                }

                // Wind section
                WindCard(
                    speed: weather.wind.speed,
                    gust: weather.wind.gust,
                    timeZoneIdentifier: timeZoneIdentifier
                )
                .padding(.horizontal, 16)

                // UV index section
                UVIndexCard(
                    uvIndex: weather.uvIndex,
                    dailyWeather: dailyWeather,
                    hourlyWeather: hourlyWeather,
                    currentDate: currentDate,
                    timeZoneIdentifier: timeZoneIdentifier,
                    dateFormat: dateFormat
                )
                .padding(.horizontal, 16)

                // Pressure section
                PressureCard(
                    pressure: weather.pressure,
                    trend: weather.pressureTrend,
                    recentTrends: recentPressureTrends,
                    timeZoneIdentifier: timeZoneIdentifier
                )
                .padding(.horizontal, 16)
            }
            .padding(.top, 16) // Row top padding

        } else if loadAttempted {
            // Show "No Internet" message when weather is enabled but couldn't be loaded
            HStack {
                Spacer()
                Text("No Weather Data")
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                Spacer()
            }
            .detailsSheetCardRow()
            .padding(.top, 16) // Row top padding
        }
    }
}
