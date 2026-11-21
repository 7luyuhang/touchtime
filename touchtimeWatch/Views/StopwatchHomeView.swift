//
//  StopwatchHomeView.swift
//  touchtimeWatch
//
//  The stopwatch, in the list's place once chosen, on the timer's ring, with
//  hands as the system's Stopwatch has them on its analogue face: an orange
//  one sweeping round with the time on the stopwatch, and from the first lap
//  a blue one with the lap's, back at the top for each new lap. The minutes
//  go round a small dial above the middle, and the time shows in figures
//  below it, as on that face. The laps are listed on a page to its right.
//

import SwiftUI

struct StopwatchHomeView: View {
    @Environment(WatchStopwatchStore.self) private var stopwatch
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    /// Whole turns the second hand, and the minutes' hand, have gone on round
    /// to the top on reset, rather than back, where that's the nearer way, as
    /// a chronograph's hands fly back.
    @State private var secondTurns: Double = 0
    @State private var minuteTurns: Double = 0

    var body: some View {
        TimelineView(StopwatchSchedule(zeroDate: stopwatch.zeroDate)) { context in
            let phase = stopwatch.phase(at: context.date)

            TabView {
                dial(at: context.date, phase: phase)
                StopwatchLapsList(laps: stopwatch.laps)
            }
            .tabViewStyle(.page)
            .toolbar {
                controls(for: phase)
            }
            .sensoryFeedback(trigger: phase) { _, phase in
                switch phase {
                case .running: .start
                case .idle, .stopped: .stop
                case .finished: .success
                }
            }
        }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: stopwatch.laps.count) { oldCount, newCount in
            newCount > oldCount
        }
    }

    /// The ring with the minutes' dial, the figures and the hands in it, at
    /// `date`, and every frame after that while it runs.
    private func dial(at date: Date, phase: WatchStopwatchStore.Phase) -> some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let layout = AnalogueDialLayout(
                    diameter: max(0, min(geometry.size.width - 16, geometry.size.height))
                )

                ZStack {
                    SecondsDial(layout: layout)
                        .accessibilityHidden(true)
                    MinuteDial(layout: layout)
                        .accessibilityHidden(true)

                    // Every frame while it runs, but not with the wrist
                    // down, when the minutes turning over are enough.
                    TimelineView(.animation(paused: phase != .running || isLuminanceReduced)) { frame in
                        face(at: max(frame.date, date), phase: phase, layout: layout)
                    }
                }
                .frame(width: layout.diameter, height: layout.diameter)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }

            // A line's room under the circle, as the timer leaves, for the
            // two rings to be as big as each other.
            Text(verbatim: " ")
                .font(.subheadline)
                .hidden()
        }
        // The circle's narrow top fits between the toolbar controls, as the
        // timer's does.
        .padding(.top, -20)
        .padding(.bottom, 8)
        .ignoresSafeArea(edges: .bottom)
    }

    /// The figures and the hands at `date`.
    private func face(at date: Date, phase: WatchStopwatchStore.Phase, layout: AnalogueDialLayout) -> some View {
        let elapsed = stopwatch.elapsed(at: date)
        let lapElapsed = stopwatch.laps.isEmpty ? nil : stopwatch.currentLapElapsed(at: date)
        // With the wrist down while it runs, they'd only turn over once a
        // minute.
        let showsSeconds = !(isLuminanceReduced && phase == .running)

        return ZStack {
            figures(elapsed: elapsed, lapElapsed: lapElapsed, showsSeconds: showsSeconds, isRunning: phase == .running, layout: layout)

            MinuteHand(layout: layout, angle: (minuteTurns * 30 + (elapsed / 60).rounded(.down)) * 12)
                .accessibilityHidden(true)

            StopwatchHands(
                layout: layout,
                angle: secondTurns * 360 + Self.secondAngle(of: elapsed),
                lapAngle: lapElapsed.map { Self.secondAngle(of: $0) },
                showsSecondHands: showsSeconds
            )
            .accessibilityHidden(true)
        }
    }

    /// The time on the stopwatch in figures, as far below the middle as the
    /// minutes' dial is above it.
    private func figures(
        elapsed: TimeInterval,
        lapElapsed: TimeInterval?,
        showsSeconds: Bool,
        isRunning: Bool,
        layout: AnalogueDialLayout
    ) -> some View {
        Text(verbatim: WatchStopwatchStore.figures(for: elapsed, showsSeconds: showsSeconds))
            .font(Self.digitsFont(size: layout.figuresFontSize))
            .foregroundStyle(.white)
            // Straight to zero as the hands fly back, rather than cross-fading
            .contentTransition(.identity)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: layout.figuresWidth)
            .position(x: layout.center.x, y: layout.center.y + layout.figuresOffset)
            .accessibilityLabel(Self.spokenTime(elapsed))
            .accessibilityAddTraits(isRunning ? .updatesFrequently : [])
            // The lap's time too, which only the lap hand shows, hidden from
            // VoiceOver
            .accessibilityCustomContent(
                AccessibilityCustomContentKey(Text("Lap \(stopwatch.laps.count + 1)"), id: "lap"),
                lapElapsed.map { Text(Self.spokenTime($0)) },
                importance: .high
            )
    }

    /// Lap while it runs, or Reset once it's stopped, across from Start or
    /// Stop in the corner where the timer's Start is.
    @ToolbarContentBuilder
    private func controls(for phase: WatchStopwatchStore.Phase) -> some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            let showsReset = switch phase {
            case .idle, .running: false
            case .stopped, .finished: true
            }
            // One button turning from one into the other, rather than one in
            // the other's place, which the animated reset would fade in over
            // the pressed Reset, cutting its glass off
            Button(showsReset ? "Reset" : "Lap", systemImage: showsReset ? "arrow.counterclockwise" : "stopwatch") {
                if showsReset {
                    reset()
                } else {
                    stopwatch.lap()
                }
            }
            .tint(phase == .running ? .white : nil)
            // The system leaves a tinted button's glyph white
            .foregroundStyle(phase == .running ? .black : Color.primary)
            .disabled(phase == .idle)
            Spacer()
            if phase == .running {
                Button("Stop", systemImage: "stop.fill") {
                    stopwatch.stop()
                }
                .tint(.red)
            } else {
                Button("Start", systemImage: "play.fill") {
                    stopwatch.start()
                }
                .tint(phase == .finished ? nil : .green)
                .disabled(phase == .finished)
            }
        }
    }

    /// Back to zero, the second hand and the minutes' hand going to the top
    /// the nearer way round rather than unwinding.
    private func reset() {
        let elapsed = stopwatch.elapsed(at: .now)
        withAnimation(.smooth) {
            if Self.secondAngle(of: elapsed) > 180 {
                secondTurns += 1
            }
            minuteTurns += ((elapsed / 60).rounded(.down) / 30).rounded()
            stopwatch.reset()
        }
    }

    private static func digitsFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded).monospacedDigit()
    }

    /// `interval`'s seconds round the ring, in degrees clockwise from the top.
    private static func secondAngle(of interval: TimeInterval) -> Double {
        interval.truncatingRemainder(dividingBy: 60) * 6
    }

    private static func spokenTime(_ interval: TimeInterval) -> String {
        Duration.milliseconds(Int64(interval * 1000)).formatted(
            .units(allowed: [.hours, .minutes, .seconds], width: .wide, fractionalPart: .show(length: 2))
        )
    }
}

