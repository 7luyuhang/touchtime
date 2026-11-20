//
//  TimerHomeView.swift
//  touchtimeWatch
//
//  The timer, in the list's place once chosen. Its minutes and seconds are
//  set in two boxes the Digital Crown turns, inside the analogue face's
//  ring as it counts the seconds round it, with a dot round the ring at the
//  value being set, as on the system's time pickers. Running, the time left
//  counts down in the boxes' place, with a tick lit round the ring for
//  each minute of it.
//

import SwiftUI

struct TimerHomeView: View {
    private enum Field {
        case minutes
        case seconds
    }

    /// What the timer's doing, each change of it felt.
    private enum Status {
        case idle
        case running
        case paused
        case finished
    }

    @Environment(WatchTimerStore.self) private var timerStore
    @Environment(WatchCityStore.self) private var cityStore
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    /// The box the Digital Crown turns, whose value the dot marks.
    @FocusState private var focusedField: Field?
    @State private var showsRecents = false

    var body: some View {
        TimelineView(CountdownSchedule(endDate: timerStore.endDate)) { context in
            let phase = timerStore.phase(at: context.date)
            let remaining = timerStore.remainingSeconds(at: context.date)

            VStack(spacing: 8) {
                GeometryReader { geometry in
                    let layout = AnalogueDialLayout(
                        diameter: max(0, min(geometry.size.width - 16, geometry.size.height))
                    )

                    ZStack {
                        TimerDial(
                            layout: layout,
                            markedValue: focusedField == .seconds ? timerStore.duration % 60 : timerStore.duration / 60,
                            showsMark: phase == .idle,
                            litTicks: (remaining + 59) / 60
                        )
                        .accessibilityHidden(true)

                        if phase == .idle {
                            numberBoxes(layout: layout)
                                .transition(.blurReplace)
                        } else {
                            let isPaused = if case .paused = phase { true } else { false }
                            countdown(remaining, isPaused: isPaused, layout: layout)
                                .transition(.blurReplace)
                        }
                    }
                    .frame(width: layout.diameter, height: layout.diameter)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }

                // A line's room under the circle, as Conditions leaves for its
                // day, for the circle to be as big as Conditions' and clear of
                // the controls in the corners.
                Text(verbatim: " ")
                    .font(.subheadline)
                    .hidden()
            }
            // The circle's narrow top fits between the toolbar controls, as
            // Conditions' does.
            .padding(.top, -20)
            .padding(.bottom, 8)
            .ignoresSafeArea(edges: .bottom)
            // Also as the run ends, outside any button's transaction
            .animation(.smooth, value: phase == .idle)
            .toolbar {
                controls(for: phase)
            }
            .sensoryFeedback(trigger: status(of: phase, at: context.date)) { _, status in
                switch status {
                case .running: .start
                case .idle, .paused: .stop
                case .finished: .success
                }
            }
        }
        .sheet(isPresented: $showsRecents) {
            RecentTimersSheet { timer in
                timerStore.start(seconds: timer.durationSeconds)
            }
        }
    }

    private func status(of phase: WatchTimerStore.Phase, at date: Date) -> Status {
        if timerStore.isFinished(at: date) {
            return .finished
        }
        switch phase {
        case .idle: return .idle
        case .running: return .running
        case .paused: return .paused
        }
    }

