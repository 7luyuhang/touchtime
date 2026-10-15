//
//  NextMoonPhaseCard.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI

/// Days until the selected upcoming phase (full moon by default). Tap to
/// show or hide all four upcoming phases, where tapping one swaps it in here.
struct NextMoonPhaseCard: View {
    let phase: UpcomingMoonPhase
    let currentDate: Date
    let timeOffset: TimeInterval
    let timeZoneIdentifier: String
    @Binding var isExpanded: Bool

    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("showUpcomingMoonPhases") private var storedIsExpanded = false

    var body: some View {
        HStack {
            HStack(spacing: 12){
                Image(systemName: phase.icon)
                    .symbolRenderingMode(.monochrome)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .frame(width: 24)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.spring(), value: phase.icon)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .contentTransition(.numericText())
                    .animation(.spring(), value: phase.icon)
            }
            Spacer()

            Text(daysUntil)
                .foregroundStyle(.primary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(), value: phase.date)

            // Chevron icon
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .frame(width: 14, height: 14)
                .foregroundStyle(isExpanded ? .primary : .tertiary)
                .blendMode(.plusLighter)
                .rotationEffect(.degrees(isExpanded ? 90 : 0), anchor: .center)
        }
        .detailsSheetCard()
        .contentShape(Rectangle())
        .onTapGesture {
            if hapticEnabled {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
            let newValue = !isExpanded
            withAnimation(.snappy(duration: 0.50)) { // upcoming phases animation
                isExpanded = newValue
            }
            storedIsExpanded = newValue
        }
    }

    private var title: String {
        switch phase.icon {
        case "moonphase.new.moon":
            return String(localized: "Next New Moon")
        case "moonphase.first.quarter":
            return String(localized: "Next First Quarter")
        case "moonphase.last.quarter":
            return String(localized: "Next Last Quarter")
        default:
            return String(localized: "Next Full Moon")
        }
    }

    private var daysUntil: String {
        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        var calendar = Calendar.current
        calendar.timeZone = timeZone

        let currentLocalDate = currentDate.addingTimeInterval(timeOffset)
        let startOfToday = calendar.startOfDay(for: currentLocalDate)
        let startOfTargetDay = calendar.startOfDay(for: phase.date)
        let days = max(calendar.dateComponents([.day], from: startOfToday, to: startOfTargetDay).day ?? 0, 0)

        if Locale.current.language.languageCode?.identifier == "zh" {
            return "\(days)天"
        }

        return days == 1 ? "1 day" : "\(days) days"
    }
}
