//
//  TouchTimeWatchApp.swift
//  touchtimeWatch
//

import SwiftUI

@main
struct TouchTimeWatchApp: App {
    @State private var cityStore = WatchCityStore()
    @State private var weatherStore = WatchWeatherStore()
    @State private var timerStore = WatchTimerStore()

    var body: some Scene {
        WindowGroup {
            WorldClockView()
                .environment(cityStore)
                .environment(weatherStore)
                .environment(timerStore)
        }
    }
}
