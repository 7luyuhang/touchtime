//
//  AnalogClockStopwatch.swift
//  touchtime
//
//  Stopwatch page components for AnalogClockFullView.
//

import SwiftUI

// MARK: - Stopwatch Controls State
/// Which pair of buttons the bottom controls should offer.
/// idle: Start · running: Lap / Stop · stopped: Reset / Start · finished: Reset
enum StopwatchControlsState: Equatable {
    case idle
    case running
    case stopped
    /// Stopped at `StopwatchSnapshot.maxElapsed`; only Reset is left.
    case finished
}

// MARK: - Stopwatch Snapshot
/// Value snapshot of the persisted stopwatch state. Elapsed time is derived
/// from the wall clock so the stopwatch keeps counting while the app is
/// backgrounded or relaunched.
struct StopwatchSnapshot: Equatable {
    /// The stopwatch stops at 99:59:59.99, like the iOS Stopwatch.
    static let maxElapsed: TimeInterval = 99 * 3600 + 59 * 60 + 59.99

    /// Unix epoch of the moment the current run started; 0 while stopped.
    var startEpoch: Double
    /// Time collected by previous runs (before the current start).
    var accumulatedSeconds: TimeInterval
    /// Duration of each completed lap, in recorded order.
    var laps: [TimeInterval]

    var isRunning: Bool {
        startEpoch > 0
    }

    var hasStarted: Bool {
        isRunning || accumulatedSeconds > 0 || !laps.isEmpty
    }

    /// Stopped at `maxElapsed`; only Reset can move it on.
    var isFinished: Bool {
        !isRunning && accumulatedSeconds >= Self.maxElapsed
    }

    var controlsState: StopwatchControlsState {
        if isRunning { return .running }
        if isFinished { return .finished }
        return hasStarted ? .stopped : .idle
    }

    /// Total elapsed time, never past `maxElapsed`.
    func elapsed(at date: Date) -> TimeInterval {
        let total: TimeInterval
        if isRunning {
            let currentRun = date.timeIntervalSince1970 - startEpoch
            total = accumulatedSeconds + max(currentRun, 0)
        } else {
            total = accumulatedSeconds
        }
        return min(max(total, 0), Self.maxElapsed)
    }

    /// True while running once the total has hit `maxElapsed`; the run should
    /// then be persisted as stopped.
    func hasReachedLimit(at date: Date) -> Bool {
        isRunning && elapsed(at: date) >= Self.maxElapsed
    }

    /// Time counted since the last recorded lap (or since the start).
    func currentLapElapsed(at date: Date) -> TimeInterval {
        let completedLapsTotal = laps.reduce(0, +)
        return max(elapsed(at: date) - completedLapsTotal, 0)
    }

    /// 1-based number of the lap currently in progress.
    var currentLapNumber: Int {
        laps.count + 1
    }
}

// MARK: - Stopwatch Lap Store
/// Encodes the lap list for `@AppStorage`, which cannot hold arrays directly.
enum StopwatchLapStore {
    static func decode(_ data: Data) -> [TimeInterval] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([TimeInterval].self, from: data)) ?? []
    }

    static func encode(_ laps: [TimeInterval]) -> Data {
        (try? JSONEncoder().encode(laps)) ?? Data()
    }
}

// MARK: - Stopwatch Time Formatter
enum StopwatchTimeFormatter {
    /// "MM:SS.hh", growing to "H:MM:SS.hh" once the first hour is reached.
    static func string(from interval: TimeInterval) -> String {
        let totalCentiseconds = Int((max(interval, 0) * 100).rounded(.down))
        let centiseconds = totalCentiseconds % 100
        let totalSeconds = totalCentiseconds / 100
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600

        if hours > 0 {
            return String(format: "%d:%02d:%02d.%02d", hours, minutes, seconds, centiseconds)
        }
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }
}

// MARK: - Stopwatch Clock Face
struct StopwatchClockFaceView: View {
    let size: CGFloat
    let stopwatch: StopwatchSnapshot

    private var numberRingRadius: CGFloat {
        size / 2 - 36
    }

    /// The lap hand and the sweep that follows it.
    private static let lapHandColor: Color = .yellow

