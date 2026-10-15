//
//  DSTLabel.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI

/// Next DST transition, e.g. "DST Ends Oct 25 -1 hours"
struct DSTLabel: View {
    let isStart: Bool
    let transitionDate: Date
    let offsetHours: Int
    let dateFormat: DetailsDateFormat

    var body: some View {
        HStack(spacing: 5) {
            Text("DST")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Text(isStart ? String(localized: "Starts") : String(localized: "Ends"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Text(dateFormat.monthDay(transitionDate))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary)

            if offsetHours != 0 {
                Text(offsetHours > 0 ? String(format: String(localized: "+%d hours"), offsetHours) : String(format: String(localized: "%d hours"), offsetHours))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .blendMode(.plusLighter)
    }
}
