//
//  UpcomingMoonPhasesRow.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI

/// The four principal phases coming up, as columns sharing one card across
/// the full row width.
struct UpcomingMoonPhasesRow: View {
    let phases: [UpcomingMoonPhase]
    let dateFormat: DetailsDateFormat
    @Binding var selectedPhaseIcon: String

    @AppStorage("hapticEnabled") private var hapticEnabled = true

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                if index > 0 {
                    Divider()
                        .overlay(.white.opacity(0.10))
                        .blendMode(.plusLighter)
                        .padding(.vertical, 12)
                }

                VStack(spacing: 8) {
                    // Phase name
                    Text(phase.name)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .lineLimit(1)

                    // Phase icon
                    Image(systemName: phase.icon)
                        .symbolRenderingMode(.monochrome)
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .opacity(0.50)
                        .frame(height: 28)

                    // Date of the phase
                    Text(dateFormat.monthDay(phase.date))
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .onTapGesture {
                    if hapticEnabled {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    withAnimation(.spring()) {
                        selectedPhaseIcon = phase.icon
                    }
                }
            }
        }
        .detailsSheetCardChrome()
    }
}
