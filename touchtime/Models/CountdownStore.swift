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
