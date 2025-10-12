//
//  touchtimeApp.swift
//  touchtime
//
//  Created by yuhang on 23/09/2025.
//

import SwiftUI
import TipKit
import UIKit

// Custom UIHostingController to force dark mode
class DarkModeHostingController<Content: View>: UIHostingController<Content> {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Force dark mode for this view controller
        overrideUserInterfaceStyle = .dark
    }
}

@main
struct touchtimeApp: App {
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
    }
}
