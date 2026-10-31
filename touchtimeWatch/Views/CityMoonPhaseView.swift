//
//  CityMoonPhaseView.swift
//  touchtimeWatch
//

import SwiftUI

/// The moon at the displayed instant, with its phase and the city's date.
struct CityMoonPhaseView: View {
    let date: Date
    let timeZone: TimeZone

    @Environment(\.locale) private var locale

    // Match the iOS moon details: 118 frames, about six hours of moon age apart.
    private static let scrubFrameCount = 118
    private static let synodicMonthDays = 29.530589

    private var phase: MoonPhase {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return MoonDay(containing: date, calendar: calendar).phase
    }

    private var imageName: String {
        let age = MoonAstronomy.snapshot(for: date).ageDays
        let steps = age / Self.synodicMonthDays * Double(Self.scrubFrameCount)
        let index = Int(steps.rounded()) % Self.scrubFrameCount
        return String(format: "moon_scrub_%03d", index)
    }

    var body: some View {
        let phaseName = phase.localizedName
        let moonImageName = imageName

        GeometryReader { geometry in
            let diameter = geometry.size.width * 0.72

            VStack(spacing: 8) {
                Image(moonImageName)
                    .resizable()
                    .scaledToFit()
                    // Crop the black margin from the shared moon photos.
                    .scaleEffect(1.18)
                    .frame(maxWidth: diameter, maxHeight: diameter)
                    .clipShape(.circle)
                    .grayscale(1)
                    // Keep the image's identity and brightness stable while
                    // the Crown updates frames, independently of text animations.
                    .transaction { $0.animation = nil }
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    ZStack {
                        Text(phaseName)
                            .id(phaseName)
                            .transition(.blurReplace)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .animation(.smooth, value: phaseName)

                    Text(date, format: Date.FormatStyle(
                        date: .abbreviated,
                        time: .omitted,
                        locale: locale,
                        timeZone: timeZone
                    ))
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
    }
}
