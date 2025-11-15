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
    
    init(name: String, cities: [WorldClock] = []) {
        self.id = UUID()
        self.name = name
        self.cities = cities
    }
    
    static func == (lhs: CityCollection, rhs: CityCollection) -> Bool {
        return lhs.id == rhs.id
    }
}

