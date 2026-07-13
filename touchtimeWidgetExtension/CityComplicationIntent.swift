//
//  CityComplicationIntent.swift
//  touchtimeWidgetExtension
//
//  Widget configuration: pick a city and a complication to display.
//

import AppIntents
import WidgetKit

// Complications available in the widget (only ones that don't need live weather data)
enum WidgetComplicationKind: String, AppEnum {
    case analogClock
    case sunPosition
    case sunriseSunset
    case sunAzimuth
    case solarCurve

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Complication")

    static let caseDisplayRepresentations: [WidgetComplicationKind: DisplayRepresentation] = [
        .analogClock: "Analog Clock",
        .sunPosition: "Sun Elevation",
        .sunriseSunset: "Sunrise & Sunset",
        .sunAzimuth: "Sun Azimuth",
        .solarCurve: "Solar Curve"
    ]
}

struct CityEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "City")
    static let defaultQuery = CityQuery()

    // Stable id: "<cityName>|<timeZoneIdentifier>"
    var id: String
    var cityName: String
    var timeZoneIdentifier: String

    init(id: String, cityName: String, timeZoneIdentifier: String) {
        self.id = id
        self.cityName = cityName
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    init(clock: WorldClock) {
        self.init(
            id: "\(clock.cityName)|\(clock.timeZoneIdentifier)",
            cityName: clock.localizedCityName,
            timeZoneIdentifier: clock.timeZoneIdentifier
        )
    }

    // Reconstruct from a stored id when the city no longer exists in saved clocks
    init?(id: String) {
        let parts = id.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        self.init(id: id, cityName: parts[0], timeZoneIdentifier: parts[1])
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(cityName)")
    }
}

struct CityQuery: EntityQuery {
    private func allCities() -> [CityEntity] {
        SharedWidgetStore.loadWorldClocks().map { CityEntity(clock: $0) }
    }

    func entities(for identifiers: [String]) async throws -> [CityEntity] {
        let cities = allCities()
        return identifiers.compactMap { id in
            cities.first { $0.id == id } ?? CityEntity(id: id)
        }
    }

    func suggestedEntities() async throws -> [CityEntity] {
        allCities()
    }

    func defaultResult() async -> CityEntity? {
        allCities().first
    }
}

struct CityComplicationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "City Time"
    static let description = IntentDescription("Choose a city and a complication to display.")

    @Parameter(title: "City")
    var city: CityEntity?

    @Parameter(title: "Complication", default: .sunriseSunset)
    var complication: WidgetComplicationKind
}
