//
//  HomeTimerSnapshot.swift
//  touchtime
//
//  The Home timer as persisted in UserDefaults.
//

import Foundation

/// The Home timer as persisted under the keys the timer views keep in
/// `@AppStorage`, for code that runs without those views: the timer's alarm,
/// its Live Activity and the Live Activity buttons.
struct HomeTimerSnapshot {
    /// The timer runs for at most 59:59.
    static let maxSeconds = 59 * 60 + 59

    private enum Key {
        static let configuredSeconds = "homeTimerConfiguredSeconds"
        static let endDateEpoch = "homeTimerEndDateEpoch"
        static let isPaused = "homeTimerPaused"
        static let pausedRemainingSeconds = "homeTimerPausedRemainingSeconds"
        static let name = "homeTimerName"
        static let completionHandled = "homeTimerCompletionHandled"
    }

    var configuredSeconds: Int
    /// Unix epoch of the moment the running timer ends; 0 while paused.
    var endDateEpoch: Double
    var isPaused: Bool
    var pausedRemainingSeconds: Int
    var name: String
    /// Set once the current run has been counted towards Timer Recents.
    var completionHandled: Bool

    init(defaults: UserDefaults = .standard) {
        configuredSeconds = defaults.integer(forKey: Key.configuredSeconds)
        endDateEpoch = defaults.double(forKey: Key.endDateEpoch)
        isPaused = defaults.bool(forKey: Key.isPaused)
        pausedRemainingSeconds = defaults.integer(forKey: Key.pausedRemainingSeconds)
        name = defaults.string(forKey: Key.name) ?? ""
        completionHandled = defaults.bool(forKey: Key.completionHandled)
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(configuredSeconds, forKey: Key.configuredSeconds)
        defaults.set(endDateEpoch, forKey: Key.endDateEpoch)
        defaults.set(isPaused, forKey: Key.isPaused)
        defaults.set(pausedRemainingSeconds, forKey: Key.pausedRemainingSeconds)
        defaults.set(name, forKey: Key.name)
        defaults.set(completionHandled, forKey: Key.completionHandled)
    }

    var isConfigured: Bool {
        configuredSeconds > 0
    }

    var clampedConfiguredSeconds: Int {
        min(max(configuredSeconds, 0), Self.maxSeconds)
    }

    /// The trimmed name, or "Timer" when there is none.
    var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? String(localized: "Timer") : trimmedName
    }

    /// When the timer rings; nil unless it is counting down.
    var runningEndDate: Date? {
        guard isConfigured, !isPaused, endDateEpoch > 0 else { return nil }
        return Date(timeIntervalSince1970: endDateEpoch)
    }

    func remainingSeconds(at date: Date) -> Int {
        guard isConfigured else { return 0 }

        if isPaused {
            return max(0, min(pausedRemainingSeconds, Self.maxSeconds))
        }

        guard let endDate = runningEndDate else { return 0 }
        return max(Int(ceil(endDate.timeIntervalSince(date))), 0)
    }

    /// Counted down to zero, and not restarted since.
    func isFinished(at date: Date) -> Bool {
        isConfigured && !isPaused && remainingSeconds(at: date) == 0
    }

    // MARK: - Transitions

    /// Pause / Resume, or Start again once finished; the same steps as
    /// tapping the timer card on Home.
    mutating func togglePlayPause(at now: Date) {
        guard isConfigured else { return }

        let remaining = remainingSeconds(at: now)
        if remaining == 0 {
            endDateEpoch = now.addingTimeInterval(TimeInterval(clampedConfiguredSeconds)).timeIntervalSince1970
            isPaused = false
            pausedRemainingSeconds = 0
            completionHandled = false
        } else if isPaused {
            let secondsToResume = max(1, min(pausedRemainingSeconds, Self.maxSeconds))
            endDateEpoch = now.addingTimeInterval(TimeInterval(secondsToResume)).timeIntervalSince1970
            isPaused = false
            pausedRemainingSeconds = 0
            completionHandled = false
        } else {
            pausedRemainingSeconds = remaining
            isPaused = true
            endDateEpoch = 0
        }
    }

    /// Takes the timer off Home, like Delete on its card.
    mutating func clear() {
        configuredSeconds = 0
        endDateEpoch = 0
        completionHandled = false
        isPaused = false
        pausedRemainingSeconds = 0
        name = ""
    }
}
