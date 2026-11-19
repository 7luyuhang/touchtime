//
//  CityCardIntent.swift
//  touchtimeWatchWidgetExtension
//
//  The City Time widget's city: one of the clocks the watch app lists.
//

import AppIntents

struct ClockCityEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "City")
    static let defaultQuery = ClockCityQuery()

    /// The clock's `ClockCity.id`.
    let id: String
    let name: String

    init(_ city: ClockCity) {
        id = city.id
        name = city.name
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct ClockCityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [ClockCityEntity] {
        let cities = WatchWidgetStore.cities
        return identifiers.compactMap { id in
            cities.first { $0.id == id }.map { ClockCityEntity($0) }
        }
    }

    @MainActor
    func suggestedEntities() async throws -> [ClockCityEntity] {
        WatchWidgetStore.cities.map { ClockCityEntity($0) }
    }

    /// The watch's own clock, until another city is picked.
    @MainActor
    func defaultResult() async -> ClockCityEntity? {
        ClockCityEntity(.local)
    }
}

struct CityCardIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "City Time"
    static let description = IntentDescription("Choose a city to display.")

    @Parameter(title: "City")
    var city: ClockCityEntity?

    init() {}
}
