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
    /// How many times this timer has run all the way down to zero
    var usageCount: Int = 0
}

extension RecentTimer {
    // Entries saved before usage counts existed have no usageCount key;
    // decoding it as optional keeps them loading instead of wiping Recents.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        durationSeconds = try container.decode(Int.self, forKey: .durationSeconds)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        lastUsedAt = try container.decode(Date.self, forKey: .lastUsedAt)
        usageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0
    }
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

    /// Inserts a newly started timer at the front, capping the history size.
    /// Restarting a timer already in the list keeps it at its current
    /// position instead of moving it to the top. Returns the updated list.
    @discardableResult
    static func remember(durationSeconds: Int, name: String?) -> [RecentTimer] {
        guard durationSeconds > 0 else { return load() }

        var timers = load()
        if timers.contains(where: { $0.durationSeconds == durationSeconds && $0.name == name }) {
            return timers
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
        // Keep duration + name unique, matching insert behaviour. The
        // replaced duplicate's completed runs carry over to the renamed entry.
        let isReplacedDuplicate: (RecentTimer) -> Bool = {
            $0.id != renamedID && $0.durationSeconds == durationSeconds && $0.name == newName
        }
        timers[index].usageCount += timers.filter(isReplacedDuplicate).reduce(0) { $0 + $1.usageCount }
        timers.removeAll(where: isReplacedDuplicate)
        save(timers)
    }

    /// Counts one completed run for the entry matching the given duration and
    /// name. Called when the home timer runs all the way down to zero.
    static func recordCompletion(durationSeconds: Int, name: String?) {
        guard durationSeconds > 0 else { return }

        var timers = load()
        guard let index = timers.firstIndex(where: {
            $0.durationSeconds == durationSeconds && $0.name == name
        }) else { return }

        timers[index].usageCount += 1
        save(timers)
    }

    /// Trims whitespace; empty names are stored as nil.
    static func normalizedName(_ name: String?) -> String? {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
