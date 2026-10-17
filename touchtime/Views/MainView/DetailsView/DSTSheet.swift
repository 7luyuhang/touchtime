//
//  DSTSheet.swift
//  touchtime
//
//  Created on 16/10/2026.
//

import SwiftUI
import UIKit

/// The next DST change: the city's clock now beside what it will read at
/// the same moment once the change is in, e.g. 20:00 and 19:00 (-1h).
/// Zooms out of the DST pill.
struct DSTSheet: View {
    let transitionDate: Date
    let isStart: Bool
    let timeOffset: TimeInterval
    let dateFormat: DetailsDateFormat

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    private static let minColumnGap: CGFloat = 16
    private static let maxDialSize: CGFloat = 150

    private var timeZone: TimeZone {
        TimeZone(identifier: dateFormat.timeZoneIdentifier) ?? .current
    }

    /// The city's offset from UTC once the change is in, in seconds
    private var offsetAfterChange: Int {
        timeZone.secondsFromGMT(for: transitionDate)
    }

    /// How far the clocks move, in seconds: negative when they go back
    private var offsetChange: Int {
        offsetAfterChange - timeZone.secondsFromGMT(for: transitionDate.addingTimeInterval(-1))
    }

    /// The change as the DST pill writes it, e.g. "-1h". Lord Howe Island's
    /// clocks move half an hour, which whole hours can't show.
    private var offsetChangeText: String {
        guard offsetChange.isMultiple(of: 3_600) else {
            let amount = Duration.seconds(abs(offsetChange))
                .formatted(.units(allowed: [.hours, .minutes], width: .narrow))
            return (offsetChange > 0 ? "+" : "-") + amount
        }
        let hours = offsetChange / 3_600
        return hours > 0
            ? String(format: String(localized: "+%d hours"), hours)
            : String(format: String(localized: "%d hours"), hours)
    }

    var body: some View {
        NavigationStack {
            clockComparison
                .frame(maxHeight: .infinity, alignment: .center)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            triggerHaptic()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }

                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text(isStart ? String(localized: "Daylight Saving Time Starts") : String(localized: "Daylight Saving Time Ends"))
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Text(offsetChangeText)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
        }
        .presentationDetents([.height(300)])
    }

    /// Two clocks side by side, each above its title.
    private var clockComparison: some View {
        VStack(spacing: 12) {
            TimelineView(.animation) { context in
                let date = context.date.addingTimeInterval(timeOffset)

                columns(
                    DSTClockDial(
                        date: date,
                        secondsFromGMT: timeZone.secondsFromGMT(for: date),
                        use24HourFormat: dateFormat.use24HourFormat
                    ),
                    DSTClockDial(
                        date: date,
                        secondsFromGMT: offsetAfterChange,
                        use24HourFormat: dateFormat.use24HourFormat,
                        hourHandShift: offsetChange
                    )
                )
            }

            columns(
                columnTitle(String(localized: "Current")),
                columnTitle(dateFormat.monthDayYear(transitionDate))
            )
        }
    }

    /// Two columns up to a dial wide, with the same gap at the edges as
    /// between them: the columns take their width first, and the spacers
    /// split what is left.
    private func columns(_ left: some View, _ right: some View) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: Self.minColumnGap)
            left
                .frame(maxWidth: Self.maxDialSize)
                .layoutPriority(1)
            Spacer(minLength: Self.minColumnGap)
            right
                .frame(maxWidth: Self.maxDialSize)
                .layoutPriority(1)
            Spacer(minLength: Self.minColumnGap)
        }
    }

    private func columnTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}
