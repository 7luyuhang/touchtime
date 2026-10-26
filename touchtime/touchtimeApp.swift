//
//  touchtimeApp.swift
//  touchtime
//
//  Created by yuhang on 23/09/2025.
//

import Combine
import LockedCameraCapture
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
    // The home indicator's inset, for tabs whose own bottom inset goes stale
    // next to a vertical bar (iPhone Duo).
    @State private var windowBottomInset: CGFloat = 0

    init() {
        // Initialize TipKit
        try? Tips.configure([
            .displayFrequency(.daily),
            .datastoreLocation(.applicationDefault)
        ])

        // Timer / stopwatch Live Activity buttons, also when they launch the app in the background
        LiveActivityActionRouter.perform = LiveActivityManager.perform
        // The Camera Control, and the Camera button in Control Center, open
        // the Clock tab's camera
        CameraCaptureRouter.openCamera = {
            QuickActionsManager.shared.pendingAction = .camera
        }

        // Before any view reads it, so Fahrenheit users keep mph
        WindSpeedUnit.migrateFromTemperatureUnit()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .syncsLiveActivities()
                .environment(countdownStore)
                .environment(\.colorScheme, .dark) // Force dark theme
                .environment(\.windowBottomInset, windowBottomInset)
                .background {
                    // Outside the tab view, so without any bar, and ignoring
                    // the keyboard
                    Color.clear
                        .ignoresSafeArea(.keyboard)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.safeAreaInsets.bottom
                        } action: { inset in
                            windowBottomInset = inset
                        }
                }
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
                // The Lock Screen camera hands over to the app's camera once
                // the iPhone is unlocked
                .onContinueUserActivity(NSUserActivityTypeLockedCameraCapture) { _ in
                    QuickActionsManager.shared.pendingAction = .camera
                }
                // Countdowns shared from another phone, opened from AirDrop,
                // Messages, Mail or Files
                .onOpenURL { url in
                    SharedCountdownInbox.shared.open(url)
                }
                // Alarms set from a city's time follow that city's clock
                // when the clocks change while the app is open
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    Task { await AlarmSupport.resyncCityAlarms() }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange).receive(on: DispatchQueue.main)) { _ in
                    Task { await AlarmSupport.resyncCityAlarms() }
                }
                // Injected app-wide, so sheets that take only part of the
                // window still know which way up it is
                .readsWindowOrientation()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Keep the rolling 24-hour window of on-the-hour notifications topped up,
            // and turn the toggle off if permission was revoked in system Settings
            if newPhase == .active {
                HourlyNotificationManager.shared.syncEnabledWithAuthorization()
                HourlyNotificationManager.shared.reschedule()
                // Repeating countdown reminders roll forward to their next
                // occurrence after one has fired.
                CountdownReminderManager.shared.reschedule(for: countdownStore.countdowns)
                // Daylight saving or travel may have shifted the device's
                // clock against the cities alarms were set from
                Task { await AlarmSupport.resyncCityAlarms() }
                SharedWidgetStore.syncFromApp()
                discardLockedCameraSessionContent()
                // Screens fetch weather only as they appear, not when the
                // app comes back, so expired conditions are replaced here
                Task { await WeatherManager.shared.refreshExpiredWeather() }
            } else if newPhase == .background {
                // Keep the widget's city list and time format up to date
                SharedWidgetStore.syncFromApp()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    /// The Lock Screen camera doesn't capture, so the folders it leaves the
    /// app are empty
    private func discardLockedCameraSessionContent() {
        Task {
            let manager = LockedCameraCaptureManager.shared
            for url in manager.sessionContentURLs {
                try? await manager.invalidateSessionContent(at: url)
            }
        }
    }
}

extension EnvironmentValues {
    /// Whether the window is wider than it is tall. A sheet can't tell from
    /// its own size: on the iPhone Duo in landscape it takes only one half.
    @Entry var isWindowLandscape = false
    /// The window's own bottom safe area inset (the home indicator), without
    /// any bar or the keyboard.
    @Entry var windowBottomInset: CGFloat = 0
}

/// Sets `isWindowLandscape` from the window's geometry as it's laid out, so
/// on a rotation the views get the new orientation in the same layout pass
/// as the new size. Measured after the fact, it would land one update late,
/// and for that update the views would lay out the new size the old way.
private struct WindowOrientationReader: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { proxy in
            // The safe area added back, so the keyboard can't make a portrait
            // window look wide
            let insets = proxy.safeAreaInsets
            let width = proxy.size.width + insets.leading + insets.trailing
            let height = proxy.size.height + insets.top + insets.bottom
            content.environment(\.isWindowLandscape, width > height)
        }
    }
}

private extension View {
    func readsWindowOrientation() -> some View {
        modifier(WindowOrientationReader())
    }
}
