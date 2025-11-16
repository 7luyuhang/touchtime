//
//  ContentView.swift
//  touchtime
//
//  Created by yuhang on 23/09/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var worldClocks: [WorldClock] = []
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    
    // UserDefaults key for storing world clocks
    private let worldClocksKey = "savedWorldClocks"
    
    var body: some View {
        if hasCompletedOnboarding {
            TabView {
            Tab(String(localized: "List"), systemImage: "clock") {
                HomeView(worldClocks: $worldClocks)
            }
            
            Tab(String(localized: "Earth"), systemImage: "globe.americas.fill") {
                EarthView(worldClocks: $worldClocks)
            }
            
            Tab(role: .search) {
                SearchTabView(worldClocks: $worldClocks)
            }
            }
            .tabViewStyle(.automatic)
            .onAppear {
                loadWorldClocks()
            }
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
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
