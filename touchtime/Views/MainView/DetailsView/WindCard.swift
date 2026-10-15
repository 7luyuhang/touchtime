//
//  WindCard.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI

/// Wind and gust speeds (left) + wind direction complication (right)
struct WindCard: View {
    let speed: Measurement<UnitSpeed>
    let gust: Measurement<UnitSpeed>?
    let timeZoneIdentifier: String

    @AppStorage(WindSpeedUnit.storageKey) private var windSpeedUnit = WindSpeedUnit.kilometersPerHour

    var body: some View {
        let complicationSize: CGFloat = 64

        HStack(spacing: 16) {
            VStack(spacing: 12) {
                speedLine("Wind", speed: speed)

                Divider()
                    .overlay(.white.opacity(0.10))
                    .blendMode(.plusLighter)

                speedLine("Gusts", speed: gust)
            }

            Color.clear
                .frame(width: complicationSize, height: complicationSize)
        }
        .detailsSheetCard()
        // Over the card rather than in it: the card's plusLighter blend would
        // add the glass's copy of the sky back onto the sky and wash it out
        .overlay(alignment: .trailing) {
            WindDirectionIndicator(
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

    // Wind speed in the unit picked in Settings → Units
    private func formattedSpeed(_ speed: Measurement<UnitSpeed>?) -> String {
        guard let speed else { return "-" }
        return speed.converted(to: windSpeedUnit.unit).formatted(
            .measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(0))
            )
        )
    }

    private func speedLine(_ title: LocalizedStringKey, speed: Measurement<UnitSpeed>?) -> some View {
        let speedText = formattedSpeed(speed)
        return HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
                .lineLimit(1)

            Spacer()

            Text(speedText)
                .monospacedDigit()
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.spring(), value: speedText)
        }
    }
}
