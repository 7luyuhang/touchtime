//
//  CityMoonPhaseView.swift
//  touchtimeWatch
//

import SwiftUI

/// The moon at the displayed instant, with its phase and the city's date.
struct CityMoonPhaseView: View {
    let date: Date
    let timeZone: TimeZone
    let dateLabel: String
    let onMoonTap: () -> Void

    private var phase: MoonPhase {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return MoonDay(containing: date, calendar: calendar).phase
    }

    var body: some View {
        let phaseName = phase.localizedName
        let moonImageName = CityMoonImage.name(for: date)

        GeometryReader { geometry in
            let diameter = geometry.size.width * 0.86

            VStack(spacing: 8) {
                Button(action: onMoonTap) {
                    Image(moonImageName)
                        .resizable()
                        .scaledToFit()
                        // Crop the black margin from the shared moon photos.
                        .scaleEffect(1.18)
                        .frame(maxWidth: diameter, maxHeight: diameter)
                        .clipShape(.circle)
                        .grayscale(1)
                        .shadow(color: .white.opacity(0.25), radius: 75)
                        // Last so opacity/shadow don't flatten it into an isolated layer.
                        .blendMode(.plusLighter)
                        // Keep frames stable independently of text animations.
                        .transaction { $0.animation = nil }
                        .contentShape(.circle)
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Moon Phase")
                .accessibilityValue(phaseName)

                VStack(spacing: 0) {
                    ZStack {
                        Text(phaseName)
                            .id(phaseName)
                            .transition(.blurReplace)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .animation(.smooth, value: phaseName)

                    Text(dateLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .contentTransition(.numericText())
                }
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
                .scenePadding(.navigationBar, edges: .horizontal)
                .accessibilityElement(children: .combine)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Use the former city-title row, as the Daylight ring does.
        .padding(.top, -20)
    }
}

enum CityMoonImage {
    // Match the iOS moon details: 118 frames across one lunar cycle.
    static func name(for date: Date) -> String {
        let age = MoonAstronomy.snapshot(for: date).ageDays
        let index = Int((age / MoonAstronomy.synodicMonthDays * 118).rounded()) % 118
        return String(format: "moon_scrub_%03d", index)
    }
}
