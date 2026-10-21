//
//  PressureCard.swift
//  touchtime
//
//  Created on 17/10/2026.
//

import SwiftUI
import WeatherKit

/// Sea-level pressure and its trend (left) + pressure complication (right)
struct PressureCard: View {
    let pressure: Measurement<UnitPressure>
    let trend: PressureTrend
    // 9, 6 and 3 hours ago, oldest first
    let recentTrends: [PressureTrend]
    let timeZoneIdentifier: String

    @AppStorage(PressureUnit.storageKey) private var pressureUnit = PressureUnit.millibars

    var body: some View {
        let complicationSize: CGFloat = 64
        let pressureText = formattedPressure
        let trendText = trendName

        HStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Text("Pressure")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .lineLimit(1)

                    Spacer()

                    Text(pressureText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .animation(.spring(), value: pressureText)
                }

                Divider()
                    .overlay(.white.opacity(0.10))
                    .blendMode(.plusLighter)

                HStack {
                    Text(trendText)
                        .font(.body)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .contentTransition(.numericText())
                        .animation(.spring(), value: trendText)

                    Spacer()

                    HStack(spacing: 8) {
                        ForEach(recentTrends.indices, id: \.self) { index in
                            Image(systemName: recentTrends[index].symbolName)
                                .foregroundStyle(.tertiary)
                                .blendMode(.plusLighter)
                                .contentTransition(.symbolEffect(.replace))
                        }

                        Image(systemName: trend.symbolName)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .font(.subheadline.weight(.semibold))
                    .animation(.spring(), value: recentTrends)
                    .animation(.spring(), value: trend)
                }
            }

            Color.clear
                .frame(width: complicationSize, height: complicationSize)
        }
        .detailsSheetCard()
        // Over the card rather than in it: the card's plusLighter blend would
        // add the glass's copy of the sky back onto the sky and wash it out
        .overlay(alignment: .trailing) {
            PressureIndicator(
                timeZone: TimeZone(identifier: timeZoneIdentifier) ?? .current,
                size: complicationSize
            )
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 1)
                    .blendMode(.plusLighter)
            )
            .padding(.trailing, 16)
        }
    }

    // Pressure in the unit picked in Settings → Units, e.g. "1,033 mbar"
    private var formattedPressure: String {
        pressure.converted(to: pressureUnit.unit).formatted(
            .measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(pressureUnit.fractionDigits))
            )
        )
    }

    private var trendName: String {
        switch trend {
        case .rising:
            return String(localized: "Rising")
        case .falling:
            return String(localized: "Falling")
        case .steady:
            return String(localized: "Steady")
        @unknown default:
            return trend.description
        }
    }
}
