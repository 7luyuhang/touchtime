//
//  touchtimeApp.swift
//  touchtime
//
//  Created by yuhang on 23/09/2025.
//

import SwiftUI
import TipKit

@main
struct touchtimeApp: App {
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    init() {
        // Initialize TipKit
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }
    
    var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil // System default
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(preferredColorScheme)
        }
    }
}
