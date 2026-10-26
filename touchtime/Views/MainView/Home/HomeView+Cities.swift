//
//  HomeView+Cities.swift
//  touchtime
//

import SwiftUI

extension HomeView {
    // Get local city name from timezone
    var localCityName: String {
        let identifier = TimeZone.current.identifier
        let components = identifier.split(separator: "/")
        let cityName: String
        if components.count >= 2 {
            cityName = components.last!.replacingOccurrences(of: "_", with: " ")
        } else {
            cityName = identifier
        }
        // Return localized city name
        return String(localized: String.LocalizationValue(cityName))
    }
    
    // Get original city name from timezone identifier
    func getOriginalCityName(from identifier: String) -> String {
        let components = identifier.split(separator: "/")
        if components.count >= 2 {
            return components.last!.replacingOccurrences(of: "_", with: " ")
        } else {
            return String(components[0])
        }
    }
    
    // Get localized city name for display (using WorldClock's localizedCityName property)
    func getLocalizedCityName(for clock: WorldClock) -> String {
        return clock.localizedCityName
    }
    
    // Get displayed clocks based on selected collection
    var displayedClocks: [WorldClock] {
        if let collectionId = selectedCollectionId,
           let collection = collections.first(where: { $0.id == collectionId }) {
            return collection.cities
        }
        return worldClocks // Default - show all cities
    }

    // Current collection name for display
    var currentCollectionName: String {
        if let collectionId = selectedCollectionId,
           let collection = collections.first(where: { $0.id == collectionId }) {
            return collection.name
        }
        return String(localized: "All Cities")
    }
    
    // Quick Switch Collections
    // Cycle to the next collection (Collection 1 -> Collection 2 -> ... -> Collection 1)
    func cycleToNextCollection() {
        guard !collections.isEmpty else { return }
        
        if let currentId = selectedCollectionId,
           let currentIndex = collections.firstIndex(where: { $0.id == currentId }) {
            // Currently on a collection, go to the next one or wrap to first
            let nextIndex = (currentIndex + 1) % collections.count
            selectedCollectionId = collections[nextIndex].id
        } else {
            // Currently on All Cities, go to the first collection
            selectedCollectionId = collections.first?.id
        }
        
        saveSelectedCollection()
        
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    // Load collections from UserDefaults
    func loadCollections() {
        if let data = UserDefaults.standard.data(forKey: collectionsKey),
           let decoded = try? JSONDecoder().decode([CityCollection].self, from: data) {
            collections = decoded
        } else {
            // Clear collections if no data in UserDefaults
            collections = []
        }
        
        // Load saved selection
        if !savedSelectedCollectionId.isEmpty,
           let uuid = UUID(uuidString: savedSelectedCollectionId) {
            selectedCollectionId = uuid
        } else {
            // Clear selection if no saved ID
            selectedCollectionId = nil
        }
    }
    
    // Save selected collection
    func saveSelectedCollection() {
        savedSelectedCollectionId = selectedCollectionId?.uuidString ?? ""
    }
    
    // Save collections to UserDefaults
    func saveCollections() {
        if let encoded = try? JSONEncoder().encode(collections) {
            UserDefaults.standard.set(encoded, forKey: collectionsKey)
        }
    }

    // Save world clocks to UserDefaults
    func saveWorldClocks() {
        if let encoded = try? JSONEncoder().encode(worldClocks) {
            UserDefaults.standard.set(encoded, forKey: worldClocksKey)
        }
    }

    // Restore the most recently deleted city (if any)
    func restoreLastDeletedCity() {
        guard let snapshot = recentlyDeletedCity else { return }

        // If this city already exists again, clear stale snapshot and exit.
        guard !worldClocks.contains(where: { $0.id == snapshot.clock.id }) else {
            recentlyDeletedCity = nil
            return
        }

        let worldInsertIndex = min(snapshot.worldClockIndex, worldClocks.count)
        worldClocks.insert(snapshot.clock, at: worldInsertIndex)
        saveWorldClocks()

        for position in snapshot.collectionPositions {
            guard let collectionIndex = collections.firstIndex(where: { $0.id == position.collectionId }) else {
                continue
            }
            guard !collections[collectionIndex].cities.contains(where: { $0.id == snapshot.clock.id }) else {
                continue
            }

            let cityInsertIndex = min(position.cityIndex, collections[collectionIndex].cities.count)
            collections[collectionIndex].cities.insert(snapshot.clock, at: cityInsertIndex)
        }
        saveCollections()

        recentlyDeletedCity = nil

        if hapticEnabled {
            let feedback = UINotificationFeedbackGenerator()
            feedback.prepare()
            feedback.notificationOccurred(.success)
        }
    }
    
    // Delete city from both worldClocks and all collections
    func deleteCity(withId cityId: UUID) {
        guard let worldClockIndex = worldClocks.firstIndex(where: { $0.id == cityId }) else {
            return
        }

        let deletedClock = worldClocks.remove(at: worldClockIndex)
        var removedCollectionPositions: [DeletedCitySnapshot.CollectionPosition] = []

        for collectionIndex in collections.indices {
            if let cityIndex = collections[collectionIndex].cities.firstIndex(where: { $0.id == cityId }) {
                collections[collectionIndex].cities.remove(at: cityIndex)
                removedCollectionPositions.append(
                    .init(
                        collectionId: collections[collectionIndex].id,
                        cityIndex: cityIndex
                    )
                )
            }
        }

        recentlyDeletedCity = DeletedCitySnapshot(
            clock: deletedClock,
            worldClockIndex: worldClockIndex,
            collectionPositions: removedCollectionPositions
        )

        if !hasTriggeredShakeToResetTip {
            hasTriggeredShakeToResetTip = true
            showShakeToResetTip = true
        }

        saveWorldClocks()
        saveCollections()
    }
}
