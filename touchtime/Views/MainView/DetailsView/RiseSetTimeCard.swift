//
//  RiseSetTimeCard.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI

/// A sunrise, sunset, moonrise or moonset time, marked by its symbol.
struct RiseSetTimeCard: View {
    let symbolName: String
    let time: Date?
    let dateFormat: DetailsDateFormat

    var body: some View {
        HStack {
            Image(systemName: symbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
                .frame(width: 24)

            Spacer()

            Text(dateFormat.time(time))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: false))
                .animation(.spring(), value: time)
        }
        .frame(maxWidth: .infinity)
        .detailsSheetCard()
    }
}
