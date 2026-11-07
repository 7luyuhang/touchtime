//
//  TouchTimeWatchApp.swift
//  touchtimeWatch
//

import SwiftUI

@main
struct TouchTimeWatchApp: App {
    @State private var cityStore = WatchCityStore()
    @State private var weatherStore = WatchWeatherStore()

    var body: some Scene {
        WindowGroup {
            WorldClockView()
                .environment(cityStore)
                .environment(weatherStore)
        }
    }
}
