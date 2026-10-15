//
//  PrecipitationCard.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI
import WeatherKit

/// Today's precipitation chance (right) + next 12 hours of precipitation amount bars (mm)
struct PrecipitationCard: View {
    let hourlyWeather: [HourWeather]
    let chancePercent: Int

    var body: some View {
        let hours = Array(hourlyWeather.prefix(12))
        let amounts = hours.map { max($0.precipitationAmount.converted(to: .millimeters).value, 0) }
        let referenceAmount = max(amounts.max() ?? 0, 1) // Full bar at max amount, at least 1 mm

        HStack {
            HStack(spacing: 12) {
                Image(systemName: "drop.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .frame(width: 24)

                Text("Precipitation")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 12) {
                // One bar per hour, height maps to precipitation amount (mm)
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(Array(amounts.enumerated()), id: \.offset) { _, amount in
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(.white.opacity(0.10))
                                .blendMode(.plusLighter)

                            if amount > 0 {
                                Capsule()
                                    .fill(.cyan)
                                    .frame(height: max(4, CGFloat(amount / referenceAmount) * 16))
                            }
                        }
                        .frame(width: 4, height: 16)
                    }
                }

                Text(chancePercent, format: .percent)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(), value: chancePercent)
            }
            .lineLimit(1)
            .layoutPriority(1)
        }
        .detailsSheetCard()
    }
}
