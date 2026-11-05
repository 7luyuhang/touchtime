//
//  ClockTimeText.swift
//  touchtimeWatch
//

import CoreText
import SwiftUI

/// A clock's time in rounded digits, in 12- or 24-hour time by the 24-Hour
/// Format setting. AM/PM stays off the screen, but VoiceOver still reads it.
struct ClockTimeText: View {
    enum Size {
        /// A clock's main time.
        case large
        /// A clock's time in the city list.
        case list
        /// A prominent time inside a chart or ring.
        case title
        /// A time in a full-width detail row.
        case medium
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
    @ScaledMetric(relativeTo: .largeTitle) private var listDigitsSize: CGFloat = 36
    @AppStorage(WatchTimeFormat.use24HourFormatKey) private var use24HourFormat = WatchTimeFormat.systemUses24HourFormat
    @Environment(\.fontResolutionContext) private var fontResolutionContext

    var body: some View {
        let time = WatchTimeFormat.time(date, in: timeZone, use24HourFormat: use24HourFormat)
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
        case .list: .system(size: listDigitsSize, design: .rounded).monospacedDigit()
        case .title: .system(.title3, design: .rounded, weight: .medium).monospacedDigit()
        case .medium: .system(.body, design: .rounded, weight: .medium).monospacedDigit()
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
