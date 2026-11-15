//
//  CountdownListFilter.swift
//  touchtimeWatch
//

import SwiftUI

/// Which of the iPhone's countdowns the countdowns page shows: those pinned
/// to Home on the iPhone, or all of them.
enum CountdownListFilter: String, CaseIterable, Identifiable {
    case pinned
    case all

    /// The watch app's Countdowns View setting.
    static let storageKey = "countdownListFilter"

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .pinned: "Pinned"
        case .all: "All"
        }
    }

    /// The ones of `countdowns` the page shows, in the same order.
    func apply(to countdowns: [WatchCountdown]) -> [WatchCountdown] {
        switch self {
        case .pinned: countdowns.filter(\.isPinned)
        case .all: countdowns
        }
    }
}
