//
//  HourlyForecastRow.swift
//  touchtime
//
//  Created on 30/10/2026.
//

import SwiftUI
import WeatherKit

/// The next 24 hours of conditions, opened from today's daily forecast card.
struct HourlyForecastRow: View {
    let hours: [HourWeather]
    let dateFormat: DetailsDateFormat
    @Binding var isHourlyForecastShown: Bool

    @AppStorage("useCelsius") private var useCelsius = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(hours.prefix(24).enumerated()), id: \.offset) { index, hour in
                    if index == 0 {
                        Button {
                            if hapticEnabled {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                            withAnimation(.snappy(duration: 0.5)) {
                                isHourlyForecastShown = false
                            }
                        } label: {
                            hourCard(hour, isCurrentHour: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Now"))
                    } else {
                        hourCard(hour, isCurrentHour: false)
                    }
                }
            }
        }
        .horizontalScrollEdgeFade()
        // The fade mask composites the row offscreen, so the cards'
        // plusLighter blend is reapplied to the whole row.
        .blendMode(.plusLighter)
    }

    private func hourCard(_ hour: HourWeather, isCurrentHour: Bool) -> some View {
        let temperature = useCelsius ?
        hour.temperature.converted(to: .celsius) :
        hour.temperature.converted(to: .fahrenheit)
        let precipitationChance = Int((hour.precipitationChance * 100).rounded())

        return ZStack {
            // Kept at the card's geometric center; the optional precipitation
            // label no longer pushes the condition down.
            Image(systemName: hour.condition.icon)
                .symbolRenderingMode(.multicolor)
                .font(.title3)
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
                .frame(height: 28)

            VStack(spacing: 0) {
                Text("\(Int(temperature.value))°")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()

                if precipitationChance > 0 {
                    Text("\(precipitationChance)%")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.cyan)
                        .monospacedDigit()
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)

                HStack(spacing: 3) {
                    if isCurrentHour {
                        Image(systemName: "chevron.left")
                            .font(.caption2.weight(.bold))
                    }

                    Text(isCurrentHour ? String(localized: "Now") : dateFormat.forecastHour(hour.date))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(isCurrentHour ? Color.primary : Color.secondary)
                .blendMode(.plusLighter)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            width: ForecastCardMetrics.width,
            height: ForecastCardMetrics.contentHeight
        )
        .padding(.vertical, 12)
        .detailsSheetCardChrome()
        .accessibilityElement(children: .combine)
    }
}
