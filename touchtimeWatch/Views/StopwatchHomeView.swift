//
//  StopwatchHomeView.swift
//  touchtimeWatch
//
//  The stopwatch, in the list's place once chosen, on the timer's ring, with
//  hands as the system's Stopwatch has them on its analogue face: an orange
//  one sweeping round with the time on the stopwatch, and from the first lap
//  a blue one with the lap's, back at the top for each new lap. The minutes
//  go round a small dial above the middle, and the time shows in figures
//  below it, as on that face. Tapped, the figures grow in the ring's place,
//  under the minutes' dial, the seconds' and the tenths' in a row, as the
//  system's Stopwatch has its three dials. The laps are listed on a page to
//  its right.
//

import SwiftUI
import WatchKit

struct StopwatchHomeView: View {
    /// The ring's page, and the laps' to its right.
    private enum Page {
        case dial
        case laps
    }

    @Environment(WatchStopwatchStore.self) private var stopwatch
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    /// Whole turns the second hand, the minutes' hand and the tenths' hand
    /// have gone on round to the top on reset, rather than back, where that's
    /// the nearer way, as a chronograph's hands fly back.
    @State private var secondTurns: Double = 0
    @State private var minuteTurns: Double = 0
    @State private var tenthTurns: Double = 0
    /// The page shown, kept here, as the page view left to itself goes back
    /// to the ring when the first lap takes No Laps' place.
    @State private var page = Page.dial
    /// Whether the figures show large in the ring's place, under the small
    /// dials in a row, from a tap on them.
    @State private var isDigital = false