private extension AnalogueDialLayout {
    /// The minutes' dial, clear of the ring above it and of the second hands'
    /// cap below.
    var minuteDialCenter: CGPoint { CGPoint(x: center.x, y: center.y - innerRadius * 0.47) }
    var minuteDialRadius: CGFloat { innerRadius * 0.32 }
    var minuteDialTickLength: CGFloat { minuteDialRadius * 0.14 }
    var minuteDialMajorTickLength: CGFloat { minuteDialRadius * 0.26 }
    var minuteDialTickWidth: CGFloat { tickWidth * 0.75 }
    var minuteHandCapDiameter: CGFloat { secondHandWidth * 3 }
    /// The time on the stopwatch.
    var figuresOffset: CGFloat { innerRadius * 0.47 }
    var figuresFontSize: CGFloat { innerRadius * 0.3 }
    var figuresWidth: CGFloat { innerRadius * 1.5 }
    /// The second hands' cap, a ring as thick as their bars round its hole.
    var stopwatchCapDiameter: CGFloat { radius * 0.08 }
    var stopwatchHoleDiameter: CGFloat { max(0, stopwatchCapDiameter - secondHandWidth * 2) }
}

/// The second hands as the system's Stopwatch has them on its analogue face:
/// an orange one with the time on the stopwatch over a blue one with the
/// lap's, each a thin bar from a short tail behind the middle out to the
/// ticks, on a round cap open to the black in its middle.
private struct StopwatchHands: View {
    let layout: AnalogueDialLayout
    /// In degrees clockwise from the top, counting whole turns.
    let angle: Double
    /// The lap hand's, or nil before the first lap.
    let lapAngle: Double?
    let showsSecondHands: Bool