    /// The minutes and seconds the timer's set to, each up to 59, as on
    /// iPhone, with the minutes' taking the Digital Crown first.
    private func numberBoxes(layout: AnalogueDialLayout) -> some View {
        let minutes = Binding {
            timerStore.duration / 60
        } set: { minutes in
            timerStore.duration = minutes * 60 + timerStore.duration % 60
        }
        let seconds = Binding {
            timerStore.duration % 60
        } set: { seconds in
            timerStore.duration = timerStore.duration / 60 * 60 + seconds
        }

        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            numberBox("Minutes", value: minutes, field: .minutes, layout: layout)
            colon(layout: layout)
            numberBox("Seconds", value: seconds, field: .seconds, layout: layout)
        }
        .onAppear {
            focusedField = .minutes
        }
    }

    /// A number the Digital Crown turns while its box is focused, changing
    /// in place, where a wheel picker would scroll the whole number, and on
    /// round from 59 to 00 and back. The box is outlined as the wheel
    /// picker's is while focused, without its fill, and only faintly
    /// otherwise.
    private func numberBox(
        _ title: LocalizedStringKey,
        value: Binding<Int>,
        field: Field,
        layout: AnalogueDialLayout
    ) -> some View {
        let isFocused = focusedField == field
        let box = RoundedRectangle(cornerRadius: 10, style: .continuous)
        // Going on round, the crown takes its two ends for the same place,
        // so it runs to 60, read as 00, for both 59 and 00 to come up.
        let crownValue = Binding {
            value.wrappedValue
        } set: { newValue in
            value.wrappedValue = newValue % 60
        }

        return Text(verbatim: Self.twoDigits(value.wrappedValue))
            .font(Self.digitsFont(size: layout.boxFontSize))
            .frame(width: layout.boxSize, height: layout.boxSize)
            .overlay {
                box.strokeBorder(isFocused ? Color.green : TimerDial.lineColor, lineWidth: isFocused ? 1.5 : 1)
                    // Also as focus comes back after a sheet, outside any transaction of ours
                    .animation(.smooth, value: isFocused)
            }
            .contentShape(box)
            .focusable()
            // The border shows the focus instead.
            .focusEffectDisabled()
            .focused($focusedField, equals: field)
            .digitalCrownRotation(detent: crownValue, from: 0, through: 60, by: 1, sensitivity: .low, isContinuous: true)
            // The indicator beside the crown goes with the scroll indicators,
            // and the number shows the turning instead.
            .scrollIndicators(.hidden)
            .onTapGesture {
                focusedField = field
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(Text(value.wrappedValue, format: .number))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: value.wrappedValue = (value.wrappedValue + 1) % 60
                case .decrement: value.wrappedValue = (value.wrappedValue + 59) % 60
                @unknown default: break
                }
            }
    }

    /// The time left where the boxes were. With the wrist down its seconds
    /// hide, as they'd only turn over once a minute.
    private func countdown(_ remaining: Int, isPaused: Bool, layout: AnalogueDialLayout) -> some View {
        let seconds = isLuminanceReduced ? "--" : Self.twoDigits(remaining % 60)
        return Text(verbatim: "\(Self.twoDigits(remaining / 60)):\(seconds)")
            .font(Self.digitsFont(size: layout.countdownFontSize))
            .contentTransition(.numericText(countsDown: true))
            .animation(.smooth(duration: 0.2), value: remaining)
            .accessibilityLabel(Duration.seconds(remaining).formatted(.units(allowed: [.minutes, .seconds], width: .wide)))
            .accessibilityValue(isPaused ? Text("Paused") : Text(verbatim: ""))
    }

    /// Two dots level with the middle of the figures, where the font's colon
    /// sits lower, on their baseline.
    private func colon(layout: AnalogueDialLayout) -> some View {
        VStack(spacing: layout.colonDotGap) {
            Circle()
                .frame(width: layout.colonDotDiameter, height: layout.colonDotDiameter)
            Circle()
                .frame(width: layout.colonDotDiameter, height: layout.colonDotDiameter)
        }
        .frame(width: layout.colonWidth)
        // The figures stand two thirds of the type size tall on the baseline.
        .alignmentGuide(.firstTextBaseline) { dimensions in
            dimensions[VerticalAlignment.center] + layout.boxFontSize / 3
        }
        .accessibilityHidden(true)
    }

    private static func digitsFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded).monospacedDigit()
    }

    private static func twoDigits(_ value: Int) -> String {
        String(format: "%02d", value)
    }

    /// Start, Pause or Resume in the corner, as the system's time pickers
    /// confirm there, across from the iPhone's recent timers to start
    /// instead, there once it's sent some, or Cancel once started.
    @ToolbarContentBuilder
    private func controls(for phase: WatchTimerStore.Phase) -> some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            if phase == .idle {
                Button("Recents", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") {
                    showsRecents = true
                }
                .disabled(cityStore.recentTimers.isEmpty)
            } else {
                Button("Cancel", systemImage: "xmark") {
                    timerStore.cancel()
                }
            }
            Spacer()
            switch phase {
            case .idle:
                Button("Start", systemImage: "play.fill") {
                    timerStore.start()
                }
                .tint(timerStore.duration == 0 ? nil : .orange)
                .disabled(timerStore.duration == 0)
            case .running:
                Button("Pause", systemImage: "pause.fill") {
                    timerStore.pause()
                }
                .tint(.orange)
            case .paused:
                Button("Resume", systemImage: "play.fill") {
                    timerStore.resume()
                }
                .tint(.orange)
            }
        }
    }
}

private extension AnalogueDialLayout {
    /// Each number's box, square, the two of them with room to spare inside
    /// the ring.
    var boxSize: CGFloat { innerRadius * 0.72 }
    var colonWidth: CGFloat { innerRadius * 0.16 }
    var boxFontSize: CGFloat { innerRadius * 0.42 }
    /// The colon's dots, as big and as far apart as the font's.
    var colonDotDiameter: CGFloat { boxFontSize * 0.14 }
    var colonDotGap: CGFloat { boxFontSize * 0.2 }
    /// The time left's, bigger, without the boxes round it.
    var countdownFontSize: CGFloat { innerRadius * 0.5 }
}

