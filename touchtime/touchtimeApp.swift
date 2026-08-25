//
//  touchtimeApp.swift
//  touchtime
//
//  Created by yuhang on 23/09/2025.
//

import SwiftUI
import TipKit
import UIKit
import WidgetKit

@main
struct touchtimeApp: App {
    // Captures Home Screen quick actions (Set Alarm / Set Timer)
    @UIApplicationDelegateAdaptor(QuickActionsAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    // Shared countdown source of truth; injected app-wide so the Home
    // cards and the countdown sheet always observe the same data.
    @State private var countdownStore = CountdownStore()

    init() {
        // Initialize TipKit
        try? Tips.configure([
            .displayFrequency(.daily),
            .datastoreLocation(.applicationDefault)
        ])
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(countdownStore)
                .environment(\.colorScheme, .dark) // Force dark theme
                .onAppear {
                    // Force dark mode for all windows when app appears
                    DispatchQueue.main.async {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            windowScene.windows.forEach { window in
                                window.overrideUserInterfaceStyle = .dark
                            }
                        }
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Keep the rolling 24-hour window of on-the-hour notifications topped up,
            // and turn the toggle off if permission was revoked in system Settings
            if newPhase == .active {
                HourlyNotificationManager.shared.syncEnabledWithAuthorization()
                HourlyNotificationManager.shared.reschedule()
                SharedWidgetStore.syncFromApp()
            } else if newPhase == .background {
                // Keep the widget's city list and time format up to date
                SharedWidgetStore.syncFromApp()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
