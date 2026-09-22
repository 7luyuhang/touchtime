//
//  ScrollTimeQuickAction.swift
//  touchtime
//
//  Created on 22/09/2026.
//

import Foundation

/// The tools that can appear as quick actions when the time slider
/// (ScrollTimeView) is double-tapped. The user picks 1–3 of them in
/// Settings → Custom Quick Actions; the close button is always appended.
enum ScrollTimeQuickAction: String, CaseIterable, Identifiable {
    case alarm
    case timer
    case stopwatch
    case countdown

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .alarm:
            return "alarm"
        case .timer:
            return "timer"
        case .stopwatch:
            return "stopwatch"
        case .countdown:
            return "hourglass"
        }
    }

    var localizedName: String {
        switch self {
        case .alarm:
            return String(localized: "Alarm")
        case .timer:
            return String(localized: "Timer")
        case .stopwatch:
            return String(localized: "Stopwatch")
        case .countdown:
            return String(localized: "Countdown")
        }
    }

    // MARK: - Persistence

    /// UserDefaults key. The selection is stored as a comma-separated list of
    /// raw values in the user's chosen order (same scheme as the hourly chime cities).
    static let storageKey = "scrollTimeQuickActions"
    static let defaultSelection: [ScrollTimeQuickAction] = [.alarm, .timer, .countdown]
    static let minSelectionCount = 1
    static let maxSelectionCount = 3

    /// Decodes a stored selection. Unknown values are dropped, duplicates
    /// collapsed and the result capped at `maxSelectionCount`; when nothing
    /// valid remains (e.g. never customised) the default set is returned.
    static func selection(from storageString: String) -> [ScrollTimeQuickAction] {
        var seen = Set<ScrollTimeQuickAction>()
        let actions = storageString
            .split(separator: ",")
            .compactMap { ScrollTimeQuickAction(rawValue: String($0)) }
            .filter { seen.insert($0).inserted }
            .prefix(maxSelectionCount)
        return actions.isEmpty ? defaultSelection : Array(actions)
    }

    static func storageString(for selection: [ScrollTimeQuickAction]) -> String {
        selection.map(\.rawValue).joined(separator: ",")
    }
}
