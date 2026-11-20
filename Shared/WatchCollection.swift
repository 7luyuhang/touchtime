//
//  WatchCollection.swift
//  touchtime
//
//  The collections the iPhone app sends to the Apple Watch app over
//  WatchConnectivity.
//

import Foundation

/// A collection as the watch pages through it: its name, and the cities the
/// iPhone's list shows while it's selected.
struct WatchCollection: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let cities: [WatchCity]
}
