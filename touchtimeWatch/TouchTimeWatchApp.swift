//
//  TouchTimeWatchApp.swift
//  touchtimeWatch
//

import SwiftUI
import TipKit

@main
struct TouchTimeWatchApp: App {
    @State private var cityStore = WatchCityStore()
    @State private var weatherStore = WatchWeatherStore()
    @State private var timerStore = WatchTimerStore()
    @State private var stopwatchStore = WatchStopwatchStore()

    init() {
        // Settings changed by a version without the widget
        WatchWidgetStore.saveSettings()
        try? Tips.configure()
    }

    var body: some Scene {
        WindowGroup {
            WorldClockView()
                .environment(cityStore)
                .environment(weatherStore)
                .environment(timerStore)
                .environment(stopwatchStore)
        }
    }
}
