//
//  MoonPhaseCard.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI

/// Today's moon phase. Tap for the moon phase calendar.
struct MoonPhaseCard: View {
    let phaseName: String
    let phaseIcon: String
    @Binding var showsMoonPhaseView: Bool

    @AppStorage("hapticEnabled") private var hapticEnabled = true

    var body: some View {
        Button {
            if hapticEnabled {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            showsMoonPhaseView = true
        } label: {
            HStack {
                HStack(spacing: 12){
                    Image(systemName: phaseIcon)
                        .symbolRenderingMode(.monochrome)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .frame(width: 24)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(.spring(), value: phaseIcon)

                    Text("Moon Phase")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                }
                Spacer()

                Text(phaseName)
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .blendMode(.plusLighter)
            }
            .detailsSheetCard()
        }
        .buttonStyle(.plain)
    }
}
