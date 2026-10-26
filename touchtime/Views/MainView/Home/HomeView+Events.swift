//
//  HomeView+Events.swift
//  touchtime
//

import SwiftUI
import Combine

extension HomeView {
    func handlingEvents(_ content: some View) -> some View {
        content
            .onReceive(timer) { now in
                handleHomeTimerTick(at: now)
                finalizeHomeStopwatchIfLimitReached(at: now)

                // Only update when the minute changes.
                // The List displays "HH:mm" (no seconds) and all visual components
                // (sky gradients, analog clock, etc.) are minute-level.
                // This reduces full-body re-renders from 60×/min to 1×/min,
                // eliminating frame drops during scrolling with many cities.
                let cal = Calendar.current
                if cal.component(.minute, from: now) != cal.component(.minute, from: currentDate) {
                    currentDate = now
                }
            }
            
            .onAppear {
                loadCollections()
                restoreHomeTimerStateIfNeeded()
                finalizeHomeStopwatchIfLimitReached(at: Date())
                checkForTimeZoneChange()
            }
            
            // Time zone changes, for the Time Zone Updated tip
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    checkForTimeZoneChange()
                }
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                // Lets Home settle first, rather than the sheet greeting the user
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                showLifetimePromoIfDue()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange).receive(on: DispatchQueue.main)) { _ in
                checkForTimeZoneChange()
            }

            // With fewer than two pinned countdowns there's nothing to fold, so
            // the next ones pinned show unfolded
            .onChange(of: displayedCountdowns.count) { _, count in
                if count < 2 {
                    isCountdownStackCollapsed = false
                }
            }
    }

    /// Requests posted from other screens and quick actions: resetting the
    /// scrolled time and opening Home's tool sheets.
    func handlingRequests(_ content: some View) -> some View {
        content
            // Listen for reset notification to reset scroll time
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetScrollTime"))) { _ in
                withAnimation(.spring()) {
                    timeOffset = 0
                    showScrollTimeButtons = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSetAlarmSheet"))) { _ in
                showSetAlarmSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSetTimerSheet"))) { _ in
                showSetTimerSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowCountdownSheet"))) { _ in
                showCountdownSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowStopwatchSheet"))) { _ in
                showStopwatchRecordsSheet = true
            }

            // Quick actions (Home Screen icon menu / Spotlight App Shortcuts)
            .onReceive(NotificationCenter.default.publisher(for: .quickActionSetAlarm)) { _ in
                showSetAlarmSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickActionSetTimer)) { _ in
                showSetTimerSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickActionCountdown)) { _ in
                showCountdownSheet = true
            }
    }

    // Show the Time Zone Updated tip when the device's time zone differs from
    // the last one seen, e.g. after landing in another country
    private func checkForTimeZoneChange() {
        let currentIdentifier = TimeZone.current.identifier
        guard currentIdentifier != lastKnownTimeZoneIdentifier else { return }

        // Nothing is recorded before the first check, so there's no change to report
        let isFirstCheck = lastKnownTimeZoneIdentifier.isEmpty
        lastKnownTimeZoneIdentifier = currentIdentifier

        guard !isFirstCheck, showLocalTime else { return }
        withAnimation(.spring()) {
            showTimeZoneUpdatedTip = true
        }
    }
}
