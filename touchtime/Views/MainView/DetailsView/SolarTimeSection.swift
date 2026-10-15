//
//  SolarTimeSection.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI

/// Sunrise and sunset, the length of the day, and the evening golden hour.
struct SolarTimeSection: View {
    let sunrise: Date?
    let sunset: Date?
    let goldenHourStart: Date?
    let goldenHourEnd: Date?
    let headerTopPadding: CGFloat
    let currentDate: Date
    let timeOffset: TimeInterval
    let dateFormat: DetailsDateFormat
    @Binding var showsDaylightSheet: Bool

    var body: some View {
        VStack(alignment: .leading){

            Text("Solar Time")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
                .padding(.horizontal, 32)
                .padding(.bottom, 4)
                .padding(.top, headerTopPadding)

            HStack(spacing: 8) {
                RiseSetTimeCard(symbolName: "sunrise.fill", time: sunrise, dateFormat: dateFormat)
                RiseSetTimeCard(symbolName: "sunset.fill", time: sunset, dateFormat: dateFormat)
            }
            .padding(.horizontal, 16)

            DaylightCard(sunrise: sunrise, sunset: sunset, showsDaylightSheet: $showsDaylightSheet)
                .padding(.horizontal, 16)

            if let goldenHourStart, let goldenHourEnd {
                GoldenHourCard(
                    start: goldenHourStart,
                    end: goldenHourEnd,
                    currentDate: currentDate,
                    timeOffset: timeOffset,
                    dateFormat: dateFormat
                )
                .padding(.horizontal, 16)
                .transition(.blurReplace().combined(with: .opacity))
            }
        }
    }
}
