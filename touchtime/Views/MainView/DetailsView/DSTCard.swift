//
//  DSTCard.swift
//  touchtime
//
//  Created on 15/11/2026.
//

import SwiftUI

/// The next DST change, e.g. "DST Ends  Oct 25 -1h". Tap for the DST sheet.
struct DSTCard: View {
    let isStart: Bool
    let transitionDate: Date
    let offsetHours: Int
    let dateFormat: DetailsDateFormat
    @Binding var showsDSTSheet: Bool

    @AppStorage("hapticEnabled") private var hapticEnabled = true

    var body: some View {
        Button {
            if hapticEnabled {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            showsDSTSheet = true
        } label: {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .frame(width: 24)

                    HStack(spacing: 4) {
                        Text("DST")
                        Text(isStart ? String(localized: "Starts") : String(localized: "Ends"))
                    }
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                }
                Spacer()

                HStack(spacing: 6) {
                    Text(dateFormat.monthDay(transitionDate))
                        .foregroundStyle(.primary)

                    if offsetHours != 0 {
                        Text(offsetText)
                            .foregroundStyle(.secondary)
                            .blendMode(.plusLighter)
                    }
                }
                .monospacedDigit()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .blendMode(.plusLighter)
            }
            .lineLimit(1)
            .contentTransition(.numericText())
            .animation(.spring(), value: transitionDate)
            .detailsSheetCard()
        }
        .buttonStyle(.plain)
    }

    /// e.g. "+1h"
    private var offsetText: String {
        offsetHours > 0
            ? String(format: String(localized: "+%d hours"), offsetHours)
            : String(format: String(localized: "%d hours"), offsetHours)
    }
}
