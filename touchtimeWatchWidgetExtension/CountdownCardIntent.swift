//
//  CountdownCardIntent.swift
//  touchtimeWatchWidgetExtension
//
//  The Countdown widget's countdown: one of those the watch app lists.
//

import AppIntents

struct CountdownEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Countdown")
    static let defaultQuery = CountdownQuery()

    /// The countdown's `WatchCountdown.id`.
    let id: UUID
    let title: String

    init(_ countdown: WatchCountdown) {
        id = countdown.id
        title = countdown.title
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct CountdownQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [CountdownEntity] {
        let countdowns = WatchWidgetStore.countdowns
        return identifiers.compactMap { id in
            countdowns.first { $0.id == id }.map { CountdownEntity($0) }
        }
    }

    @MainActor
    func suggestedEntities() async throws -> [CountdownEntity] {
        WatchWidgetStore.countdowns.map { CountdownEntity($0) }
    }

    /// The iPhone's first countdown, until another is picked.
    @MainActor
    func defaultResult() async -> CountdownEntity? {
        WatchWidgetStore.countdowns.first.map { CountdownEntity($0) }
    }
}

struct CountdownCardIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Countdown"
    static let description = IntentDescription("Choose a countdown to display.")

    @Parameter(title: "Countdown")
    var countdown: CountdownEntity?

    init() {}
}
