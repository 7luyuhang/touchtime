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
        HStack(spacing: 8) {
            // Keep Now available to switch back after scrolling ahead.
            if let currentHour = hours.first {
                Button {
                    if hapticEnabled {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    withAnimation(.snappy(duration: 0.5)) {
                        isHourlyForecastShown = false
                    }
                } label: {
                    hourCard(currentHour, isCurrentHour: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Now"))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(hours.prefix(24).dropFirst().enumerated()), id: \.offset) { _, hour in
                        hourCard(hour, isCurrentHour: false)
                    }
                }
            }
            .horizontalScrollEdgeFade()
        }
        // The scroll mask composites its cards offscreen, so reapply
        // their plusLighter blend to the whole row.
        .blendMode(.plusLighter)
    }

    private func hourCard(_ hour: HourWeather, isCurrentHour: Bool) -> some View {
        let temperature = useCelsius ?
        hour.temperature.converted(to: .celsius) :
        hour.temperature.converted(to: .fahrenheit)
        let chance = hour.precipitationChance
        let precipitationChance = chance.isFinite && (0...1).contains(chance)
            ? Int((chance * 100).rounded())
            : 0

        return ZStack {
            // Keep the icon centered, with precipitation below it in an
            // overlay so the label cannot move the icon or the time.
            Image(systemName: hour.condition.icon)
                .symbolRenderingMode(.monochrome)
                .font(.title3)
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
                .frame(height: 28)
                .overlay(alignment: .top) {
                    if precipitationChance > 0 {
                        Text("\(precipitationChance)%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.cyan)
                            .monospacedDigit()
                            .fixedSize()
                            .padding(.top, 32) // Below the 28pt icon row, with a 4pt gap.
                    }
                }

            // Mirror the daily card's rows so the temperature has the same
            // vertical position, whether or not precipitation is shown.
            VStack(spacing: 5) {
                Text("\(Int(temperature.value))°")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()

                // Reserve the daily low-temperature line using its font metrics.
                Text("0°")
                    .font(.subheadline.weight(.medium))
                    .hidden()

                Color.clear
                    .frame(height: 28)

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
                .padding(.top, 5)
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
