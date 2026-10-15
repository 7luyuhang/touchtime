//
//  GoldenHourCard.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI

/// The evening golden hour, filling up from the leading edge while it lasts.
struct GoldenHourCard: View {
    let start: Date
    let end: Date
    let currentDate: Date
    let timeOffset: TimeInterval
    let dateFormat: DetailsDateFormat

    private var isInGoldenHour: Bool {
        guard end > start else { return false }
        let adjustedNow = currentDate.addingTimeInterval(timeOffset)
        return adjustedNow >= start && adjustedNow <= end
    }

    private var fillProgress: Double {
        guard end > start else { return 0 }
        let adjustedNow = currentDate.addingTimeInterval(timeOffset)
        let fraction = adjustedNow.timeIntervalSince(start) / end.timeIntervalSince(start)
        return min(max(fraction, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: "sun.max.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                // Golden Hour text
                Text("Golden Hour")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)

                Spacer()

                // Time range
                HStack(spacing: 8) {
                    Text(dateFormat.timeWithoutPeriod(start))
                        .monospacedDigit()
                        .lineLimit(1)
                        .contentTransition(.numericText(countsDown: false))
                        .animation(.spring(), value: start)
                    Image(systemName: "arrow.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(isInGoldenHour ? .yellow : .secondary)
                        .animation(.spring(), value: isInGoldenHour)
                    Text(dateFormat.time(end))
                        .monospacedDigit()
                        .lineLimit(1)
                        .contentTransition(.numericText(countsDown: false))
                        .animation(.spring(), value: end)
                }
                .lineLimit(1)
                .layoutPriority(1)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(alignment: .leading) {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.white.opacity(0.05))
                        .blendMode(.plusLighter)
                        .frame(width: geometry.size.width * CGFloat(fillProgress))
                        .frame(maxHeight: .infinity)
                }
                .opacity(isInGoldenHour ? 1 : 0)
            }
        }
        .detailsSheetCardChrome()
    }
}
