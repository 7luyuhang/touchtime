//
//  MoonTimeSection.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI

/// Moonrise and moonset, today's phase, and the principal phases ahead.
struct MoonTimeSection: View {
    let moonrise: Date?
    let moonset: Date?
    let phaseName: String
    let phaseIcon: String
    let upcomingPhases: [UpcomingMoonPhase]
    let currentDate: Date
    let timeOffset: TimeInterval
    let timeZoneIdentifier: String
    let dateFormat: DetailsDateFormat
    @Binding var showsMoonPhaseView: Bool
    @Binding var isPhasesExpanded: Bool

    @AppStorage("selectedMoonPhaseIcon") private var selectedPhaseIcon = "moonphase.full.moon" // Phase shown in the "Next ..." row

    /// The upcoming phase shown in the "Next ..." row. Tapping one of the
    /// four phase columns below changes it; defaults to the full moon.
    private var selectedPhase: UpcomingMoonPhase? {
        upcomingPhases.first { $0.icon == selectedPhaseIcon } ?? upcomingPhases.first
    }

    var body: some View {
        VStack(alignment: .leading){
            Text("Moon Time")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
                .padding(.horizontal, 32)
                .padding(.bottom, 4)
                .padding(.top, 24)

            HStack(spacing: 8) {
                RiseSetTimeCard(symbolName: "moonrise.fill", time: moonrise, dateFormat: dateFormat)
                RiseSetTimeCard(symbolName: "moonset.fill", time: moonset, dateFormat: dateFormat)
            }
            .padding(.horizontal, 16)

            MoonPhaseCard(phaseName: phaseName, phaseIcon: phaseIcon, showsMoonPhaseView: $showsMoonPhaseView)
                .padding(.horizontal, 16)

            if let selectedPhase {
                NextMoonPhaseCard(
                    phase: selectedPhase,
                    currentDate: currentDate,
                    timeOffset: timeOffset,
                    timeZoneIdentifier: timeZoneIdentifier,
                    isExpanded: $isPhasesExpanded
                )
                .padding(.horizontal, 16)
            }

            if isPhasesExpanded && !upcomingPhases.isEmpty {
                UpcomingMoonPhasesRow(
                    phases: upcomingPhases,
                    dateFormat: dateFormat,
                    selectedPhaseIcon: $selectedPhaseIcon
                )
                .padding(.horizontal, 16)
                .transition(.blurReplace())
            }
        }
    }
}
