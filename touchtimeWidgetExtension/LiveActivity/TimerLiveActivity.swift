//
//  TimerLiveActivity.swift
//  touchtimeWidgetExtension
//
//  The Home timer as a Live Activity. The Dynamic Island follows the Clock
//  app's timer; the Lock Screen shows the timer card from Home.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            TimerLockScreenView(state: context.state, isFinished: context.isStale)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TimerIslandButtons(state: context.state, isFinished: context.isStale)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    IslandTitleAndDigits(title: context.state.title) {
                        TimerDigits(state: context.state)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
            } compactTrailing: {
                TimerDigits(state: context.state)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            } minimal: {
                TimerProgressRing(state: context.state)
            }
            .keylineTint(.white)
        }
    }
}

/// Play / Pause and Cancel, side by side like the Clock app's timer.
private struct TimerIslandButtons: View {
    let state: TimerActivityAttributes.ContentState
    /// Past the end, until the app takes the activity down.
    let isFinished: Bool

    var body: some View {
        HStack(spacing: 10) {
            IslandCircleButton(
                intent: TimerPlayPauseIntent(),
                systemImage: TimerPlayPauseLabel.systemImage(for: state, isFinished: isFinished),
                prominence: .primary,
                accessibilityLabel: TimerPlayPauseLabel.accessibilityLabel(for: state, isFinished: isFinished)
            )

            IslandCircleButton(
                intent: TimerCancelIntent(),
                systemImage: "xmark",
                prominence: .secondary,
                accessibilityLabel: "Cancel"
            )
        }
    }
}

private struct TimerLockScreenView: View {
    let state: TimerActivityAttributes.ContentState
    let isFinished: Bool

    var body: some View {
        LockScreenCard(
            playPauseIntent: TimerPlayPauseIntent(),
            isRunning: state.isRunning && !isFinished,
            playPauseAccessibilityLabel: TimerPlayPauseLabel.accessibilityLabel(for: state, isFinished: isFinished)
        ) {
            VStack(alignment: .leading, spacing: 4) {
                LockScreenCardHeader(systemImage: "timer", detail: state.durationText)

                LockScreenCardTitleRow(title: state.title) {
                    TimerDigits(state: state)
                }
            }
        }
    }
}

/// The play / pause button reads Pause while counting down, Resume while
/// paused and Start once the timer has finished.
private enum TimerPlayPauseLabel {
    static func systemImage(for state: TimerActivityAttributes.ContentState, isFinished: Bool) -> String {
        state.isRunning && !isFinished ? "pause.fill" : "play.fill"
    }

    static func accessibilityLabel(for state: TimerActivityAttributes.ContentState, isFinished: Bool) -> LocalizedStringKey {
        if isFinished { return "Start" }
        return state.isRunning ? "Pause" : "Resume"
    }
}
