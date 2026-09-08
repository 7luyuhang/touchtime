//
//  CountdownStore.swift
//  touchtime
//
//  Shared storage for countdown events. The CountdownItem model itself
//  lives in Shared/CountdownItem.swift so the widget extension can decode
//  the same data.
//

import Foundation
import Observation
import WidgetKit

/// Single source of truth for countdowns, created once at the app root and
/// shared through the environment. Every mutation notifies all observing
/// views (e.g. the Home cards update live while the countdown sheet is up)
/// and is persisted to UserDefaults automatically.
@Observable
final class CountdownStore {
    private static let storageKey = SharedWidgetStore.countdownsKey

    var countdowns: [CountdownItem] {
        didSet {
            Self.persist(countdowns)
            // Keep pending reminder notifications in step with every mutation.
            CountdownReminderManager.shared.reschedule(for: countdowns)
            // Deleted countdowns take their space attachments with them.
            CountdownSpaceStore.shared.prune(keeping: countdowns.map(\.id))
        }
    }

    init() {
        countdowns = Self.load()
    }

    private static func load() -> [CountdownItem] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([CountdownItem].self, from: data) else {
            return []
        }
        return items
    }

    private static func persist(_ items: [CountdownItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        // Mirror into the App Group and refresh the Countdown widget right
        // away, so an edit shows on the Home Screen without waiting for the
        // app to be backgrounded.
        SharedWidgetStore.saveCountdowns(data)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedWidgetStore.countdownWidgetKind)
    }
}
