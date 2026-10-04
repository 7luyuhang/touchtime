//
//  TouchTimeLiveActivityIntents.swift
//  touchtime
//
//  The buttons of the timer and stopwatch Live Activities.
//

import AppIntents

/// What a Live Activity button asks of the Home timer or stopwatch.
enum LiveActivityAction {
    case toggleTimer
    case cancelTimer
    case toggleStopwatch
    case lapOrResetStopwatch
}

/// The system runs Live Activity intents in the app's process, never in the
/// widget extension, so the app sets `perform` when it launches.
@MainActor
enum LiveActivityActionRouter {
    static var perform: (@MainActor (LiveActivityAction) async -> Void)?
}

/// Pause / Resume, or Start again once the timer has finished.
struct TimerPlayPauseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or Resume Timer"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await LiveActivityActionRouter.perform?(.toggleTimer)
        return .result()
    }
}

/// Cancels the timer, taking it off Home like Delete on its card.
struct TimerCancelIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cancel Timer"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await LiveActivityActionRouter.perform?(.cancelTimer)
        return .result()
    }
}

/// Start / Stop.
struct StopwatchPlayPauseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start or Stop Stopwatch"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await LiveActivityActionRouter.perform?(.toggleStopwatch)
        return .result()
    }
}

/// Lap while running, Reset once stopped.
struct StopwatchLapResetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Lap or Reset Stopwatch"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await LiveActivityActionRouter.perform?(.lapOrResetStopwatch)
        return .result()
    }
}
