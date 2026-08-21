//
//  CountdownStore.swift
//  touchtime
//
//  Shared storage for countdown events.
//

import Foundation

/// A countdown towards a future date, shown in the countdown grid.
struct CountdownItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var targetDate: Date
    let createdAt: Date
    var isPinned: Bool

    init(id: UUID, title: String, targetDate: Date, createdAt: Date, isPinned: Bool = false) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.createdAt = createdAt
        self.isPinned = isPinned
    }

    // Items saved before pinning existed have no `isPinned` key.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        targetDate = try container.decode(Date.self, forKey: .targetDate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}

/// Persists countdowns in UserDefaults.
enum CountdownStore {
    private static let storageKey = "savedCountdowns"

    static func load() -> [CountdownItem] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([CountdownItem].self, from: data) else {
            return []
        }
        return items
    }

    static func save(_ items: [CountdownItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
