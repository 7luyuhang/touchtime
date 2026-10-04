//
//  LiveActivityComponents.swift
//  touchtimeWidgetExtension
//
//  Pieces shared by the timer and stopwatch Live Activities: the round
//  Dynamic Island buttons, the live digits, and the Lock Screen card that
//  copies the timer / stopwatch cards at the top of Home.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Dynamic Island Button

/// A round Dynamic Island button laid out like the Clock app's, in Touch
/// Time's colors: white with a black glyph for the main action, translucent
/// with a white glyph for the other one.
struct IslandCircleButton<Intent: LiveActivityIntent>: View {
    enum Prominence {
        case primary
        case secondary
    }

    let intent: Intent
    let systemImage: String
    let prominence: Prominence
    let accessibilityLabel: LocalizedStringKey

    var body: some View {
        Button(intent: intent) {
            ZStack {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(prominence == .primary ? Color.black : Color.white)
                    .id(systemImage)
                    .transition(.scale.combined(with: .opacity))
            }
            .frame(width: 50, height: 50)
            .animation(.spring(duration: 0.25), value: systemImage)
            .background(
                prominence == .primary ? Color.white : Color.white.opacity(0.18),
                in: Circle()
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

// MARK: - Live Digits

/// What is left on the timer, counting down live while it runs.
struct TimerDigits: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        PlaceholderSizedDigits(widthTemplate: widthTemplate) {
            if let endDate = state.endDate {
                Text(.currentDate, format: .timer(countingDownIn: state.countdownStart(endingAt: endDate)..<endDate))
            } else {
                Text(pausedText)
            }
        }
    }

    /// The paused time in the same format the running countdown uses.
    private var pausedText: AttributedString {
        let pausedAt = Date(timeIntervalSinceReferenceDate: 0)
        let endDate = pausedAt.addingTimeInterval(TimeInterval(state.pausedRemainingSeconds))
        let format = SystemFormatStyle.Timer(countingDownIn: state.countdownStart(endingAt: endDate)..<endDate)
        return format.format(pausedAt)
    }

    /// As wide as the countdown at its longest.
    private var widthTemplate: String {
        state.configuredSeconds >= 10 * 60 ? "00:00" : "0:00"
    }
}

/// The stopwatch time, counting up live while it runs.
struct StopwatchDigits: View {
    let state: StopwatchActivityAttributes.ContentState
    /// `.milliseconds(10)` adds hundredths of a second, which the system
    /// drops by itself while the screen is dimmed.
    let maxPrecision: Duration

    var body: some View {
        PlaceholderSizedDigits(widthTemplate: widthTemplate) {
            if state.isRunning {
                Text(.currentDate, format: .stopwatch(startingAt: state.virtualStartDate, maxPrecision: maxPrecision))
            } else {
                Text(stoppedText)
            }
        }
    }

    /// The stopped time in the same format the running stopwatch uses.
    private var stoppedText: AttributedString {
        let startDate = Date(timeIntervalSinceReferenceDate: 0)
        let format = SystemFormatStyle.Stopwatch(startingAt: startDate, maxPrecision: maxPrecision)
        return format.format(startDate.addingTimeInterval(state.accumulatedSeconds))
    }

    /// As wide as the digits are now: hours show up after the first hour.
    private var widthTemplate: String {
        let elapsed = state.isRunning ? Date.now.timeIntervalSince(state.virtualStartDate) : state.accumulatedSeconds
        let wholeSeconds = elapsed >= 60 * 60 ? "0:00:00" : "00:00"
        return maxPrecision < .seconds(1) ? wholeSeconds + ".00" : wholeSeconds
    }
}

/// Lays live digits out at the width of a placeholder of the same shape,
/// against the trailing edge. Auto-updating text claims more width than it
/// draws, which leaves a gap after the digits and crowds what sits beside them.
private struct PlaceholderSizedDigits<Digits: View>: View {
    let widthTemplate: String
    @ViewBuilder let digits: Digits

    var body: some View {
        Text(widthTemplate)
            .hidden()
            .overlay(alignment: .trailing) {
                digits
                    .multilineTextAlignment(.trailing)
            }
            .lineLimit(1)
    }
}

// MARK: - Timer Progress Ring

/// The share of the timer still left, emptying as it counts down.
struct TimerProgressRing: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        Group {
            if let endDate = state.endDate {
                ProgressView(timerInterval: state.countdownStart(endingAt: endDate)...endDate, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            } else {
                ProgressView(value: state.pausedRemainingFraction)
            }
        }
        .progressViewStyle(.circular)
        .tint(.white)
    }
}

// MARK: - Lock Screen Card

/// The timer / stopwatch card from the top of Home, for the Lock Screen: a
/// clear glass card straight on the wallpaper, with the play / pause button
/// in the middle.
struct LockScreenCard<Intent: LiveActivityIntent, Content: View>: View {
    let playPauseIntent: Intent
    let isRunning: Bool
    let playPauseAccessibilityLabel: LocalizedStringKey
    @ViewBuilder let content: Content

    private static var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
    }

    private var playPauseSymbol: String {
        isRunning ? "pause.fill" : "play.fill"
    }

    var body: some View {
        ZStack {
            content
                .frame(minHeight: 64)

            Button(intent: playPauseIntent) {
                ZStack {
                    Image(systemName: playPauseSymbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .id(playPauseSymbol)
                        .transition(.scale.combined(with: .opacity))
                }
                .frame(width: 64, height: 64)
                .animation(.spring(duration: 0.25), value: playPauseSymbol)
                .background(Color.white.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(playPauseAccessibilityLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            Self.cardShape
                .fill(.clear)
                .glassEffect(.clear, in: Self.cardShape)
                .overlay {
                    Self.cardShape
                        .fill(LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .opacity(0.75)
                }
        }
        .environment(\.colorScheme, .dark)
    }
}

/// The top row of a Lock Screen card: the symbol on the left, a detail
/// such as the configured duration or the lap count on the right.
struct LockScreenCardHeader: View {
    let systemImage: String
    let detail: String

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)

            Spacer()

            if !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .monospacedDigit()
            }
        }
    }
}

/// The bottom row of a Lock Screen card: the title on the left, the large
/// digits on the right.
struct LockScreenCardTitleRow<Digits: View>: View {
    let title: String
    @ViewBuilder let digits: Digits

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 120, alignment: .leading)

            Spacer()

            digits
                .font(.system(size: 36))
                .fontWeight(.light)
                .fontDesign(.rounded)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: 120, alignment: .trailing)
        }
        .padding(.bottom, -4)
    }
}

// MARK: - Dynamic Island Title And Digits

/// The trailing side of the expanded Dynamic Island: a small title above
/// the large digits, like the Clock app's timer.
struct IslandTitleAndDigits<Digits: View>: View {
    let title: String
    @ViewBuilder let digits: Digits

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.25), value: title)
                .padding(.trailing, 4)

            digits
                .font(.system(size: 28))
                .fontWeight(.regular)
                .fontDesign(.rounded)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.50)
        }
        .foregroundStyle(.white)
    }
}
