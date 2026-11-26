//
//  StopwatchHomeView.swift
//  touchtimeWatch
//
//  The stopwatch, in the list's place once chosen, on the timer's ring, with
//  hands as the system's Stopwatch has them on its analogue face: an orange
//  one sweeping round with the time on the stopwatch, and from the first lap
//  a blue one with the lap's, back at the top for each new lap. The minutes
//  go round a small dial above the middle, and the time shows in figures
//  below it, as on that face, with the lap under way's number under them
//  from the first lap. With a tap anywhere on the ring, the figures
//  grow in its place, under the minutes' dial, the seconds' and the tenths'
//  in a row, as the system's Stopwatch has its three dials. The laps are
//  listed on a page to its right.
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
    /// dials in a row, from a tap anywhere there.
    @State private var isDigital = false
    /// From the toolbar buttons' outer edges on one side to the other's,
    /// which the small dials reach across in a row.
    @State private var dialRowWidth: CGFloat = 0
    /// Where the page view ends on the screen, and the toolbar's buttons
    /// start, which the large figures are midway between the row and.
    @State private var pagesBottom: CGFloat = 0

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
            // On the screen, as the pages are each in a space of their own
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).maxY
            } action: { newBottom in
                pagesBottom = newBottom
            }
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
                // From the ring's top
                let buttonsTop = pagesBottom
                    - geometry.frame(in: .global).minY
                    - (geometry.size.height - layout.diameter) / 2

                ZStack {
                    SecondsDial(layout: layout, countsToSixty: true)
                        .accessibilityHidden(true)
                        .blurredOut(isDigital)

                    // Every frame while it runs, but not with the wrist
                    // down, when the minutes turning over are enough.
                    TimelineView(.animation(paused: phase != .running || isLuminanceReduced)) { frame in
                        face(at: max(frame.date, date), phase: phase, layout: layout, buttonsTop: buttonsTop)
                    }
                }
                .frame(width: layout.diameter, height: layout.diameter)
                .contentShape(.circle)
                .onTapGesture {
                    // Back to the ring once the seconds' and the tenths'
                    // dials are back under the minutes'
                    withAnimation(isDigital ? .smooth.delay(0.15) : .smooth) {
                        isDigital.toggle()
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            // The toolbar buttons' outer edges are where the navigation
            // bar's padding ends either side.
            .background {
                Color.clear
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.width
                    } action: { newWidth in
                        dialRowWidth = newWidth
                    }
                    .scenePadding(.navigationBar, edges: .horizontal)
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

    /// The figures, the small dials and the hands at `date`, over the
    /// toolbar's buttons from `buttonsTop` down.
    private func face(at date: Date, phase: WatchStopwatchStore.Phase, layout: AnalogueDialLayout, buttonsTop: CGFloat) -> some View {
        let elapsed = stopwatch.elapsed(at: date)
        let lapElapsed = stopwatch.laps.isEmpty ? nil : stopwatch.currentLapElapsed(at: date)
        // With the wrist down while it runs, they'd only turn over once a
        // minute.
        let showsSeconds = !(isLuminanceReduced && phase == .running)
        let secondAngle = secondTurns * 360 + Self.secondAngle(of: elapsed)
        let lapAngle = lapElapsed.map { Self.secondAngle(of: $0) }
        let figuresMiddle = isDigital
            ? layout.largeFiguresMiddle(rowWidth: dialRowWidth, bottom: buttonsTop)
            : layout.figuresMiddle

        return ZStack {
            figures(
                elapsed: elapsed,
                lapElapsed: lapElapsed,
                showsSeconds: showsSeconds,
                isRunning: phase == .running,
                middle: figuresMiddle,
                layout: layout
            )

            lapNumber(middle: figuresMiddle, layout: layout)

            SmallDials(
                layout: layout,
                rowWidth: dialRowWidth,
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
                .blurredOut(isDigital)
        }
    }

    /// The time on the stopwatch in figures below the middle, or large under
    /// the small dials in a row, around `middle`, or a little higher with the
    /// lap's number under them from the first lap.
    private func figures(
        elapsed: TimeInterval,
        lapElapsed: TimeInterval?,
        showsSeconds: Bool,
        isRunning: Bool,
        middle: CGFloat,
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
            // Shrunk on the ring rather than set smaller, so that it grows
            // into the large figures in the same font
            .scaleEffect(isDigital ? 1 : layout.figuresScale)
            .position(x: layout.center.x, y: layout.center.y + layout.figuresOffset(middle: middle, isLarge: isDigital, showsLap: lapElapsed != nil))
            // Up for the lap's number as it comes with the first lap, which
            // isn't animated, for the lap hand to show at once
            .animation(.smooth, value: lapElapsed != nil)
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

    /// The lap under way's number under the figures from the first lap, the
    /// two around `middle`, smaller than them, and growing less than they do
    /// under the row.
    private func lapNumber(middle: CGFloat, layout: AnalogueDialLayout) -> some View {
        let lap = stopwatch.laps.isEmpty ? nil : stopwatch.laps.count + 1

        return ZStack {
            // Blurred in with the first lap and out on reset in its own
            // place, rather than toward the middle
            if let lap {
                Text("Lap \(lap)")
                    .font(.system(size: layout.largeLapFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(lap)))
                    .transition(.blurReplace)
            }
        }
        // Its room, there with no lap too, as room growing round the number
        // from nothing would bring it in from the bottom right
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Shrunk on the ring, as the figures are
        .scaleEffect(isDigital ? 1 : layout.lapScale)
        .position(x: layout.center.x, y: layout.center.y + layout.lapOffset(middle: middle, isLarge: isDigital))
        .animation(.smooth, value: lap)
        // Read out with the figures instead, with the lap's time
        .accessibilityHidden(true)
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
    /// A small dial's number, a little nearer its middle than its edge, for
    /// room under the top tick, its type nearly half the dial's radius.
    var smallDialNumberRadius: CGFloat { smallDialRadius * 0.45 }
    var smallDialNumberScale: CGFloat { smallDialRadius * 0.45 / hourFontSize }
    /// The small dials in a row in the ring's place, reaching across `width`
    /// from the minutes' outer edge to the tenths', with the gap between
    /// each two: how much bigger each one is there, the space from one's
    /// middle to the next, and the minutes' middle, first in the row, as high
    /// as on the ring.
    var dialRowGap: CGFloat { innerRadius * 0.22 }
    func dialRowScale(width: CGFloat) -> CGFloat { max(0, width - dialRowGap * 2) / 6 / smallDialRadius }
    func dialRowSpacing(width: CGFloat) -> CGFloat { max(0, width - dialRowGap * 2) / 3 + dialRowGap }
    func minuteDialRowCenter(width: CGFloat) -> CGPoint {
        CGPoint(x: center.x - dialRowSpacing(width: width), y: minuteDialCenter.y)
    }
    /// The time on the stopwatch, large under the row, or on the ring shrunk
    /// to half that, and the lap under way's number, large under the row, or
    /// on the ring four fifths the size of the figures there.
    var figuresScale: CGFloat { 0.5 }
    var largeFiguresFontSize: CGFloat { innerRadius * 0.6 }
    var largeFiguresWidth: CGFloat { innerRadius * 3 }
    var largeLapFontSize: CGFloat { innerRadius * 0.28 }
    var lapScale: CGFloat { figuresFontSize(isLarge: false) * 0.8 / largeLapFontSize }
    /// Below the middle, the middle of the space the figures are in the
    /// middle of, with the lap's number under them from the first lap: on the
    /// ring, between the middle and the inside of the line a point wide on the
    /// ring's inner edge, or large, between the row across `rowWidth` and
    /// `bottom`.
    var figuresMiddle: CGFloat { (innerRadius - 0.5) / 2 }
    func largeFiguresMiddle(rowWidth: CGFloat, bottom: CGFloat) -> CGFloat {
        let rowBottom = minuteDialRowCenter(width: rowWidth).y + smallDialRadius * dialRowScale(width: rowWidth)
        return (rowBottom + bottom) / 2 - center.y
    }
    /// How far below the middle the figures are, and the lap's number, for
    /// what shows of them to be in the middle together around `middle`: the
    /// figures' digits a third of their type size up from their own middle
    /// and three eighths of it down, and the number's characters, the Chinese
    /// ones the tallest, a third of its type size up and 0.45 of it down, that
    /// much of it under the digits.
    func figuresOffset(middle: CGFloat, isLarge: Bool, showsLap: Bool) -> CGFloat {
        let figuresSize = figuresFontSize(isLarge: isLarge)
        let height = figuresSize * (1.0 / 3 + 3.0 / 8)
            + (showsLap ? lapFontSize(isLarge: isLarge) * (0.45 + 1.0 / 3 + 0.45) : 0)
        return middle - height / 2 + figuresSize / 3
    }
    func lapOffset(middle: CGFloat, isLarge: Bool) -> CGFloat {
        figuresOffset(middle: middle, isLarge: isLarge, showsLap: true)
            + figuresFontSize(isLarge: isLarge) * 3 / 8
            + lapFontSize(isLarge: isLarge) * (0.45 + 1.0 / 3)
    }
    func figuresFontSize(isLarge: Bool) -> CGFloat { largeFiguresFontSize * (isLarge ? 1 : figuresScale) }
    func lapFontSize(isLarge: Bool) -> CGFloat { largeLapFontSize * (isLarge ? 1 : lapScale) }
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
/// out from under it once it's most of the way there, with the numbers at
/// the tops of all three.
private struct SmallDials: View {
    let layout: AnalogueDialLayout
    /// From the minutes' outer edge to the tenths' once in a row.
    let rowWidth: CGFloat
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
            dial(place: 2, longTicks: 12, between: 2, number: 10, fades: true) {
                if showsSecondHands {
                    SmallDialHands(layout: layout, angle: tenthAngle)
                        .transition(.blurReplace)
                }
            }
            dial(place: 1, longTicks: 12, between: 2, number: 60) {
                if showsSecondHands {
                    SmallDialHands(layout: layout, angle: secondAngle, lapAngle: lapAngle)
                        .transition(.blurReplace)
                }
            }
            dial(place: 0, longTicks: 6, between: 4, number: 30) {
                SmallDialHands(layout: layout, angle: minuteAngle)
                    .animation(.smooth(duration: 0.3), value: minuteAngle)
            }
        }
        // The tenths' and the second hands blurring out where they are with
        // the wrist down while it runs
        .animation(.smooth, value: showsSecondHands)
        .frame(width: layout.smallDialRadius * 2, height: layout.smallDialRadius * 2)
        .scaleEffect(isInRow ? layout.dialRowScale(width: rowWidth) : 1)
        .position(isInRow ? layout.minuteDialRowCenter(width: rowWidth) : layout.minuteDialCenter)
        .compositingGroup()
    }

    /// The dial `place` places along the row from the minutes', or under it,
    /// over the ones further along, or, if it `fades`, faded out under them.
    private func dial(
        place: Int,
        longTicks: Int,
        between: Int,
        number: Int,
        fades: Bool = false,
        @ViewBuilder hands: () -> some View
    ) -> some View {
        ZStack {
            Circle()
                .frame(width: layout.smallDialCutoutRadius * 2, height: layout.smallDialCutoutRadius * 2)
                .blendMode(.destinationOut)
            SmallDial(layout: layout, longTicks: longTicks, between: between, number: number, showsNumber: isInRow)
            hands()
        }
        .offset(x: isInRow ? CGFloat(place) * layout.dialRowSpacing(width: rowWidth) / layout.dialRowScale(width: rowWidth) : 0)
        .opacity(fades && !isInRow ? 0 : 1)
        // Back under the minutes' before that goes back
        .animation(isInRow ? .smooth.delay(0.2) : .smooth(duration: 0.3), value: isInRow)
    }
}

/// A small dial as on the system Stopwatch's analogue face, with
/// `longTicks` round it, as bright as the ring's, the first at the top, and
/// `between` shorter, dimmer ones between each two: half an hour a turn for
/// the minutes, as round the ring, a minute for the seconds and a second for
/// the tenths. Inside the top one, while it `showsNumber`, the `number` a
/// turn counts to, as the ring has 60 inside its top one.
private struct SmallDial: View {
    let layout: AnalogueDialLayout
    let longTicks: Int
    let between: Int
    let number: Int
    let showsNumber: Bool

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

            Text(verbatim: "\(number)")
                // Shrunk as the ring's fives are, rather than set smaller,
                // so they look the same
                .font(.system(size: layout.hourFontSize, weight: .semibold, design: .rounded))
                .scaleEffect(layout.smallDialNumberScale)
                .foregroundStyle(.white)
                .offset(y: -layout.smallDialNumberRadius)
                .opacity(showsNumber ? 1 : 0)
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
