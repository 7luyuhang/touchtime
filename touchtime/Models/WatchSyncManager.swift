//
//  WatchSyncManager.swift
//  touchtime
//
//  Sends the saved cities and the date style to the Apple Watch app.
//

import Foundation
import WatchConnectivity

/// Keeps the Apple Watch app's cities in step with the iPhone's. The latest
/// list travels as the WatchConnectivity application context, which the
/// watch receives even when its app isn't running.
final class WatchSyncManager: NSObject, WCSessionDelegate {
    static let shared = WatchSyncManager()

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Sends `clocks`, or the saved cities when nil.
    func sync(clocks: [WorldClock]? = nil) {
        guard let session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else { return }

        let cities = (clocks ?? Self.savedClocks()).map { WatchCity($0) }
        guard let citiesData = try? JSONEncoder().encode(cities) else { return }

        try? session.updateApplicationContext([
            WatchSyncKeys.cities: citiesData,
            WatchSyncKeys.dateStyle: UserDefaults.standard.string(forKey: "dateStyle") ?? "Relative"
        ])
    }

    /// The saved cities, or the defaults the app starts with before it has
    /// saved any.
    private static func savedClocks() -> [WorldClock] {
        guard let data = UserDefaults.standard.data(forKey: SharedWidgetStore.worldClocksKey),
              let clocks = try? JSONDecoder().decode([WorldClock].self, from: data) else {
            return WorldClockData.defaultClocks
        }
        return clocks
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            self.sync()
        }
    }

    // The watch app was just installed, or the user paired another watch
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.sync()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Switching to another watch deactivates the session; activating
        // again connects to the new one
        session.activate()
    }
}
