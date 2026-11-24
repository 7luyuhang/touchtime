//
//  WatchSyncManager.swift
//  touchtime
//
//  Sends the saved cities and collections, the date style, the first day of
//  the week, the temperature, wind speed and pressure units, the countdowns
//  and the unit they count in, and the recent timers to the Apple Watch app,
//  and puts the timers started there in Recents.
//

import Foundation
import UIKit
import WatchConnectivity

/// Keeps the Apple Watch app's cities, countdowns and recent timers in step
/// with the iPhone's. The latest of them travel as the WatchConnectivity
/// application context, which the watch receives even when its app isn't
/// running. The timers started on the watch come back as user info, each
/// queued there until it's delivered.
final class WatchSyncManager: NSObject, WCSessionDelegate {
    static let shared = WatchSyncManager()

    /// How many pixels the thumbnail behind a countdown's row keeps of its
    /// cover photo, on the longer side. Blurred over the row, those few
    /// pixels look just like the whole photo, and they keep the application
    /// context small.
    private static let photoThumbnailSide: CGFloat = 24
    /// How many pixels across the cover photo is for a countdown's details:
    /// twice the points of the watch's circle, so it's as sharp there.
    private static let coverPhotoSide: CGFloat = 176

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Sends `clocks`, or the saved cities when nil, the saved collections
    /// and countdowns, and the recent timers.
    func sync(clocks: [WorldClock]? = nil) {
        guard let session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else { return }

        let cities = (clocks ?? Self.savedClocks()).map { WatchCity($0) }
        let collections = CollectionsStore.load().map {
            WatchCollection(id: $0.id, name: $0.name, cities: $0.cities.map { WatchCity($0) })
        }
        let recentTimers = RecentTimerStore.load().map {
            WatchRecentTimer(id: $0.id, name: $0.name, durationSeconds: $0.durationSeconds)
        }
        guard let citiesData = try? JSONEncoder().encode(cities),
              let collectionsData = try? JSONEncoder().encode(collections),
              let recentTimersData = try? JSONEncoder().encode(recentTimers) else { return }
        let countdowns = CountdownSortOrder.saved.sorted(Self.savedCountdowns())

        var context: [String: Any] = [
            WatchSyncKeys.cities: citiesData,
            WatchSyncKeys.collections: collectionsData,
            WatchSyncKeys.dateStyle: UserDefaults.standard.string(forKey: "dateStyle") ?? "Relative",
            WatchSyncKeys.firstWeekday: UserDefaults.standard.object(forKey: SharedWidgetStore.firstWeekdayKey) as? Int
                ?? SharedWidgetStore.defaultFirstWeekday,
            WatchSyncKeys.useCelsius: UserDefaults.standard.object(forKey: "useCelsius") as? Bool ?? true,
            WatchSyncKeys.windSpeedUnit: UserDefaults.standard.string(forKey: WindSpeedUnit.storageKey)
                ?? WindSpeedUnit.kilometersPerHour.rawValue,
            WatchSyncKeys.pressureUnit: UserDefaults.standard.string(forKey: PressureUnit.storageKey)
                ?? PressureUnit.millibars.rawValue,
            WatchSyncKeys.countdownUnit: CountdownUnit(
                showYears: UserDefaults.standard.bool(forKey: "countdownShowYears"),
                showMonths: UserDefaults.standard.bool(forKey: "countdownShowMonths")
            ).rawValue,
            WatchSyncKeys.recentTimers: recentTimersData
        ]
        // The photos are most of it: past the size limit, the covers go,
        // then the thumbnails too, so the countdowns and everything else
        // still get to the watch.
        for photos in PhotoDetail.allCases {
            context[WatchSyncKeys.countdowns] = Self.encoded(countdowns, photos: photos)
            do {
                try session.updateApplicationContext(context)
                return
            } catch WCError.payloadTooLarge {
                continue
            } catch {
                return
            }
        }
    }

    /// How much of the countdowns' cover photos goes to the watch, from
    /// the most.
    private enum PhotoDetail: CaseIterable {
        /// The cover for the details and the thumbnail behind the row.
        case covers
        /// Only the thumbnail.
        case thumbnails
        /// Neither.
        case none
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

    /// `countdowns` as the watch shows them, JSON-encoded, with as much of
    /// their cover photos as `photos` allows. Without any, those with a
    /// cover photo go without a background.
    private static func encoded(_ countdowns: [CountdownItem], photos: PhotoDetail) -> Data? {
        let watchCountdowns = countdowns.map { item in
            WatchCountdown(
                id: item.id,
                title: item.title,
                targetDate: item.targetDate,
                repeatFrequency: item.repeatFrequency,
                pausedAt: item.pausedAt,
                emoji: item.emoji,
                coverPhoto: photos == .covers ? coverPhoto(of: item) : nil,
                background: background(of: item, withPhoto: photos != .none)
            )
        }
        return try? JSONEncoder().encode(watchCountdowns)
    }

    /// `item`'s cover photo as framed in its badge, as sharp as the watch's
    /// details show it, or nil without one.
    private static func coverPhoto(of item: CountdownItem) -> Data? {
        guard let photoData = item.photoData,
              let photo = CountdownPreviewCard.cachedImage(from: photoData, crop: item.photoCrop) else { return nil }
        return jpeg(of: photo, longerSide: coverPhotoSide)
    }

    /// What fills `item`'s card, as on the iPhone: its photo blurred, or
    /// its emoji's colour without one.
    private static func background(of item: CountdownItem, withPhoto: Bool) -> WatchCountdown.Background? {
        if let photoData = item.photoData {
            guard withPhoto else { return nil }
            if let photo = CountdownPreviewCard.cachedImage(from: photoData, crop: item.photoCrop),
               let thumbnail = jpeg(of: photo, longerSide: photoThumbnailSide) {
                return .photo(thumbnail)
            }
        }
        guard let emoji = item.emoji, let color = EmojiDominantColor.cached(for: emoji) else { return nil }
        return .color(hue: color.hue, saturation: color.saturation, brightness: color.brightness)
    }

    /// `photo` shrunk to `longerSide` pixels on its longer side, as a JPEG.
    private static func jpeg(of photo: UIImage, longerSide targetSide: CGFloat) -> Data? {
        let longerSide = max(photo.size.width, photo.size.height)
        guard longerSide > 0 else { return nil }
        let scale = min(1, targetSide / longerSide)
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

    // A timer started on the watch from its pickers. Remembering it sends
    // Recents back with it in.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let timerData = userInfo[WatchSyncKeys.startedTimer] as? Data else { return }
        Task { @MainActor in
            guard let timer = try? JSONDecoder().decode(WatchRecentTimer.self, from: timerData) else { return }
            RecentTimerStore.remember(durationSeconds: timer.durationSeconds, name: timer.name)
            NotificationCenter.default.post(name: .recentTimersDidChange, object: nil)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Switching to another watch deactivates the session; activating
        // again connects to the new one
        session.activate()
    }
}
