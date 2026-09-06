//
//  QuickActionsManager.swift
//  touchtime
//
//  Created by yuhang on 10/08/2026.
//

import SwiftUI
import Combine
import UIKit

/// Quick-action destinations, reached from the Home Screen icon menu
/// or the Spotlight App Shortcuts (see AppShortcuts.swift).
enum QuickAction: String {
    case setAlarm = "com.time.touchtime.setAlarm"
    case setTimer = "com.time.touchtime.setTimer"
    case countdown = "com.time.touchtime.countdown"

    init?(shortcutItem: UIApplicationShortcutItem) {
        self.init(rawValue: shortcutItem.type)
    }
}

extension Notification.Name {
    /// Posted by ContentView after routing a quick action; HomeView opens the matching sheet.
    static let quickActionSetAlarm = Notification.Name("QuickActionSetAlarm")
    static let quickActionSetTimer = Notification.Name("QuickActionSetTimer")
    static let quickActionCountdown = Notification.Name("QuickActionCountdown")
}

/// Bridges Home Screen quick actions from UIKit into the SwiftUI hierarchy.
final class QuickActionsManager: ObservableObject {
    static let shared = QuickActionsManager()

    /// Set when the app is launched or resumed via a quick action,
    /// consumed by ContentView once the tab bar is on screen.
    @Published var pendingAction: QuickAction?

    private init() {}
}

/// Captures the quick action when the app is cold-launched from the icon menu,
/// and installs the scene delegate that receives them while running.
final class QuickActionsAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem,
           let action = QuickAction(shortcutItem: shortcutItem) {
            QuickActionsManager.shared.pendingAction = action
        }

        let configuration = UISceneConfiguration(
            name: connectingSceneSession.configuration.name,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = QuickActionsSceneDelegate.self
        return configuration
    }
}

/// Receives the quick action when the app is already running in the background.
final class QuickActionsSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let action = QuickAction(shortcutItem: shortcutItem) else {
            completionHandler(false)
            return
        }
        QuickActionsManager.shared.pendingAction = action
        completionHandler(true)
    }
}
