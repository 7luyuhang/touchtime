//
//  StopwatchLiveActivity.swift
//  touchtimeWidgetExtension
//
//  The Home stopwatch as a Live Activity. The Dynamic Island follows the
//  Clock app's stopwatch; the Lock Screen shows the stopwatch card from Home.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct StopwatchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StopwatchActivityAttributes.self) { context in
            StopwatchLockScreenView(title: context.attributes.title, state: context.state)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StopwatchIslandButtons(state: context.state)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    IslandTitleAndDigits(
                        title: context.state.lapsText.isEmpty ? context.attributes.title : context.state.lapsText
                    ) {
                        StopwatchDigits(state: context.state, maxPrecision: .milliseconds(10))
                    }
                }
            } compactLeading: {
                IslandCompactSymbol(systemImage: "stopwatch")
            } compactTrailing: {
                StopwatchDigits(state: context.state, maxPrecision: .seconds(1))
                    .font(.body.weight(.semibold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "stopwatch")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .keylineTint(.white)
        }
    }
}

/// Start / Stop and Lap / Reset, side by side like the Clock app's stopwatch.
private struct StopwatchIslandButtons: View {
    let state: StopwatchActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 10) {
            IslandCircleButton(
                intent: StopwatchPlayPauseIntent(),
                systemImage: state.isRunning ? "pause.fill" : "play.fill",
                prominence: .primary,
                accessibilityLabel: state.isRunning ? "Stop" : "Start"
            )

            IslandCircleButton(
                intent: StopwatchLapResetIntent(),
                systemImage: state.isRunning ? "stopwatch" : "arrow.counterclockwise",
                prominence: .secondary,
                accessibilityLabel: state.isRunning ? "Lap" : "Reset"
            )
        }
    }
}

private struct StopwatchLockScreenView: View {
    let title: String
    let state: StopwatchActivityAttributes.ContentState

    var body: some View {
        LockScreenCard(
            playPauseIntent: StopwatchPlayPauseIntent(),
            isRunning: state.isRunning,
            playPauseAccessibilityLabel: state.isRunning ? "Stop" : "Start"
        ) {
            VStack(alignment: .leading, spacing: 4) {
                LockScreenCardHeader(systemImage: "stopwatch", detail: state.lapsText)

                LockScreenCardTitleRow(title: title) {
                    StopwatchDigits(state: state, maxPrecision: .seconds(1))
                }
            }
        }
    }
}