/// The analogue face's ring as it counts the seconds round it once tapped,
/// outlined rather than glass: a tick for each one round its outer edge,
/// every fifth one longer, and inside them the fives, in two figures as the
/// boxes' numbers are, from 00 at the top rather than 60. While the timer's
/// set, a dot stands in for the tick of the value being set; while it runs, a
/// tick is lit from the top for each minute left.
private struct TimerDial: View {
    /// The ring's edges, and the boxes' unless focused.
    static let lineColor = Color.white.opacity(0.2)

    let layout: AnalogueDialLayout
    /// The value being set, 0 to 59.
    let markedValue: Int
    let showsMark: Bool
    let litTicks: Int
    /// The dot's place, which counts on past 59 and back below 0, for the
    /// dot to go on round to the value rather than back the long way, and
    /// which stays where the dot went while it's gone.
    @State private var markPosition: Int?

    var body: some View {
        ZStack {
            layout.ring
                .stroke(Self.lineColor, lineWidth: 1)

            ForEach(0..<60, id: \.self) { tick in
                let isLit = tick < litTicks
                RadialBar(
                    start: layout.tickOuterRadius - (tick % 5 == 0 ? layout.majorTickLength : layout.tickLength),
                    end: layout.tickOuterRadius,
                    width: layout.tickWidth
                )
                // The shorter ticks as bright on black as the face's are on
                // its glass
                .fill(isLit ? Color.orange : .white.opacity(tick % 5 == 0 ? 1 : 0.375))
                .opacity(showsMark && tick == markedValue ? 0 : 1)
                .rotationEffect(.degrees(Double(tick) * 6))
                .animation(tickAnimation(tick: tick, isLit: isLit), value: isLit)
            }

            ForEach(1...12, id: \.self) { hour in
                Text(verbatim: String(format: "%02d", hour * 5 % 60))
                    // Shrunk as the face's seconds are, rather than set
                    // smaller, so they look the same
                    .font(.system(size: layout.hourFontSize, weight: .semibold, design: .rounded))
                    .scaleEffect(layout.secondNumberScale)
                    .foregroundStyle(.white)
                    .position(layout.point(atHour: hour, radius: layout.secondNumberRadius))
            }

            // Going and coming as the boxes do, blurred in its own place
            // rather than toward the middle
            ZStack {
                if showsMark {
                    Circle()
                        .fill(.orange)
                        .transition(.blurReplace)
                }
            }
            .frame(width: layout.majorTickLength, height: layout.majorTickLength)
            .position(x: layout.center.x, y: layout.center.y - layout.tickOuterRadius + layout.majorTickLength / 2)
            .rotationEffect(.degrees(Double(markPosition ?? markedValue) * 6))
        }
        .animation(.smooth, value: markedValue)
        .frame(width: layout.diameter, height: layout.diameter)
        .onAppear {
            markPosition = markedValue
        }
        .onChange(of: markedValue) { oldValue, newValue in
            // Not after the dot as the timer starts, when the seconds' box
            // goes and the value turns back to the minutes
            guard showsMark else { return }
            // The nearer way round, -30 to 29 steps
            let steps = (newValue - oldValue + 90) % 60 - 30
            withAnimation(.smooth) {
                markPosition = (markPosition ?? oldValue) + steps
            }
        }
        .onChange(of: showsMark) {
            if showsMark {
                markPosition = markedValue
            }
        }
    }

    /// The ticks light one after another round from the top, and go out the
    /// other way, quicker, as the face's seconds come in and go.
    private func tickAnimation(tick: Int, isLit: Bool) -> Animation {
        isLit
            ? .smooth(duration: 0.35).delay(Double(tick) / 60 * 0.4)
            : .smooth(duration: 0.25).delay(Double(59 - tick) / 60 * 0.2)
    }
}

/// When the time left turns over, up to the end: each second, or with the
/// wrist down, each minute, as only its minutes show then. Just the once
/// while nothing counts down.
private nonisolated struct CountdownSchedule: TimelineSchedule {
    let endDate: Date?

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> [Date] {
        guard let endDate, endDate > startDate else { return [startDate] }
        // The seconds left, rounded up, turn over a whole number of seconds
        // before the end, and the whole minutes in them a second after a
        // whole number of minutes before it.
        let secondsLeft = Int(endDate.timeIntervalSince(startDate).rounded(.up))
        let turns = (0..<secondsLeft).reversed().filter { seconds in
            mode != .lowFrequency || seconds == 0 || (seconds + 1) % 60 == 0
        }
        // One more after the end, as the view never updates for the last
        // date of a schedule, which would leave the run at 00:01.
        return [startDate] + turns.map { endDate.addingTimeInterval(-TimeInterval($0)) } + [endDate.addingTimeInterval(1)]
    }
}

#Preview {
    NavigationStack {
        TimerHomeView()
    }
    .environment(WatchTimerStore())
    .environment(WatchCityStore())
}
