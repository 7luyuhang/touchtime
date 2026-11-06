//
//  CityListPage.swift
//  touchtimeWatch
//

import Foundation

/// One page of the city list: every city, or one of the iPhone's collections,
/// each led by the watch's own time zone.
struct CityListPage: Identifiable {
    /// Every city's page, the first.
    static let allCitiesID = ""

    /// `allCitiesID`, or the collection's.
    let id: String
    /// The collection's name, or nil on every city's page.
    let title: String?
    let cities: [ClockCity]

    private init(id: String, title: String?, cities: [WatchCity]) {
        self.id = id
        self.title = title
        self.cities = [ClockCity.local] + cities.map { ClockCity($0) }
    }

    /// Every city's page, then a page for each collection, in the iPhone's order.
    static func pages(cities: [WatchCity], collections: [WatchCollection]) -> [CityListPage] {
        [CityListPage(id: allCitiesID, title: nil, cities: cities)]
            + collections.map { CityListPage(id: $0.id.uuidString, title: $0.name, cities: $0.cities) }
    }
}
