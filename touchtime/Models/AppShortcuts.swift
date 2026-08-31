//
//  AppShortcuts.swift
//  touchtime
//
//  Created by yuhang on 31/08/2026.
//

import AppIntents

/// Opens the alarms sheet. Exposed as an App Shortcut so it shows up
/// as a quick action when searching for the app in Spotlight.
struct OpenAlarmsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Alarms"
    static let description = IntentDescription("Opens the alarms in Touch Time.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickActionsManager.shared.pendingAction = .setAlarm
        return .result()
    }
}

/// Opens the timer sheet from Spotlight, Siri, or the Shortcuts app.
struct OpenTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Timer"
    static let description = IntentDescription("Opens the timer in Touch Time.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickActionsManager.shared.pendingAction = .setTimer
        return .result()
    }
}

/// Opens the countdown sheet from Spotlight, Siri, or the Shortcuts app.
struct OpenCountdownIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Countdown"
    static let description = IntentDescription("Opens the countdowns in Touch Time.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickActionsManager.shared.pendingAction = .countdown
        return .result()
    }
}

/// Surfaces Alarms / Timer / Countdown as quick actions under the app
/// in Spotlight search results (also available via Siri and Shortcuts).
/// Phrase translations live in AppShortcuts.xcstrings.
struct TouchTimeAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenAlarmsIntent(),
            phrases: [
                "Open alarms in \(.applicationName)",
                "Show my \(.applicationName) alarms"
            ],
            shortTitle: "Alarms",
            systemImageName: "alarm"
        )
        AppShortcut(
            intent: OpenTimerIntent(),
            phrases: [
                "Open the timer in \(.applicationName)",
                "Set a timer in \(.applicationName)"
            ],
            shortTitle: "Timer",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: OpenCountdownIntent(),
            phrases: [
                "Open countdowns in \(.applicationName)",
                "Show my \(.applicationName) countdowns"
            ],
            shortTitle: "Countdown",
            systemImageName: "hourglass"
        )
    }
}
