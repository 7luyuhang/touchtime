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
    private static let pinnedOrderKey = "pinnedCountdownOrder"

    var countdowns: [CountdownItem] {
        didSet {
            Self.persist(countdowns)
            // Keep pending reminder notifications in step with every mutation.
            CountdownReminderManager.shared.reschedule(for: countdowns)
            // Deleted countdowns take their space attachments with them.
            CountdownSpaceStore.shared.prune(keeping: countdowns.map(\.id))
            // ...and leave the collections they were added to.
            CollectionsStore.pruneCountdowns(keeping: countdowns.map(\.id))
            // Unpinned and deleted countdowns give up their arranged spot,
            // so pinning one again lines it up after the arranged ones.
            let pinnedIds = Set(countdowns.filter(\.isPinned).map(\.id))
            let keptOrder = pinnedOrder.filter { pinnedIds.contains($0) }
            if keptOrder != pinnedOrder {
                pinnedOrder = keptOrder
            }
        }
    }

    /// Pinned countdown IDs in the order they were dragged into in Arrange,
    /// which Home lays its countdown cards out in (see `pinnedCountdowns(at:)`).
    var pinnedOrder: [UUID] {
        didSet {
            UserDefaults.standard.set(pinnedOrder.map(\.uuidString), forKey: Self.pinnedOrderKey)
        }
    }

    init() {
        countdowns = Self.load()
        pinnedOrder = (UserDefaults.standard.stringArray(forKey: Self.pinnedOrderKey) ?? [])
            .compactMap(UUID.init(uuidString:))
    }

    /// Pinned countdowns in Home's card order: the arranged ones first, then
    /// any not arranged yet (pinned since the last drag, or all of them
    /// before the first) by their next target date.
    func pinnedCountdowns(at now: Date) -> [CountdownItem] {
        let pinned = countdowns.filter(\.isPinned)
        let arranged = pinnedOrder.compactMap { id in
            pinned.first { $0.id == id }
        }
        let unarranged = pinned
            .filter { !pinnedOrder.contains($0.id) }
            .sorted { $0.effectiveTargetDate(at: now) < $1.effectiveTargetDate(at: now) }
        return arranged + unarranged
    }

    private static func load() -> [CountdownItem] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([CountdownItem].self, from: data) else {
            return []
        }
        return withDefaultCovers(items)
    }

    /// Countdowns saved before covers became mandatory get a random emoji,
    /// like new ones do in the editor. Written straight back (`didSet`
    /// doesn't run for the initial assignment) so the Home cards and the
    /// widget's App Group copy pick the covers up without waiting for an
    /// edit.
    private static func withDefaultCovers(_ items: [CountdownItem]) -> [CountdownItem] {
        let covered = items.map { item in
            guard item.emoji == nil, item.photoData == nil else { return item }
            var item = item
            item.emoji = CountdownCoverEmojis.random
            return item
        }
        if covered != items {
            persist(covered)
        }
        return covered
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