    var body: some View {
        ZStack {
            // In at once with the first lap, and back at the top at once for
            // each lap after it, but blurred out in its own place on reset
            if showsSecondHands, let lapAngle {
                hand(.blue)
                    .rotationEffect(.degrees(lapAngle))
                    .transition(.blurReplace)
            }

            if showsSecondHands {
                hand(.orange)
                    .rotationEffect(.degrees(angle))
                    .transition(.blurReplace)
            }

            Circle()
                .frame(width: layout.stopwatchHoleDiameter, height: layout.stopwatchHoleDiameter)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .frame(width: layout.diameter, height: layout.diameter)
        .animation(.smooth, value: showsSecondHands)
    }

    private func hand(_ color: Color) -> some View {
        ZStack {
            RadialBar(start: -layout.secondHandTail, end: layout.secondHandLength, width: layout.secondHandWidth)
                .fill(color)
            Circle()
                .fill(color)
                .frame(width: layout.stopwatchCapDiameter, height: layout.stopwatchCapDiameter)
        }
    }
}

/// The small dial above the middle that the minutes go round, as on the
/// system Stopwatch's analogue face: half an hour a turn, with a tick for
/// each minute, every fifth one longer, as bright as the ring's.
private struct MinuteDial: View {
    let layout: AnalogueDialLayout

    var body: some View {
        ZStack {
            ForEach(0..<30, id: \.self) { minute in
                RadialBar(
                    start: layout.minuteDialRadius - (minute % 5 == 0 ? layout.minuteDialMajorTickLength : layout.minuteDialTickLength),
                    end: layout.minuteDialRadius,
                    width: layout.minuteDialTickWidth
                )
                .fill(.white.opacity(minute % 5 == 0 ? 1 : 0.375))
                .rotationEffect(.degrees(Double(minute) * 12))
            }
        }
        .frame(width: layout.minuteDialRadius * 2, height: layout.minuteDialRadius * 2)
        .position(layout.minuteDialCenter)
    }
}

/// The minutes' hand, in the second hand's orange, stepping on a tick as
/// that comes round to the top.
private struct MinuteHand: View {
    let layout: AnalogueDialLayout
    /// In degrees clockwise from the top, counting whole turns.
    let angle: Double

    var body: some View {
        ZStack {
            RadialBar(start: 0, end: layout.minuteDialRadius, width: layout.secondHandWidth)
                .fill(.orange)
            Circle()
                .fill(.orange)
                .frame(width: layout.minuteHandCapDiameter, height: layout.minuteHandCapDiameter)
        }
        .frame(width: layout.minuteDialRadius * 2, height: layout.minuteDialRadius * 2)
        .rotationEffect(.degrees(angle))
        .animation(.smooth(duration: 0.3), value: angle)
        .position(layout.minuteDialCenter)
    }
}

/// When the minutes on the stopwatch turn over while it runs, for its
/// figures and its minutes' hand with the wrist down, up to its limit,
/// where it stops. Just the once while it's stopped.
private nonisolated struct StopwatchSchedule: TimelineSchedule {
    /// When the stopwatch would have read zero, had it run all along, or nil
    /// while it's stopped.
    let zeroDate: Date?

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> UnfoldFirstSequence<Date> {
        guard let zeroDate else {
            return sequence(first: startDate) { _ in nil }
        }
        // A second past the limit, as the view never updates for the last
        // date of a schedule, which would leave it running.
        let lastDate = zeroDate.addingTimeInterval(WatchStopwatchStore.maxElapsed + 1)
        return sequence(first: startDate) { date in
            guard date < lastDate else { return nil }
            let minutes = (date.timeIntervalSince(zeroDate) / 60).rounded(.down) + 1
            var turn = zeroDate.addingTimeInterval(minutes * 60)
            // However the seconds round
            if turn <= date {
                turn.addTimeInterval(60)
            }
            return min(turn, lastDate)
        }
    }
}

#Preview {
    NavigationStack {
        StopwatchHomeView()
    }
    .environment(WatchStopwatchStore())
}
