//
//  ClockCity.swift
//  touchtimeWatch
//

import Foundation

/// One clock on the watch: its own time zone, or one of the iPhone's saved
/// cities.
struct ClockCity: Identifiable, Hashable {
    static let localID = "local"

    static let local = ClockCity(id: localID, name: String(localized: "Local"), timeZoneIdentifier: nil)

    let id: String
    let name: String
    /// Nil for the watch's own time zone, which follows the watch around.
    private let timeZoneIdentifier: String?

    init(_ city: WatchCity) {
        self.init(id: city.id.uuidString, name: city.name, timeZoneIdentifier: city.timeZoneIdentifier)
    }

    private init(id: String, name: String, timeZoneIdentifier: String?) {
        self.id = id
        self.name = name
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    var isLocal: Bool {
        timeZoneIdentifier == nil
    }

    var timeZone: TimeZone {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .autoupdatingCurrent
    }
}
