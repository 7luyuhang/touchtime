//
//  TouchTimeWatchApp.swift
//  touchtimeWatch
//

import SwiftUI

@main
struct TouchTimeWatchApp: App {
    @State private var cityStore = WatchCityStore()

    var body: some Scene {
        WindowGroup {
            WorldClockView()
                .environment(cityStore)
        }
    }
}
