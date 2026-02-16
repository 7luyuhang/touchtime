//
//  CollectionsStore.swift
//  touchtime
//
//  Shared persistence helpers for city collections.
//

import Foundation

enum CollectionsStore {
    private static let collectionsKey = "savedCityCollections"
    
    static func load() -> [CityCollection] {
        guard let data = UserDefaults.standard.data(forKey: collectionsKey),
              let decoded = try? JSONDecoder().decode([CityCollection].self, from: data) else {
            return []
        }
        return decoded
    }
    
    static func save(_ collections: [CityCollection]) {
        guard let encoded = try? JSONEncoder().encode(collections) else { return }
        UserDefaults.standard.set(encoded, forKey: collectionsKey)
    }
    
    static func removeCity(withId cityId: UUID) {
        var collections = load()
        var didChange = false
        
        for index in collections.indices {
            let countBefore = collections[index].cities.count
            collections[index].cities.removeAll { $0.id == cityId }
            if collections[index].cities.count != countBefore {
                didChange = true
            }
        }
        
        if didChange {
            save(collections)
        }
    }
    
    static func renameCity(withId cityId: UUID, to newName: String) {
        var collections = load()
        var didChange = false
        
        for collectionIndex in collections.indices {
            if let cityIndex = collections[collectionIndex].cities.firstIndex(where: { $0.id == cityId }) {
                collections[collectionIndex].cities[cityIndex].cityName = newName
                didChange = true
            }
        }
        
        if didChange {
            save(collections)
        }
    }
}
