//
//  ClockTimeText.swift
//  touchtimeWatch
//

import SwiftUI

/// A clock's time in rounded digits, in the watch's 12- or 24-hour time.
/// AM/PM stays off the screen, but VoiceOver still reads it.
struct ClockTimeText: View {
    enum Size {
        /// A clock's main time.
        case large
        /// A time beside a clock, like its sunrise.
        case small
    }

    let date: Date
    let timeZone: TimeZone
    var size: Size = .large

    @ScaledMetric(relativeTo: .largeTitle) private var largeDigitsSize: CGFloat = 34
    /// The watch's region settings, 24-Hour Time included.
    @Environment(\.locale) private var locale

    var body: some View {
        let time = WatchTimeFormat.time(date, in: timeZone, hourCycle: locale.hourCycle)
        Text(time.digits)
            .font(font)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText())
            .accessibilityLabel([time.digits, time.period].compactMap { $0 }.joined(separator: " "))
    }

    private var font: Font {
        switch size {
        case .large: .system(size: largeDigitsSize, design: .rounded).monospacedDigit()
        case .small: .system(.caption2, design: .rounded, weight: .medium).monospacedDigit()
        }
    }
}
