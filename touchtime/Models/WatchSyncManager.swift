//
//  WatchSyncManager.swift
//  touchtime
//
//  Sends the saved cities, the date style, the first day of the week, the
//  temperature, wind speed and pressure units, and the countdowns with
//  their cover photos to the Apple Watch app.
//

import CryptoKit
import Foundation
import UIKit
import WatchConnectivity

/// Keeps the Apple Watch app's cities and countdowns in step with the
/// iPhone's. The latest of them travel as the WatchConnectivity application
/// context, which the watch receives even when its app isn't running; the
/// countdowns' cover photos, too big for it, follow as files.
final class WatchSyncManager: NSObject, WCSessionDelegate {
    static let shared = WatchSyncManager()

    /// How many pixels the thumbnail behind a countdown's row keeps of its
    /// cover photo, on the longer side. Blurred over the row, those few
    /// pixels look just like the whole photo, and they keep the application
    /// context small.
    private static let photoThumbnailSide: CGFloat = 24
    /// How many pixels across the cover photo is for a countdown's details:
    /// twice as many as the watch's circle has. Halved evenly onto the
    /// screen, it comes out sharper than a photo the circle's size, and
    /// stays sharp as the circle swells under a press.
    private static let coverPhotoSide: CGFloat = 352
    private static let coverPhotoQuality: CGFloat = 0.9

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
        Self.sendCoverPhotos(of: countdowns, over: session)
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
                emoji: item.emoji,
                coverPhotoFileName: coverPhotoFileName(of: item),
                background: background(of: item, withPhoto: withPhotos)
            )
        }
        return try? JSONEncoder().encode(watchCountdowns)
    }

    /// The name of the file `item`'s cover photo goes to the watch in, or
    /// nil without one: a digest of the photo, its framing and its size and
    /// quality, so a new cover, or one sent sharper, goes in a new file.
    private static func coverPhotoFileName(of item: CountdownItem) -> String? {
        guard let photoData = item.photoData else { return nil }
        var hasher = SHA256()
        hasher.update(data: photoData)
        var rendering = "\(coverPhotoSide) \(coverPhotoQuality)"
        if let crop = item.photoCrop {
            rendering += " \(crop.scale) \(crop.offset.width) \(crop.offset.height)"
        }
        hasher.update(data: Data(rendering.utf8))
        let digest = hasher.finalize().prefix(8).map { String(format: "%02x", $0) }.joined()
        return "\(digest).jpg"
    }

    /// Sends the watch the cover photos of `countdowns` it hasn't been sent,
    /// as files: too big for the application context. Each stays in the
    /// session's watch directory once sent, until no countdown shows it any
    /// more; the system clears that directory away with the watch app, so
    /// a reinstalled one is sent them all again.
    private static func sendCoverPhotos(of countdowns: [CountdownItem], over session: WCSession) {
        guard let directory = coverPhotosDirectory(of: session) else { return }
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var unsent: [String: CountdownItem] = [:]
        for item in countdowns {
            if let name = coverPhotoFileName(of: item) {
                unsent[name] = item
            }
        }
        let sent = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in sent {
            if unsent.removeValue(forKey: file.lastPathComponent) == nil {
                try? fileManager.removeItem(at: file)
            }
        }

        for (name, item) in unsent {
            guard let photoData = item.photoData,
                  let photo = CountdownPreviewCard.cachedImage(from: photoData, crop: item.photoCrop),
                  let jpeg = jpeg(of: photo, longerSide: coverPhotoSide, quality: coverPhotoQuality) else { continue }
            let file = directory.appending(path: name)
            guard (try? jpeg.write(to: file)) != nil else { continue }
            session.transferFile(file, metadata: [WatchSyncKeys.coverPhotoFileName: name])
        }
    }

    /// Where the cover photos sent to the watch are kept: in the session's
    /// directory for its watch app, nil without one.
    nonisolated private static func coverPhotosDirectory(of session: WCSession) -> URL? {
        session.watchDirectoryURL?.appending(path: "Cover Photos", directoryHint: .isDirectory)
    }

    /// What fills `item`'s card, as on the iPhone: its photo blurred, or
    /// its emoji's colour without one.
    private static func background(of item: CountdownItem, withPhoto: Bool) -> WatchCountdown.Background? {
        if let photoData = item.photoData {
            guard withPhoto else { return nil }
            if let photo = CountdownPreviewCard.cachedImage(from: photoData, crop: item.photoCrop),
               let thumbnail = jpeg(of: photo, longerSide: photoThumbnailSide, quality: 0.7) {
                return .photo(thumbnail)
            }
        }
        guard let emoji = item.emoji, let color = EmojiDominantColor.cached(for: emoji) else { return nil }
        return .color(hue: color.hue, saturation: color.saturation, brightness: color.brightness)
    }

    /// `photo` shrunk to `longerSide` pixels on its longer side, as a JPEG
    /// of `quality`, from 0 to 1.
    private static func jpeg(of photo: UIImage, longerSide targetSide: CGFloat, quality: CGFloat) -> Data? {
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
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: quality) { context in
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

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        // Cleared away, so the next sync sends it again
        guard error != nil,
              let name = fileTransfer.file.metadata?[WatchSyncKeys.coverPhotoFileName] as? String,
              let directory = Self.coverPhotosDirectory(of: session) else { return }
        try? FileManager.default.removeItem(at: directory.appending(path: name))
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Switching to another watch deactivates the session; activating
        // again connects to the new one
        session.activate()
    }
}
