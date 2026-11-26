//
//  RunningTips.swift
//  touchtimeWatch
//

import SwiftUI
import TipKit

/// The timer and the stopwatch while they run, side by side at the foot of
/// a list, each a tip with its time going on live. Tapped, one takes the
/// list's place, as when it's chosen from the list's corner.
struct RunningTips: View {
    @Environment(WatchTimerStore.self) private var timerStore
    @Environment(WatchStopwatchStore.self) private var stopwatch
    @AppStorage(HomeDisplay.storageKey) private var homeDisplay: HomeDisplay = .list
    /// The tips' width side by side, at their full size.
    @State private var tipsWidth: CGFloat = 0
    /// The width there's room for.
    @State private var width: CGFloat = .infinity

    var body: some View {
        TimelineView(RunningTipsSchedule(endDates: endDates)) { context in
            // The timeline's date is from its last update, which may be long
            // past by the time a run starts; ahead of now, it's for Always On.
            let date = max(context.date, .now)

            HStack(spacing: 6) {
                if let endDate = timerStore.endDate, endDate > date {
                    tip(TimerRunningTip(endDate: endDate, duration: timerStore.duration), opening: .timer)
                }
                if let zeroDate = stopwatch.zeroDate, stopwatch.phase(at: date) == .running {
                    tip(StopwatchRunningTip(zeroDate: zeroDate), opening: .stopwatch)
                }
            }
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { tipsWidth = $0 }
            // Both smaller alike where they wouldn't fit side by side, rather
            // than one's digits squeezed into the room the other leaves
            .scaleEffect(tipsWidth > width ? width / tipsWidth : 1, anchor: .bottom)
            // With both bounds, the room offered even as the tips overflow it
            .frame(minWidth: 0, maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        }
        // TipKit brings a tip in with an animation once it's ready, which on
        // a slow launch is only after the list shows. Animated, the tips would
        // rise into their places from where the empty row sat, below and to
        // the right of them. So they're placed in here, filling the room
        // around them, where nothing animates
        .frame(maxHeight: .infinity, alignment: .bottom)
        .transaction { $0.animation = nil }
    }

    /// When the timer runs down, and when the stopwatch stops at its limit.
    private var endDates: [Date] {
        [timerStore.endDate, stopwatch.zeroDate?.addingTimeInterval(WatchStopwatchStore.maxElapsed)].compactMap { $0 }
    }

    private func tip(_ tip: some Tip, opening display: HomeDisplay) -> some View {
        TipView(tip) { _ in
            homeDisplay = display
        }
        .tipViewStyle(RunningTipStyle())
        // On glass rather than a platter of its own: around the tip, as
        // within it the glass would be cut to the tip's bounds as it swells
        // when pressed, leaving only the text to grow
        .tipBackground(.clear)
        .glassEffect(.regular.interactive())
    }
}

/// Now, then as either runs out, for its tip to go then. Now first, as with
/// only dates ahead, the timeline would start on the first of them.
nonisolated struct RunningTipsSchedule: TimelineSchedule {
    let endDates: [Date]

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> [Date] {
        [startDate] + endDates.filter { $0 > startDate }.sorted()
    }
}

/// The timer's run, counting down to its end.
nonisolated struct TimerRunningTip: Tip {
    let endDate: Date
    /// The time the timer's set to, which the run counts down from.
    let duration: Int

    var title: Text {
        Text("Timer")
    }

    var message: Text? {
        Text(.currentDate, format: .timer(countingDownIn: endDate.addingTimeInterval(-TimeInterval(duration))..<endDate))
    }

    var image: Image? {
        Image(systemName: "timer")
    }

    /// The timer taking the list's place, as when it's chosen from the
    /// list's corner.
    var actions: [Action] {
        Action {
            Text("Timer")
        }
    }

    /// Shown for every run, whatever other tips have shown.
    var options: [any TipOption] {
        Tips.IgnoresDisplayFrequency(true)
    }
}

/// The stopwatch's run, counting on from zero.
nonisolated struct StopwatchRunningTip: Tip {
    /// When the stopwatch would have read zero, had it run all along.
    let zeroDate: Date

    var title: Text {
        Text("Stopwatch")
    }

    var message: Text? {
        Text(.currentDate, format: .stopwatch(startingAt: zeroDate, maxPrecision: .seconds(1)))
    }

    var image: Image? {
        Image(systemName: "stopwatch")
    }

    /// The stopwatch taking the list's place, as when it's chosen from the
    /// list's corner.
    var actions: [Action] {
        Action {
            Text("Stopwatch")
        }
    }

    /// Shown for every run, whatever other tips have shown.
    var options: [any TipOption] {
        Tips.IgnoresDisplayFrequency(true)
    }
}

/// A tip as a capsule, all of it the button for its action: its symbol,
/// standing for its title, then its message.
private struct RunningTipStyle: TipViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.actions.first?.handler()
        } label: {
            HStack(spacing: 4) {
                configuration.image?
                    .accessibilityLabel(configuration.title ?? Text(verbatim: ""))
                configuration.message?
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            // As tall as a tip in the default style
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
