//
//  ScrollTimeBar.swift
//  touchtimeWatch
//

import SwiftUI

/// The iPhone app's Scroll Time bar: slid sideways, it moves every clock's
/// time a quarter hour at a time.
struct ScrollTimeBar: View {
    /// The time every clock shows in place of now, or nil for now.
    @Binding var adjustedDate: Date?
    /// The slide under way, or nil while the bar is at rest.
    @Binding var slide: ScrollTimeSlide?
    let now: Date

    /// How far a slide moves the time a quarter hour.
    private static let pointsPerQuarterHour: CGFloat = 6
    private static let quarterHour: TimeInterval = 15 * 60
    /// The bar's height, which the round button above it matches.
    fileprivate static let height: CGFloat = 40

    var body: some View {
        let isAdjusted = adjustedDate != nil

        HStack {
            Image(systemName: "chevron.left")
                .fontWeight(.semibold)
                .foregroundStyle(isAdjusted ? .primary : .tertiary)

            Spacer(minLength: 4)

            label
                .fontWeight(.medium)

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .fontWeight(.semibold)
                .foregroundStyle(isAdjusted ? .primary : .tertiary)
        }
        .font(.footnote)
        .animation(.smooth, value: adjustedDate)
        .padding(.horizontal, 14)
        .frame(height: Self.height)
        .contentShape(.capsule)
        .glassEffect(.regular.interactive(), in: .capsule)
        .gesture(slideGesture)
        .sensoryFeedback(.selection, trigger: adjustedDate) { _, _ in slide != nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Adjust Time")
        .accessibilityValue(adjustedDate.map { Self.offset(from: now, to: $0) } ?? String(localized: "Current Time"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                adjustedDate = Self.quarterHour(1, from: adjustedDate ?? now)
            case .decrement:
                adjustedDate = Self.quarterHour(-1, from: adjustedDate ?? now)
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder
    private var label: some View {
        if let adjustedDate {
            Text(Self.offset(from: now, to: adjustedDate))
                .monospacedDigit()
                .contentTransition(.numericText())
                .transition(.blurReplace)
        } else {
            Text("Slide to Adjust")
                .foregroundStyle(.secondary)
                .transition(.blurReplace)
        }
    }

    private var slideGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if slide == nil {
                    slide = ScrollTimeSlide(start: adjustedDate)
                }
                let start = slide?.start
                let quarters = Int((value.translation.width / Self.pointsPerQuarterHour).rounded(.towardZero))
                let date = quarters == 0 ? start : Self.quarterHour(quarters, from: start ?? now)
                if date != adjustedDate {
                    adjustedDate = date
                }
            }
            .onEnded { _ in
                withAnimation(.smooth) {
                    slide = nil
                }
            }
    }

    /// The quarter hour `quarters` quarter hours from `date`, counting from
    /// the quarter hour under way.
    private static func quarterHour(_ quarters: Int, from date: Date) -> Date {
        // Every time zone is a whole number of quarter hours from UTC, so
        // quarter hours start at the same moments on every clock
        let start = (date.timeIntervalSinceReferenceDate / quarterHour).rounded(.down) * quarterHour
        // Going back, the start of the quarter hour under way is the first stop
        let steps = quarters < 0 && start < date.timeIntervalSinceReferenceDate ? quarters + 1 : quarters
        return Date(timeIntervalSinceReferenceDate: start + TimeInterval(steps) * quarterHour)
    }

    /// How far `date` is from `now`, as the iPhone app shows it: "+2h 15m",
    /// "-45m".
    private static func offset(from now: Date, to date: Date) -> String {
        let totalMinutes = Int(abs(date.timeIntervalSince(now)) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let sign = date < now ? "-" : "+"
        if hours > 0 {
            return sign + String(format: String(localized: "%dh %02dm"), hours, minutes)
        }
        return sign + String(format: String(localized: "%02dm"), minutes)
    }
}

/// A slide under way on the Scroll Time bar.
struct ScrollTimeSlide {
    /// The time the clocks showed as it began, or nil for now.
    let start: Date?
}

/// The button above the Scroll Time bar that brings the clocks back to now.
struct ScrollTimeResetButton: View {
    /// The time every clock shows in place of now, or nil for now.
    @Binding var adjustedDate: Date?

    /// How far above the bar the button reaches, the gap between them
    /// included.
    static let reach = ScrollTimeBar.height + spacing
    private static let spacing: CGFloat = 6

    var body: some View {
        Button {
            withAnimation(.smooth) {
                adjustedDate = nil
            }
        } label: {
            Label("Current Time", systemImage: "xmark")
                .labelStyle(.iconOnly)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: ScrollTimeBar.height, height: ScrollTimeBar.height)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .padding(.bottom, Self.spacing)
    }
}
