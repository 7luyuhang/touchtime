//
//  CountdownStore.swift
//  touchtime
//
//  Shared storage for countdown events.
//

import Foundation
import Observation

/// A countdown towards a future date, shown in the countdown grid.
struct CountdownItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var targetDate: Date
    let createdAt: Date
    var isPinned: Bool
    var emoji: String?

    init(id: UUID, title: String, targetDate: Date, createdAt: Date, isPinned: Bool = false, emoji: String? = nil) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.emoji = emoji
    }

    // Items saved before pinning/emoji existed are missing those keys.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        targetDate = try container.decode(Date.self, forKey: .targetDate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji)
    }
}

/// Single source of truth for countdowns, created once at the app root and
/// shared through the environment. Every mutation notifies all observing
/// views (e.g. the Home cards update live while the countdown sheet is up)
/// and is persisted to UserDefaults automatically.
@Observable
final class CountdownStore {
    private static let storageKey = "savedCountdowns"

    var countdowns: [CountdownItem] {
        didSet { Self.persist(countdowns) }
    }

    init() {
        countdowns = Self.load()
    }

    private static func load() -> [CountdownItem] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([CountdownItem].self, from: data) else {
            return []
        }
        return items
    }

    private static func persist(_ items: [CountdownItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