    var body: some View {
        TimelineView(StopwatchSchedule(zeroDate: stopwatch.zeroDate)) { context in
            let phase = stopwatch.phase(at: context.date)

            TabView(selection: $page) {
                dial(at: context.date, phase: phase)
                    .tag(Page.dial)
                StopwatchLapsList(laps: stopwatch.laps)
                    .tag(Page.laps)
            }
            .tabViewStyle(.page)
            .toolbar {
                controls(at: context.date, phase: phase)
            }
            .sensoryFeedback(trigger: phase) { _, phase in
                switch phase {
                case .running: .start
                case .stopped: .stop
                case .finished: .success
                // Back to zero on reset, which goes without a sound
                case .idle: nil
                }
            }
        }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: stopwatch.laps.count) { oldCount, newCount in
            newCount > oldCount
        }
    }

    /// The ring with the minutes' dial, the figures and the hands in it, or
    /// the figures large under the small dials in a row, at `date`, and
    /// every frame after that while it runs.
    private func dial(at date: Date, phase: WatchStopwatchStore.Phase) -> some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let layout = AnalogueDialLayout(
                    diameter: max(0, min(geometry.size.width - 16, geometry.size.height))
                )

                ZStack {
                    SecondsDial(layout: layout, countsToSixty: true)
                        .accessibilityHidden(true)
                        .blurredOut(isDigital)

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
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isDigital)
    }

    /// The figures, the small dials and the hands at `date`.
    private func face(at date: Date, phase: WatchStopwatchStore.Phase, layout: AnalogueDialLayout) -> some View {
        let elapsed = stopwatch.elapsed(at: date)
        let lapElapsed = stopwatch.laps.isEmpty ? nil : stopwatch.currentLapElapsed(at: date)
        // With the wrist down while it runs, they'd only turn over once a
        // minute.
        let showsSeconds = !(isLuminanceReduced && phase == .running)
        let secondAngle = secondTurns * 360 + Self.secondAngle(of: elapsed)
        let lapAngle = lapElapsed.map { Self.secondAngle(of: $0) }

        return ZStack {
            figures(elapsed: elapsed, lapElapsed: lapElapsed, showsSeconds: showsSeconds, isRunning: phase == .running, layout: layout)

            SmallDials(
                layout: layout,
                isInRow: isDigital,
                minuteAngle: (minuteTurns * 30 + (elapsed / 60).rounded(.down)) * 12,
                secondAngle: secondAngle,
                tenthAngle: tenthTurns * 360 + Self.tenthAngle(of: elapsed),
                lapAngle: lapAngle,
                showsSecondHands: showsSeconds
            )
            .accessibilityHidden(true)

            StopwatchHands(layout: layout, angle: secondAngle, lapAngle: lapAngle, showsSecondHands: showsSeconds)
                .accessibilityHidden(true)
                // Taps on the figures under them reach them.
                .allowsHitTesting(false)
                .blurredOut(isDigital)
        }
    }

    /// The time on the stopwatch in figures, as far below the middle as the
    /// minutes' dial is above it, or large under the small dials in a row.
    private func figures(
        elapsed: TimeInterval,
        lapElapsed: TimeInterval?,
        showsSeconds: Bool,
        isRunning: Bool,
        layout: AnalogueDialLayout
    ) -> some View {
        let figures = WatchStopwatchStore.figures(for: elapsed, showsSeconds: showsSeconds)

        return Text(verbatim: figures)
            .font(Self.digitsFont(size: layout.largeFiguresFontSize))
            .foregroundStyle(.white)
            // Straight to the new figures: to zero as the hands fly back,
            // rather than cross-fading, and with the seconds back as the
            // wrist comes up, rather than sliding over from the side as they
            // widen
            .animation(nil, value: figures)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: layout.largeFiguresWidth)
            .contentShape(.rect)
            .onTapGesture {
                // Back to the ring once the seconds' and the tenths' dials
                // are back under the minutes'
                withAnimation(isDigital ? .smooth.delay(0.15) : .smooth) {
                    isDigital.toggle()
                }
            }
            // Shrunk on the ring rather than set smaller, so that it grows
            // into the large figures in the same font
            .scaleEffect(isDigital ? 1 : layout.figuresScale)
            .position(x: layout.center.x, y: layout.center.y + (isDigital ? layout.largeFiguresOffset : layout.figuresOffset))
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

    /// The time on the stopwatch in figures on glass on the laps' page, at
    /// `date`, and every frame after that while it runs, as the ring has
    /// them.
    private func figuresCapsule(at date: Date, phase: WatchStopwatchStore.Phase) -> some View {
        // Its room, held on the ring's page too, as the toolbar pops items
        // that come and go, and keeps an item the size it first was. Sized by
        // the figures before the first hour, for it not to change as the
        // hours come, theirs made smaller to fit
        Text(verbatim: "00:00.00")
            .hidden()
            .padding(.horizontal, 10)
            // As tall as the buttons either side
            .padding(.vertical, 7)
            // No wider than the figures are on a 46mm watch, as on smaller
            // ones they'd reach the buttons: the toolbar makes room for all
            // it's given by pushing them out
            .frame(maxWidth: WKInterfaceDevice.current().screenBounds.width * 0.43)
            .overlay {
                if page == .laps {
                    TimelineView(.animation(paused: phase != .running || isLuminanceReduced)) { frame in
                        let elapsed = stopwatch.elapsed(at: max(frame.date, date))
                        let figures = WatchStopwatchStore.figures(for: elapsed, showsSeconds: !(isLuminanceReduced && phase == .running))

                        Text(verbatim: figures)
                            .foregroundStyle(.white)
                            // Straight to the new figures, as the ring's go
                            .animation(nil, value: figures)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .glassEffect()
                            .accessibilityLabel(Self.spokenTime(elapsed))
                            .accessibilityAddTraits(phase == .running ? .updatesFrequently : [])
                    }
                    .transition(.blurReplace.combined(with: .move(edge: .bottom)).combined(with: .opacity))
                }
            }
            .font(.system(.body, design: .rounded, weight: .medium).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            // As the page view turns the page unanimated
            .transaction(value: page) { $0.animation = .smooth }
    }

    /// Lap while it runs, or Reset once it's stopped, across from Start or
    /// Stop in the corner where the timer's Start is, and on the laps' page,
    /// where the ring isn't there to show it, the time between them.
    @ToolbarContentBuilder
    private func controls(at date: Date, phase: WatchStopwatchStore.Phase) -> some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            let showsReset = switch phase {
            case .idle, .running: false
            case .stopped, .finished: true
            }
            // One button turning from one into the other, rather than one in
            // the other's place, which the animated reset would fade in over
            // the pressed Reset, cutting its glass off
            Button {
                if showsReset {
                    reset()
                } else {
                    stopwatch.lap()
                }
            } label: {
                Label {
                    Text(showsReset ? "Reset" : "Lap")
                } icon: {
                    ZStack {
                        Image(systemName: showsReset ? "arrow.counterclockwise" : "forward.frame.fill")
                            // The system leaves a tinted button's glyph white.
                            // On the symbol rather than the button, so the one
                            // blurring away keeps its color
                            .foregroundStyle(phase == .running ? .black : Color.primary)
                            .id(showsReset)
                            .transition(.blurReplace)
                    }
                }
            }
            .tint(phase == .running ? .white : nil)
            .disabled(phase == .idle)
            // Animated here, as Start and Stop aren't, and on the transaction,
            // as a tap on the toolbar doesn't play an implicit animation. The
            // white fades with the symbols, as gone at once it leaves the one
            // coming in blurred to the end
            .transaction(value: showsReset) { $0.animation = .smooth }
            // With no spacers either side, which leave it off center
            figuresCapsule(at: date, phase: phase)
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

    /// Back to zero, the second hand, the minutes' hand and the tenths' hand
    /// going to the top the nearer way round rather than unwinding.
    private func reset() {
        let elapsed = stopwatch.elapsed(at: .now)
        withAnimation(.smooth) {
            if Self.secondAngle(of: elapsed) > 180 {
                secondTurns += 1
            }
            if Self.tenthAngle(of: elapsed) > 180 {
                tenthTurns += 1
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

    /// `interval`'s tenths round their dial, a second a turn, to read with
    /// the figures', in degrees clockwise from the top.
    private static func tenthAngle(of interval: TimeInterval) -> Double {
        interval.truncatingRemainder(dividingBy: 1) * 360
    }

    private static func spokenTime(_ interval: TimeInterval) -> String {
        Duration.milliseconds(Int64(interval * 1000)).formatted(
            .units(allowed: [.hours, .minutes, .seconds], width: .wide, fractionalPart: .show(length: 2))
        )
    }
}

private extension AnalogueDialLayout {
    /// The minutes' dial, midway between the ring above it and the middle of
    /// the face, as far from the one as from the other.
    var minuteDialCenter: CGPoint { CGPoint(x: center.x, y: center.y - innerRadius / 2) }
    var smallDialRadius: CGFloat { innerRadius * 0.32 }
    var smallDialTickLength: CGFloat { smallDialRadius * 0.14 }
    var smallDialMajorTickLength: CGFloat { smallDialRadius * 0.26 }
    var smallDialTickWidth: CGFloat { tickWidth * 0.75 }
    /// The small dials' hands as the ring's second hands are to it: as wide
    /// as the ticks, back past the middle, round a cap open in its middle.
    var smallDialHandWidth: CGFloat { smallDialTickWidth }
    var smallDialHandTail: CGFloat { smallDialRadius * 0.25 }
    var smallDialCapDiameter: CGFloat { smallDialRadius * 0.24 }
    var smallDialHoleDiameter: CGFloat { max(0, smallDialCapDiameter - smallDialHandWidth * 2) }
    /// Round a small dial, clear of its ticks, the ones further along the row
    /// hide under.
    var smallDialCutoutRadius: CGFloat { smallDialRadius * 1.15 }
    /// The minutes' dial first in a row of the small dials in the ring's
    /// place, bigger, as far above the middle as the figures are below it on
    /// the ring, and the space from one's middle to the next at that size.
    var minuteDialRowCenter: CGPoint { CGPoint(x: center.x - dialRowSpacing, y: center.y - figuresOffset) }
    var dialRowScale: CGFloat { 1.38 }
    var dialRowSpacing: CGFloat { innerRadius * 1.1 }
    /// The time on the stopwatch, large under the row, or on the ring shrunk
    /// to half that.
    var figuresOffset: CGFloat { innerRadius * 0.47 }
    var figuresScale: CGFloat { 0.5 }
    var largeFiguresOffset: CGFloat { innerRadius * 0.65 }
    var largeFiguresFontSize: CGFloat { innerRadius * 0.6 }
    var largeFiguresWidth: CGFloat { innerRadius * 3 }
    /// The second hands' cap, a ring as thick as their bars round its hole.
    var stopwatchCapDiameter: CGFloat { radius * 0.08 }
    var stopwatchHoleDiameter: CGFloat { max(0, stopwatchCapDiameter - secondHandWidth * 2) }
}

private extension View {
    /// Blurred out as the blur-replace transition takes a view out, but kept
    /// in, as the page view puts views back in without their transitions.
    func blurredOut(_ isBlurredOut: Bool) -> some View {
        BlurReplaceTransition.blurReplace.apply(content: self, phase: isBlurredOut ? .didDisappear : .identity)
    }
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

/// The small dials, as the system Stopwatch has its three: the minutes'
/// above the middle, with the seconds' and the tenths' under it, or bigger
/// in a row in the ring's place, the minutes' first, the other two fanning
/// out from under it once it's most of the way there.
private struct SmallDials: View {
    let layout: AnalogueDialLayout
    let isInRow: Bool
    /// In degrees clockwise from the top, counting whole turns. The minutes'
    /// hand steps on a tick as each comes round.
    let minuteAngle: Double
    let secondAngle: Double
    let tenthAngle: Double
    /// The lap hand's, or nil before the first lap.
    let lapAngle: Double?
    let showsSecondHands: Bool

    var body: some View {
        ZStack {
            dial(place: 2, longTicks: 12, between: 2, fades: true) {
                if showsSecondHands {
                    SmallDialHands(layout: layout, angle: tenthAngle)
                        .transition(.blurReplace)
                }
            }
            dial(place: 1, longTicks: 12, between: 2) {
                if showsSecondHands {
                    SmallDialHands(layout: layout, angle: secondAngle, lapAngle: lapAngle)
                        .transition(.blurReplace)
                }
            }
            dial(place: 0, longTicks: 6, between: 4) {
                SmallDialHands(layout: layout, angle: minuteAngle)
                    .animation(.smooth(duration: 0.3), value: minuteAngle)
            }
        }
        // The tenths' and the second hands blurring out where they are with
        // the wrist down while it runs
        .animation(.smooth, value: showsSecondHands)
        .frame(width: layout.smallDialRadius * 2, height: layout.smallDialRadius * 2)
        .scaleEffect(isInRow ? layout.dialRowScale : 1)
        .position(isInRow ? layout.minuteDialRowCenter : layout.minuteDialCenter)
        .compositingGroup()
    }

    /// The dial `place` places along the row from the minutes', or under it,
    /// over the ones further along, or, if it `fades`, faded out under them.
    private func dial(
        place: Int,
        longTicks: Int,
        between: Int,
        fades: Bool = false,
        @ViewBuilder hands: () -> some View
    ) -> some View {
        ZStack {
            Circle()
                .frame(width: layout.smallDialCutoutRadius * 2, height: layout.smallDialCutoutRadius * 2)
                .blendMode(.destinationOut)
            SmallDial(layout: layout, longTicks: longTicks, between: between)
            hands()
        }
        .offset(x: isInRow ? CGFloat(place) * layout.dialRowSpacing / layout.dialRowScale : 0)
        .opacity(fades && !isInRow ? 0 : 1)
        // Back under the minutes' before that goes back
        .animation(isInRow ? .smooth.delay(0.2) : .smooth(duration: 0.3), value: isInRow)
    }
}

/// A small dial as on the system Stopwatch's analogue face, with
/// `longTicks` round it, as bright as the ring's, the first at the top, and
/// `between` shorter, dimmer ones between each two: half an hour a turn for
/// the minutes, as round the ring, a minute for the seconds and a second for
/// the tenths.
private struct SmallDial: View {
    let layout: AnalogueDialLayout
    let longTicks: Int
    let between: Int

    var body: some View {
        let ticks = longTicks * (between + 1)

        ZStack {
            ForEach(0..<ticks, id: \.self) { tick in
                let isLong = tick % (between + 1) == 0
                RadialBar(
                    start: layout.smallDialRadius - (isLong ? layout.smallDialMajorTickLength : layout.smallDialTickLength),
                    end: layout.smallDialRadius,
                    width: layout.smallDialTickWidth
                )
                .fill(.white.opacity(isLong ? 1 : 0.375))
                .rotationEffect(.degrees(Double(tick) * 360 / Double(ticks)))
            }
        }
        .frame(width: layout.smallDialRadius * 2, height: layout.smallDialRadius * 2)
    }
}

/// A small dial's hands as the ring's second hands, smaller: an orange one,
/// over a blue one with the lap's on the seconds' dial, each a thin bar from
/// a short tail behind the middle out to the ticks. The one cap over both
/// keeps the blue from showing round its edge as the two turn.
private struct SmallDialHands: View {
    let layout: AnalogueDialLayout
    /// In degrees clockwise from the top, counting whole turns.
    let angle: Double
    /// The lap hand's, or nil without one.
    var lapAngle: Double?

    var body: some View {
        ZStack {
            // Blurred out in its own place on reset, as the ring's
            if let lapAngle {
                hand(.blue)
                    .rotationEffect(.degrees(lapAngle))
                    .transition(.blurReplace)
            }

            hand(.orange)
                .rotationEffect(.degrees(angle))

            Circle()
                .fill(.orange)
                .frame(width: layout.smallDialCapDiameter, height: layout.smallDialCapDiameter)

            Circle()
                .frame(width: layout.smallDialHoleDiameter, height: layout.smallDialHoleDiameter)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .frame(width: layout.smallDialRadius * 2, height: layout.smallDialRadius * 2)
    }

    private func hand(_ color: Color) -> some View {
        RadialBar(start: -layout.smallDialHandTail, end: layout.smallDialRadius, width: layout.smallDialHandWidth)
            .fill(color)
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
