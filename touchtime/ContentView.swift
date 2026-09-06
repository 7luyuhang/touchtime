//
//  ContentView.swift
//  touchtime
//
//  Created by yuhang on 23/09/2025.
//

import SwiftUI

struct ContentView: View {
    private enum MainTab: Hashable {
        case list
        case clock
        case search
    }

    @State private var selectedTab: MainTab = .list
    @State private var worldClocks: [WorldClock] = []
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @StateObject private var weatherManager = WeatherManager()
    
    // Shared time offset state for HomeView and AnalogClockFullView
    @State private var timeOffset: TimeInterval = 0
    @State private var listShowScrollTimeButtons = false
    @State private var clockShowScrollTimeButtons = false
    
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    // UserDefaults key for storing world clocks
    private let worldClocksKey = "savedWorldClocks"
    
    var body: some View {
        if hasCompletedOnboarding {
            TabView(selection: $selectedTab) {
            Tab(String(localized: "List"), systemImage: "list.bullet", value: MainTab.list) {
                HomeView(
                    worldClocks: $worldClocks,
                    timeOffset: $timeOffset,
                    showScrollTimeButtons: $listShowScrollTimeButtons,
                    weatherManager: weatherManager
                )
            }
            
            Tab(String(localized: "Clock"), systemImage: "clock", value: MainTab.clock) {
                AnalogClockFullView(
                    worldClocks: $worldClocks,
                    timeOffset: $timeOffset,
                    showScrollTimeButtons: $clockShowScrollTimeButtons,
                    weatherManager: weatherManager
                )
            }
            
            Tab(value: MainTab.search, role: .search) {
                SearchTabView(worldClocks: $worldClocks)
                    .onAppear {
                        if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                            impactFeedback.prepare()
                            impactFeedback.impactOccurred()
                        }
                    }
            } label: {
                Label(String(localized: "Search"), systemImage: "plus")
            }
            }
            .tabViewStyle(.automatic)
            .onAppear {
                loadWorldClocks()
            }
            // Quick actions (Home Screen icon menu / Spotlight App Shortcuts)
            // land on the List tab, where HomeView presents the matching sheet.
            // The publisher also delivers the pending value on subscription,
            // which covers cold launches.
            .onReceive(QuickActionsManager.shared.$pendingAction) { action in
                guard let action else { return }
                selectedTab = .list
                DispatchQueue.main.async {
                    QuickActionsManager.shared.pendingAction = nil
                    switch action {
                    case .setAlarm:
                        NotificationCenter.default.post(name: .quickActionSetAlarm, object: nil)
                    case .setTimer:
                        NotificationCenter.default.post(name: .quickActionSetTimer, object: nil)
                    case .countdown:
                        NotificationCenter.default.post(name: .quickActionCountdown, object: nil)
                    }
                }
            }
        } else {
            OnboardingView(
                hasCompletedOnboarding: $hasCompletedOnboarding,
                weatherManager: weatherManager
            )
        }
    }
    
    // Load world clocks from UserDefaults
    func loadWorldClocks() {
        if let data = UserDefaults.standard.data(forKey: worldClocksKey),
           let decoded = try? JSONDecoder().decode([WorldClock].self, from: data) {
            worldClocks = decoded
        } else {
            // If no saved data, use default clocks
            worldClocks = WorldClockData.defaultClocks
            saveWorldClocks()
        }
    }
    
    // Save world clocks to UserDefaults
    func saveWorldClocks() {
        if let encoded = try? JSONEncoder().encode(worldClocks) {
            UserDefaults.standard.set(encoded, forKey: worldClocksKey)
        }
    }
}
