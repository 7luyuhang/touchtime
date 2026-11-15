//
//  WatchSyncManager.swift
//  touchtime
//
//  Sends the saved cities, the date style, the first day of the week, the
//  temperature, wind speed and pressure units, and the countdowns to the
//  Apple Watch app.
//

import Foundation
import UIKit
import WatchConnectivity

/// Keeps the Apple Watch app's cities and countdowns in step with the
/// iPhone's. The latest of them travel as the WatchConnectivity application
/// context, which the watch receives even when its app isn't running.
final class WatchSyncManager: NSObject, WCSessionDelegate {
    static let shared = WatchSyncManager()

    /// How many pixels a countdown's cover photo keeps on its longer side.
    private static let photoThumbnailSide: CGFloat = 24

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Sends `clocks`, or the saved cities when nil, and the saved
    /// countdowns.
    func sync(clocks: [WorldClock]? = nil) {
        guard let session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else { return }

        let cities = (clocks ?? Self.savedClocks()).map { WatchCity($0) }
        guard let citiesData = try? JSONEncoder().encode(cities) else { return }
        let countdowns = CountdownSortOrder.saved.sorted(Self.savedCountdowns())

        var context: [String: Any] = [
            WatchSyncKeys.cities: citiesData,
            WatchSyncKeys.dateStyle: UserDefaults.standard.string(forKey: "dateStyle") ?? "Relative",
            WatchSyncKeys.firstWeekday: UserDefaults.standard.object(forKey: SharedWidgetStore.firstWeekdayKey) as? Int
                ?? SharedWidgetStore.defaultFirstWeekday,
            WatchSyncKeys.useCelsius: UserDefaults.standard.object(forKey: "useCelsius") as? Bool ?? true,
            WatchSyncKeys.windSpeedUnit: UserDefaults.standard.string(forKey: WindSpeedUnit.storageKey)
                ?? WindSpeedUnit.kilometersPerHour.rawValue,
            WatchSyncKeys.pressureUnit: UserDefaults.standard.string(forKey: PressureUnit.storageKey)
                ?? PressureUnit.millibars.rawValue
        ]
        context[WatchSyncKeys.countdowns] = Self.encoded(countdowns, withPhotos: true)
        do {
            try session.updateApplicationContext(context)
        } catch WCError.payloadTooLarge {
            // The photos' thumbnails are most of it: without them, the
            // countdowns and everything else still get to the watch.
            context[WatchSyncKeys.countdowns] = Self.encoded(countdowns, withPhotos: false)
            try? session.updateApplicationContext(context)
        } catch {}
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

    /// The saved countdowns, or none before the app has saved any.
    private static func savedCountdowns() -> [CountdownItem] {
        guard let data = UserDefaults.standard.data(forKey: SharedWidgetStore.countdownsKey),
              let countdowns = try? JSONDecoder().decode([CountdownItem].self, from: data) else {
            return []
        }
        return countdowns
    }

    /// `countdowns` as the watch shows them, JSON-encoded. Without
    /// `withPhotos`, those with a cover photo go without a background.
    private static func encoded(_ countdowns: [CountdownItem], withPhotos: Bool) -> Data? {
        let watchCountdowns = countdowns.map { item in
            WatchCountdown(
                id: item.id,
                title: item.title,
                targetDate: item.targetDate,
                repeatFrequency: item.repeatFrequency,
                pausedAt: item.pausedAt,
                isPinned: item.isPinned,
                background: background(of: item, withPhoto: withPhotos)
            )
        }
        return try? JSONEncoder().encode(watchCountdowns)
    }

    /// What fills `item`'s card, as on the iPhone: its photo blurred, or
    /// its emoji's colour without one.
    private static func background(of item: CountdownItem, withPhoto: Bool) -> WatchCountdown.Background? {
        if let photoData = item.photoData {
            guard withPhoto else { return nil }
            if let photo = CountdownPreviewCard.cachedImage(from: photoData, crop: item.photoCrop),
               let thumbnail = thumbnail(of: photo) {
                return .photo(thumbnail)
            }
        }
        guard let emoji = item.emoji, let color = EmojiDominantColor.cached(for: emoji) else { return nil }
        return .color(hue: color.hue, saturation: color.saturation, brightness: color.brightness)
    }

    /// `photo` shrunk to `photoThumbnailSide` pixels on its longer side, as
    /// a JPEG. Blurred over the watch's card, those few pixels look just
    /// like the whole photo, and they keep the application context small.
    private static func thumbnail(of photo: UIImage) -> Data? {
        let longerSide = max(photo.size.width, photo.size.height)
        guard longerSide > 0 else { return nil }
        let scale = min(1, photoThumbnailSide / longerSide)
        let size = CGSize(
            width: max(1, (photo.size.width * scale).rounded()),
            height: max(1, (photo.size.height * scale).rounded())
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.7) { context in
            context.cgContext.interpolationQuality = .high
            photo.draw(in: CGRect(origin: .zero, size: size))
        }
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
