//
//  TouchTimeActivityAttributes.swift
//  touchtime
//
//  Live Activity models for the Home timer and stopwatch.
//

import ActivityKit
import Foundation

/// The Home timer's Live Activity. Text is localized by the app, so the
/// widget extension shows exactly what the Home card shows.
nonisolated struct TimerActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        /// The timer's name, or "Timer" when it has none.
        var title: String
        /// The configured duration as the Home card words it, e.g. "5 min".
        var durationText: String
        var configuredSeconds: Int
        /// Unix epoch of the moment the running timer ends; 0 while paused.
        var endDateEpoch: Double
        /// Seconds left while paused.
        var pausedRemainingSeconds: Int

        var isRunning: Bool {
            endDateEpoch > 0
        }

        var endDate: Date? {
            isRunning ? Date(timeIntervalSince1970: endDateEpoch) : nil
        }

        /// Where the countdown range starts; it is never later than now, as
        /// what is left can't exceed the configured duration.
        func countdownStart(endingAt endDate: Date) -> Date {
            endDate.addingTimeInterval(-TimeInterval(max(configuredSeconds, 1)))
        }

        /// Share of the configured duration still left while paused.
        var pausedRemainingFraction: Double {
            guard configuredSeconds > 0 else { return 0 }
            return min(max(Double(pausedRemainingSeconds) / Double(configuredSeconds), 0), 1)
        }
    }
}

/// The Home stopwatch's Live Activity.
nonisolated struct StopwatchActivityAttributes: ActivityAttributes {
    /// "Stopwatch", localized by the app.
    var title: String

    nonisolated struct ContentState: Codable, Hashable {
        /// Unix epoch of the moment the current run started; 0 while stopped.
        var startEpoch: Double
        /// Time collected by previous runs.
        var accumulatedSeconds: TimeInterval
        /// The lap count as the Home card words it, e.g. "3 Laps"; empty
        /// before the first lap.
        var lapsText: String

        var isRunning: Bool {
            startEpoch > 0
        }

        /// When a stopwatch running without pauses would have started, so
        /// the live digits can count up from it.
        var virtualStartDate: Date {
            Date(timeIntervalSince1970: startEpoch - accumulatedSeconds)
        }
    }
}
