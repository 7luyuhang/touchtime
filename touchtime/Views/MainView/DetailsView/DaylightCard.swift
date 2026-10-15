//
//  DaylightCard.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI

/// How long the sun is up today. Tap for the daylight sheet.
struct DaylightCard: View {
    let sunrise: Date?
    let sunset: Date?
    @Binding var showsDaylightSheet: Bool

    @AppStorage("hapticEnabled") private var hapticEnabled = true

    var body: some View {
        Button {
            if hapticEnabled {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            showsDaylightSheet = true
        } label: {
            HStack {
                HStack(spacing: 12){
                    Image(systemName: "rays")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .frame(width: 24)

                    Text("Daylight")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                }
                Spacer()

                Text(duration)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.spring(), value: "\(sunrise?.description ?? "")\(sunset?.description ?? "")")

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .blendMode(.plusLighter)
            }
            .detailsSheetCard()
        }
        .buttonStyle(.plain)
    }

    private var duration: String {
        guard let start = sunrise, let end = sunset else { return "-" }

        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60

        if minutes == 0 {
            return String(format: String(localized: "%d hours"), hours)
        }
        return String(format: String(localized: "%d hours %d minutes"), hours, minutes)
    }
}