    private static func secondsAngle(for elapsed: TimeInterval) -> Double {
        elapsed.truncatingRemainder(dividingBy: 60) * 6.0
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.25))
                .glassEffect(.clear.interactive())
                .frame(width: max(size - 24, 0), height: max(size - 24, 0))
                .contentShape(Circle())

            // Seconds dial: 5 … 55 with 60 at the top
            ForEach(0..<12, id: \.self) { index in
                let angle = Double(index) * 30.0 - 90
                let x = numberRingRadius * cos(angle * .pi / 180)
                let y = numberRingRadius * sin(angle * .pi / 180)
                let markValue = index == 0 ? 60 : index * 5

                Text("\(markValue)")
                    .font(.headline)
                    .fontDesign(.rounded)
                    .foregroundColor(.white)
                    .position(x: size / 2 + x, y: size / 2 + y)
            }

            TimerMinuteTickMarksView(
                size: size,
                ringRadius: numberRingRadius
            )
            .allowsHitTesting(false)

            // Hands redraw every frame only while the stopwatch is running
            TimelineView(.animation(paused: !stopwatch.isRunning)) { context in
                let elapsed = stopwatch.elapsed(at: context.date)
                let totalAngle = Self.secondsAngle(for: elapsed)

                // Like the iOS Stopwatch: the first Lap adds a second hand that
                // tracks the current lap and snaps back to 60 on every Lap. The
                // sweep trail follows that hand, in its yellow; the total hand
                // keeps running without one. There are never more than two hands.
                let hasLapHand = !stopwatch.laps.isEmpty
                let lapElapsed = stopwatch.currentLapElapsed(at: context.date)
                let lapAngle = Self.secondsAngle(for: lapElapsed)
                let trailElapsed = hasLapHand ? lapElapsed : elapsed
                let trailAngle = hasLapHand ? lapAngle : totalAngle
                let trailColor: Color = hasLapHand ? Self.lapHandColor : .white

                ZStack {
                    if trailElapsed > 0 {
                        TimerRangeFillView(
                            startAngle: 0,
                            endAngle: trailAngle,
                            size: size,
                            color: trailColor
                        )
                    }

                    // Total elapsed
                    TimerAnimatedHandView(
                        angle: totalAngle,
                        size: size,
                        color: .white
                    )

                    // Current lap
                    if hasLapHand {
                        TimerAnimatedHandView(
                            angle: lapAngle,
                            size: size,
                            color: Self.lapHandColor
                        )
                    }
                }
                .frame(width: size, height: size)
            }
            .allowsHitTesting(false)

            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Stopwatch Lap Extremes
/// Shortest and longest lap; both are nil until there are two laps to compare.
struct StopwatchLapExtremes {
    let fastestIndex: Int?
    let slowestIndex: Int?

    init(laps: [TimeInterval]) {
        guard laps.count >= 2 else {
            fastestIndex = nil
            slowestIndex = nil
            return
        }
        fastestIndex = laps.indices.min { laps[$0] < laps[$1] }
        slowestIndex = laps.indices.max { laps[$0] < laps[$1] }
    }

    /// `circle` marks the fastest lap, `circle.fill` the slowest.
    func symbolName(for index: Int) -> String? {
        if index == fastestIndex { return "circle" }
        if index == slowestIndex { return "circle.fill" }
        return nil
    }
}

// MARK: - Stopwatch Lap History
/// Completed laps, newest first, shown between the clock face and the controls.
/// Tapping the area opens `StopwatchLapListSheet` with the full list.
struct StopwatchLapHistoryView: View {
    let laps: [TimeInterval]

    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var showsLapSheet = false

    private var lapExtremes: StopwatchLapExtremes {
        StopwatchLapExtremes(laps: laps)
    }

    private var edgeFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.25),
                .init(color: .black, location: 0.75),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func lapRow(index: Int, lap: TimeInterval) -> some View {
        HStack {
            Text(String.localizedStringWithFormat(String(localized: "Lap %d"), index + 1))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            if let symbolName = lapExtremes.symbolName(for: index) {
                Image(systemName: symbolName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.primary)
            }

            Text(StopwatchTimeFormatter.string(from: lap))
                .foregroundStyle(.primary)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 40)
        .monospacedDigit()
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 8) {
                    ForEach(Array(laps.enumerated().reversed()), id: \.offset) { index, lap in
                        VStack(spacing: 8) {
                            lapRow(index: index, lap: lap)

                            if index != 0 {
                                Divider()
                                    .overlay(.white.opacity(0.05))
                                    .padding(.horizontal, 40)
                            }
                        }
                        .transition(.blurReplace.combined(with: .opacity))
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height, alignment: .center)
            }
            .scrollIndicators(.hidden)
            .mask(edgeFadeMask)
        }
        .blendMode(.plusLighter)
        .animation(.spring(duration: 0.25), value: laps.count)
        .contentShape(Rectangle())
        .onTapGesture {
            // Nothing to show before the first lap is recorded
            guard !laps.isEmpty else { return }
            triggerHaptic()
            showsLapSheet = true
        }
        .sheet(isPresented: $showsLapSheet) {
            StopwatchLapListSheet(laps: laps)
        }
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}

// MARK: - Stopwatch Lap List Sheet
/// Plain list of every recorded lap, newest first.
struct StopwatchLapListSheet: View {
    let laps: [TimeInterval]

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    private var lapExtremes: StopwatchLapExtremes {
        StopwatchLapExtremes(laps: laps)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(laps.enumerated().reversed()), id: \.offset) { index, lap in
                    LabeledContent {
                        HStack {
                            if let symbolName = lapExtremes.symbolName(for: index) {
                                Image(systemName: symbolName)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.primary)
                            }

                            Text(StopwatchTimeFormatter.string(from: lap))
                                .foregroundStyle(.primary)
                        }
                    } label: {
                        Text(String.localizedStringWithFormat(String(localized: "Lap %d"), index + 1))
                            .foregroundStyle(.secondary)
                    }
                    .monospacedDigit()
                }
            }
            .navigationTitle(String(localized: "Laps"))
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
            }
        }
        .presentationDetents([.medium])
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}
