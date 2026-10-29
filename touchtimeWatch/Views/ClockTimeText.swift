//
//  ClockTimeText.swift
//  touchtimeWatch
//

import CoreText
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
    /// Whether the first digit's ink, rather than its box, starts at the
    /// leading edge, in line with text above or below. Every digit's box is
    /// as wide as the widest, so a 1 otherwise starts well in from the edge.
    var alignsLeadingInk = false

    @ScaledMetric(relativeTo: .largeTitle) private var largeDigitsSize: CGFloat = 40
    /// The watch's region settings, 24-Hour Time included.
    @Environment(\.locale) private var locale
    @Environment(\.fontResolutionContext) private var fontResolutionContext

    var body: some View {
        let time = WatchTimeFormat.time(date, in: timeZone, hourCycle: locale.hourCycle)
        let inkInset = alignsLeadingInk ? leadingInkInset(of: time.digits) : 0
        Text(time.digits)
            .font(font)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText())
            // A share of the width, as the digits can shrink to fit
            .visualEffect { content, geometry in
                content.offset(x: -inkInset * geometry.size.width)
            }
            .accessibilityLabel([time.digits, time.period].compactMap { $0 }.joined(separator: " "))
    }

    private var font: Font {
        switch size {
        case .large: .system(size: largeDigitsSize, design: .rounded).monospacedDigit()
        case .small: .system(.caption2, design: .rounded, weight: .medium).monospacedDigit()
        }
    }

    /// How far in from the leading edge the ink of `digits` starts, as a share
    /// of their width.
    private func leadingInkInset(of digits: String) -> CGFloat {
        let ctFont = font.resolve(in: fontResolutionContext).ctFont
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: digits, attributes: [.font: ctFont]))
        let width = CTLineGetBoundsWithOptions(line, []).width
        guard width > 0 else { return 0 }
        return CTLineGetBoundsWithOptions(line, .useGlyphPathBounds).minX / width
    }
}
