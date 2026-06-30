//
//  ContentView.swift
//  touchtime
//
//  Created by yuhang on 23/09/2025.
//

import SwiftUI

// Marks whether a view belongs to the currently selected tab. Time animations
// (driven by the shared `timeOffset`) are suppressed on inactive tabs so they
// don't defer and "replay" the spring when the tab is re-selected.
private struct IsTabActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var isTabActive: Bool {
        get { self[IsTabActiveKey.self] }
        set { self[IsTabActiveKey.self] = newValue }
    }
}

struct ContentView: View {
    @State private var worldClocks: [WorldClock] = []
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @StateObject private var weatherManager = WeatherManager()
    
    // Shared time offset state for HomeView, AnalogClockFullView and EarthView
    @State private var timeOffset: TimeInterval = 0
    @State private var listShowScrollTimeButtons = false
    @State private var clockShowScrollTimeButtons = false
    @State private var earthShowScrollTimeButtons = false
    @State private var selectedTab: AppTab = .list
    
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    // UserDefaults key for storing world clocks
    private let worldClocksKey = "savedWorldClocks"

    private enum AppTab: Hashable {
        case list, clock, earth, search
    }

    var body: some View {
        if hasCompletedOnboarding {
            TabView(selection: $selectedTab) {
            Tab(String(localized: "List"), systemImage: "list.bullet", value: AppTab.list) {
                HomeView(
                    worldClocks: $worldClocks,
                    timeOffset: $timeOffset,
                    showScrollTimeButtons: $listShowScrollTimeButtons,
                    weatherManager: weatherManager
                )
                // The time scrubber drives `timeOffset`, which every tab shares. When a
                // reset (or scrub) runs through `withAnimation`, the off-screen tabs also
                // animate and then "replay" that spring when re-selected. Suppressing
                // animations while a tab isn't front keeps the shared state in sync
                // without re-running the animation on tab switches.
                .environment(\.isTabActive, selectedTab == .list)
                .transaction { if selectedTab != .list { $0.animation = nil } }
            }
            
            Tab(String(localized: "Clock"), systemImage: "clock", value: AppTab.clock) {
                AnalogClockFullView(
                    worldClocks: $worldClocks,
                    timeOffset: $timeOffset,
                    showScrollTimeButtons: $clockShowScrollTimeButtons,
                    weatherManager: weatherManager
                )
                .environment(\.isTabActive, selectedTab == .clock)
                .transaction { if selectedTab != .clock { $0.animation = nil } }
            }
            
            Tab(String(localized: "Earth"), systemImage: "globe.americas.fill", value: AppTab.earth) {
                EarthView(
                    timeOffset: $timeOffset,
                    worldClocks: $worldClocks,
                    showScrollTimeButtons: $earthShowScrollTimeButtons,
                    weatherManager: weatherManager
                )
                .environment(\.isTabActive, selectedTab == .earth)
                .transaction { if selectedTab != .earth { $0.animation = nil } }
            }
            
            Tab(value: AppTab.search, role: .search) {
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

// Shared bottom time scrubber used by both the List (`HomeView`) and Earth
// (`EarthView`) tabs so their scrubber configuration can't drift apart. The
// Clock tab keeps its own specialised scrubber (timer play/pause + camera
// buttons), so it is intentionally not routed through here.
//
// The scrubber's visibility is driven by `isVisible`, but the alarm/timer
// sheets stay attached to a stable container regardless of visibility so that
// externally triggered presentations (e.g. notification-driven) keep working
// even while the bar itself is hidden.
struct TimeScrubberBar: View {
    @Binding var timeOffset: TimeInterval
    @Binding var worldClocks: [WorldClock]
    @Binding var showScrollTimeButtons: Bool
    @Binding var showSetAlarmSheet: Bool
    @Binding var showSetTimerSheet: Bool
    let isVisible: Bool
    let timerInitialSeconds: Int
    let onStartTimer: (Int) -> Void
    var onExpandControlsByDoubleTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if isVisible {
                ScrollTimeView(
                    timeOffset: $timeOffset,
                    showButtons: $showScrollTimeButtons,
                    worldClocks: $worldClocks,
                    enableDoubleTapExpandedControls: true,
                    onAlarmTap: { showSetAlarmSheet = true },
                    onTimerTap: { showSetTimerSheet = true },
                    onExpandControlsByDoubleTap: onExpandControlsByDoubleTap
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.blurReplace())
            }
        }
        .sheet(isPresented: $showSetAlarmSheet) {
            SetAlarmSheet()
        }
        .sheet(isPresented: $showSetTimerSheet) {
            SetTimerSheet(initialDurationSeconds: timerInitialSeconds) { durationSeconds in
                onStartTimer(durationSeconds)
            }
        }
    }
}
