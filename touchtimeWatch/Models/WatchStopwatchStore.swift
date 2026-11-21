//
//  WatchStopwatchStore.swift
//  touchtimeWatch
//
//  The stopwatch, run as the iPhone app's is: up to 99:59:59.99, counting
//  on from a start kept in the watch's own defaults, so it runs on with the
//  app closed, and keeping the time of each lap until it's reset.
//

import Foundation
import Observation

/// The time on the stopwatch and its laps: counting on from a start, or
/// stopped with the time it had.
@Observable
final class WatchStopwatchStore {
    /// As on iPhone, the stopwatch stops at 99:59:59.99.
    nonisolated static let maxElapsed: TimeInterval = 99 * 3600 + 59 * 60 + 59.99

    enum Phase: Equatable {
        /// At zero, not started since it was last reset.
        case idle
        case running
        /// Stopped with time on it, to start again or reset.
        case stopped
        /// Stopped at its limit, only to be reset.
        case finished
    }

    private enum Key {
        static let startDate = "stopwatchStartDate"
        static let accumulated = "stopwatchAccumulated"
        static let laps = "stopwatchLaps"
    }

    /// When the run under way started, or nil while it's stopped.
    private var startDate: Date?
    /// The time counted before it.
    private var accumulated: TimeInterval
    /// Each lap's time, in the order they were recorded.
    private(set) var laps: [TimeInterval]

    init() {
        let defaults = UserDefaults.standard
        let startDate = defaults.double(forKey: Key.startDate)
        self.startDate = startDate > 0 ? Date(timeIntervalSince1970: startDate) : nil
        accumulated = defaults.double(forKey: Key.accumulated)
        laps = defaults.array(forKey: Key.laps) as? [TimeInterval] ?? []
    }

    /// When the stopwatch would have read zero, had it run all along: nil
    /// while it's stopped.
    var zeroDate: Date? {
        startDate?.addingTimeInterval(-accumulated)
    }

    /// The time on the stopwatch at `date`, up to its limit.
    func elapsed(at date: Date) -> TimeInterval {
        let elapsed = zeroDate.map { date.timeIntervalSince($0) } ?? accumulated
        return min(max(elapsed, 0), Self.maxElapsed)
    }

    /// The time since the last lap, or since the start before the first.
    func currentLapElapsed(at date: Date) -> TimeInterval {
        max(elapsed(at: date) - laps.reduce(0, +), 0)
    }

    /// The stopwatch at `date`, stopped once it's reached its limit.
    func phase(at date: Date) -> Phase {
        if elapsed(at: date) >= Self.maxElapsed {
            return .finished
        }
        if startDate != nil {
            return .running
        }
        return accumulated > 0 || !laps.isEmpty ? .stopped : .idle
    }

    func start() {
        let now = Date.now
        switch phase(at: now) {
        case .idle, .stopped:
            startDate = now
            save()
        case .running, .finished:
            break
        }
    }

    func stop() {
        guard startDate != nil else { return }
        accumulated = elapsed(at: .now)
        startDate = nil
        save()
    }

    /// Ends the lap under way, and starts the next.
    func lap() {
        let now = Date.now
        guard phase(at: now) == .running else { return }
        laps.append(currentLapElapsed(at: now))
        save()
    }

    /// Back to zero, its laps cleared.
    func reset() {
        startDate = nil
        accumulated = 0
        laps = []
        save()
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(startDate?.timeIntervalSince1970 ?? 0, forKey: Key.startDate)
        defaults.set(accumulated, forKey: Key.accumulated)
        defaults.set(laps, forKey: Key.laps)
    }
}

extension WatchStopwatchStore {
    /// `interval` in figures as the iPhone's stopwatch shows it: minutes,
    /// seconds and hundredths, with the hours before them from the first
    /// hour. Without its seconds, they show as dashes, and the hundredths go.
    static func figures(for interval: TimeInterval, showsSeconds: Bool = true) -> String {
        let hundredths = Int((max(interval, 0) * 100).rounded(.down))
        let seconds = hundredths / 100
        let hours = seconds / 3600
        let minutesAndSeconds = showsSeconds
            ? String(format: "%02d:%02d.%02d", seconds / 60 % 60, seconds % 60, hundredths % 100)
            : String(format: "%02d:--", seconds / 60 % 60)
        return hours > 0 ? "\(hours):\(minutesAndSeconds)" : minutesAndSeconds
    }
}
