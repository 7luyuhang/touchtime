//
//  CityCollection.swift
//  touchtime
//
//  Created on 12/11/2025.
//

import Foundation

struct CityCollection: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var cities: [WorldClock]
    /// Pinned countdowns added to the collection, by ID. Countdowns live in
    /// `CountdownStore`, so only their identity is kept here and the views
    /// resolve it against the store; Home shows the ones that are still
    /// pinned when the collection is selected.
    var countdownIds: [UUID]
    
    init(name: String, cities: [WorldClock] = [], countdownIds: [UUID] = []) {
        self.id = UUID()
        self.name = name
        self.cities = cities
        self.countdownIds = countdownIds
    }
    
    // Collections saved before countdowns could be added are missing the key.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        cities = try container.decode([WorldClock].self, forKey: .cities)
        countdownIds = try container.decodeIfPresent([UUID].self, forKey: .countdownIds) ?? []
    }
    
    /// Whether the countdown has been added to this collection.
    func contains(countdownId: UUID) -> Bool {
        countdownIds.contains(countdownId)
    }
}
