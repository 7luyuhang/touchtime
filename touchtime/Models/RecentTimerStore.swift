//
//  RecentTimerStore.swift
//  touchtime
//
//  Shared storage for recently started timers.
//

import Foundation

/// A previously started timer, shown in the timer sheet's Recents list.
struct RecentTimer: Identifiable, Codable, Equatable {
    let id: UUID
    let durationSeconds: Int
    var name: String?
    let lastUsedAt: Date
}

/// Persists recently started timers in UserDefaults, most recently used first.
enum RecentTimerStore {
    private static let storageKey = "recentTimers"
    private static let maxCount = 24

    static func load() -> [RecentTimer] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let timers = try? JSONDecoder().decode([RecentTimer].self, from: data) else {
            return []
        }
        return timers.sorted { $0.lastUsedAt > $1.lastUsedAt }
    }

    static func save(_ timers: [RecentTimer]) {
        guard let data = try? JSONEncoder().encode(timers) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// Inserts a started timer at the front, keeping duration + name unique
    /// and capping the history size. Returns the updated list.
    @discardableResult
    static func remember(durationSeconds: Int, name: String?) -> [RecentTimer] {
        guard durationSeconds > 0 else { return load() }

        var timers = load().filter {
            !($0.durationSeconds == durationSeconds && $0.name == name)
        }
        timers.insert(
            RecentTimer(id: UUID(), durationSeconds: durationSeconds, name: name, lastUsedAt: Date()),
            at: 0
        )
        if timers.count > maxCount {
            timers = Array(timers.prefix(maxCount))
        }
        save(timers)
        return timers
    }

    /// Renames the most recent entry matching the given duration and name.
    /// Used to keep Recents in sync when the running home timer is renamed.
    static func renameMatching(durationSeconds: Int, oldName: String?, newName: String?) {
        guard durationSeconds > 0, oldName != newName else { return }

        var timers = load()
        guard let index = timers.firstIndex(where: {
            $0.durationSeconds == durationSeconds && $0.name == oldName
        }) else { return }

        let renamedID = timers[index].id
        timers[index].name = newName
        // Keep duration + name unique, matching insert behaviour
        timers.removeAll {
            $0.id != renamedID && $0.durationSeconds == durationSeconds && $0.name == newName
        }
        save(timers)
    }

    /// Trims whitespace; empty names are stored as nil.
    static func normalizedName(_ name: String?) -> String? {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
