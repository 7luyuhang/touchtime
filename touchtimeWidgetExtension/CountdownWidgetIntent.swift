//
//  CountdownWidgetIntent.swift
//  touchtimeWidgetExtension
//
//  Widget configuration: pick one of the app's saved countdowns to display,
//  and whether its cover keeps its colours in the Clear and Tinted Home
//  Screen modes.
//

import AppIntents
import WidgetKit

struct CountdownEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Countdown")
    static let defaultQuery = CountdownQuery()

    // The countdown's UUID string; stable across edits in the app.
    var id: String
    var title: String

    init(item: CountdownItem) {
        id = item.id.uuidString
        title = item.title
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    /// The order countdowns are offered in (and the default when none is
    /// picked, or the picked one was deleted): pinned first, then upcoming
    /// ones nearest first, then past ones most recent first.
    static func widgetOrder(_ items: [CountdownItem], now: Date) -> [CountdownItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        // (unpinned, past, distance from today): lower sorts first.
        func rank(_ item: CountdownItem) -> (Int, Int, TimeInterval) {
            let target = calendar.startOfDay(for: item.effectiveTargetDate(at: now))
            let isPast = target < today
            return (item.isPinned ? 0 : 1, isPast ? 1 : 0, abs(target.timeIntervalSince(today)))
        }

        return items.sorted { rank($0) < rank($1) }
    }
}

struct CountdownQuery: EntityQuery {
    private func allCountdowns() -> [CountdownEntity] {
        CountdownEntity
            .widgetOrder(SharedWidgetStore.loadCountdowns(), now: Date())
            .map(CountdownEntity.init)
    }

    // A countdown deleted in the app simply drops out: unlike cities, its
    // title can't be rebuilt from the id, so the provider falls back to the
    // first countdown in widget order instead.
    func entities(for identifiers: [String]) async throws -> [CountdownEntity] {
        let countdowns = allCountdowns()
        return identifiers.compactMap { id in
            countdowns.first { $0.id == id }
        }
    }

    func suggestedEntities() async throws -> [CountdownEntity] {
        allCountdowns()
    }

    func defaultResult() async -> CountdownEntity? {
        allCountdowns().first
    }
}

struct CountdownWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Countdown"
    static let description = IntentDescription("Choose a countdown to display.")

    @Parameter(title: "Countdown")
    var countdown: CountdownEntity?

    /// In the Clear and Tinted Home Screen modes the cover photo or emoji
    /// is desaturated with the rest of the widget; this keeps it in colour.
    @Parameter(title: "Show in Full Color", default: false)
    var showCoverInFullColor: Bool
}
