//
//  HomeView+Stopwatch.swift
//  touchtime
//

import SwiftUI

extension HomeView {
    var homeStopwatch: StopwatchSnapshot {
        StopwatchSnapshot(
            startEpoch: homeStopwatchStartEpoch,
            accumulatedSeconds: homeStopwatchAccumulatedSeconds,
            laps: StopwatchLapStore.decode(homeStopwatchLapsData)
        )
    }

    /// Start / Stop from the stopwatch card.
    func handleHomeStopwatchTap() {
        let stopwatch = homeStopwatch
        guard !stopwatch.isFinished else { return }

        if stopwatch.isRunning {
            homeStopwatchAccumulatedSeconds = stopwatch.elapsed(at: Date())
            homeStopwatchStartEpoch = 0
        } else {
            homeStopwatchStartEpoch = Date().timeIntervalSince1970
        }

        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }

    /// Start from the Stopwatch records sheet. A session under way is
    /// replaced, going to the records first as Reset sends it.
    func startNewHomeStopwatch() {
        let now = Date()
        let stopwatch = homeStopwatch
        if stopwatch.hasStarted {
            StopwatchRecordStore.remember(
                totalSeconds: stopwatch.elapsed(at: now),
                laps: stopwatch.laps
            )
        }

        withAnimation(.spring()) {
            homeStopwatchAccumulatedSeconds = 0
            homeStopwatchLapsData = Data()
            homeStopwatchStartEpoch = now.timeIntervalSince1970
        }
    }

    /// Persist the stop once the running total hits 99:59:59.99. The display
    /// is already clamped, so this only has to flip the card's button to play.
    func finalizeHomeStopwatchIfLimitReached(at now: Date) {
        guard homeStopwatch.hasReachedLimit(at: now) else { return }
        homeStopwatchAccumulatedSeconds = StopwatchSnapshot.maxElapsed
        homeStopwatchStartEpoch = 0
    }

    /// Reset ends the session: its time and laps go to the Stopwatch records
    /// (see `StopwatchRecordsSheet`) before the stopwatch is cleared.
    func resetHomeStopwatch() {
        let stopwatch = homeStopwatch
        if stopwatch.hasStarted {
            StopwatchRecordStore.remember(
                totalSeconds: stopwatch.elapsed(at: Date()),
                laps: stopwatch.laps
            )
        }

        withAnimation(.spring()) {
            homeStopwatchStartEpoch = 0
            homeStopwatchAccumulatedSeconds = 0
            homeStopwatchLapsData = Data()
        }

        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }
}
