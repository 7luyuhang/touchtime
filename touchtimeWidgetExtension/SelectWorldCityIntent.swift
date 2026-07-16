//
//  SelectWorldCityIntent.swift
//  touchtimeWidgetExtension
//
//  Runs when a city column is tapped in the medium widget: remembers the
//  choice in the shared container so the reloaded timeline repaints the
//  background with that city's sky colours.
//

import AppIntents
import WidgetKit

struct SelectWorldCityIntent: AppIntent {
    static let title: LocalizedStringResource = "Select City"
    static let description = IntentDescription("Shows the tapped city's sky as the widget background.")
    static let isDiscoverable = false

    @Parameter(title: "City")
    var cityId: String

    init() {}

    init(cityId: String) {
        self.cityId = cityId
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        SharedWidgetStore.setWorldCitiesSelectedCityId(cityId)
        // The tapped widget reloads automatically; reload the kind so any
        // other instances of this widget stay in sync too.
        WidgetCenter.shared.reloadTimelines(ofKind: WorldCitiesWidget.kind)
        return .result()
    }
}
