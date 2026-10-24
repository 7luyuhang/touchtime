//
//  SharedCountdown.swift
//  touchtime
//
//  A countdown sent from one phone's Touch Time to another's, as a
//  ".touchtime" file passed along through AirDrop, Messages, Mail or Files.
//

import CoreTransferable
import Foundation
import UIKit
import UniformTypeIdentifiers

extension UTType {
    /// A countdown file. Declared in Info.plist with Touch Time as its
    /// owner, so the system hands it to Touch Time on the receiving phone.
    nonisolated static let touchTimeCountdown = UTType(exportedAs: "com.time.touchtime.shared-countdown")
}

/// A countdown as it travels to another phone: the event, its date and
/// repeat, and its cover. What only makes sense on the sender's phone
/// stays behind: the reminder, the linked contact and its message, the
/// pause, the pin and the Space.
///
/// Nonisolated, file writing included: the share sheet waits for the file
/// on the main thread while it sets up, so an export that needed the main
/// actor would stall it until each wait timed out.
nonisolated struct SharedCountdown: Codable {
    /// Format version. Bumped only for changes an older Touch Time would
    /// misread, which then asks to be updated instead of opening the file.
    static let currentVersion = 1

    var version = Self.currentVersion
    var title: String
    var date: LocalDateTime
    /// A `CountdownItem.RepeatFrequency` raw value.
    var repeatFrequency: String
    var emoji: String?
    var photoData: Data?
    var photoCrop: PhotoCrop?

    @MainActor
    init(title: String, targetDate: Date, repeatFrequency: CountdownItem.RepeatFrequency, emoji: String?, photoData: Data?, photoCrop: CountdownItem.PhotoCrop?) {
        self.title = title
        self.date = LocalDateTime(targetDate)
        self.repeatFrequency = repeatFrequency.rawValue
        self.emoji = emoji
        self.photoData = photoData
        self.photoCrop = photoCrop.map { PhotoCrop(scale: $0.scale, offset: $0.offset) }
    }
}

extension SharedCountdown {
    /// `CountdownItem.PhotoCrop`, written the same way.
    nonisolated struct PhotoCrop: Codable {
        var scale: CGFloat
        var offset: CGSize
    }
}

// MARK: - Dates

extension SharedCountdown {
    /// A date and time as read off the calendar, with no time zone, so a
    /// countdown keeps its day on a phone in another time zone: a birthday
    /// on the 5th is on the 5th there too.
    nonisolated struct LocalDateTime: Codable {
        var year: Int
        var month: Int
        var day: Int
        var hour: Int
        var minute: Int

        /// Gregorian whatever calendar either phone is set to, in the
        /// phone's own time zone.
        private static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            return calendar
        }

        init(_ date: Date) {
            let components = Self.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            year = components.year ?? 1
            month = components.month ?? 1
            day = components.day ?? 1
            hour = components.hour ?? 0
            minute = components.minute ?? 0
        }

        /// The same date and time on this phone; nil when a field is out
        /// of its calendar range.
        var date: Date? {
            guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
                  (0...23).contains(hour), (0...59).contains(minute) else { return nil }
            return Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
        }
    }
}

// MARK: - Sending

extension SharedCountdown: Transferable {
    nonisolated static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .touchTimeCountdown) { countdown in
            SentTransferredFile(try countdown.writeFile())
        }
    }

    /// Writes the countdown to "<title>.touchtime" in a folder of its own,
    /// since the file name is what the receiver sees.
    nonisolated private func writeFile() throws -> URL {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: fileName).appendingPathExtension(for: .touchTimeCountdown)
        try JSONEncoder().encode(self).write(to: file)
        return file
    }

    /// The title, cut down to a name every file system takes.
    nonisolated private var fileName: String {
        // Dots come off the ends too: a leading one would hide the file.
        var name = title
            .components(separatedBy: CharacterSet(charactersIn: "/\\:").union(.newlines).union(.controlCharacters))
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ".")))
        // File names are capped at 255 bytes, extension included.
        while name.utf8.count > 200 {
            name.removeLast()
        }
        return name.isEmpty ? String(localized: "Countdown") : name
    }
}

// MARK: - Receiving

extension SharedCountdown {
    enum ReadError: Error {
        /// Not a countdown file, or a damaged one.
        case unreadable
        /// Written by a newer Touch Time, in a format this one doesn't know.
        case newerVersion

        var message: String {
            switch self {
            case .unreadable:
                String(localized: "This file isn't a countdown Touch Time can open.")
            case .newerVersion:
                String(localized: "This countdown was shared from a newer version of Touch Time. Update the app to open it.")
            }
        }
    }

    /// Far above any real file, which is mostly the cover photo at cover
    /// size.
    private static let maxFileSize = 2_000_000

    /// The countdown in a received file, as a new countdown to fill the New
    /// Countdown editor with.
    ///
    /// Anyone can send a file, so what it carries is held to what the
    /// editor itself makes: a single emoji, a photo redrawn at cover size,
    /// a framing that covers the badge and a repeat interval the Repeat
    /// menu offers. Whatever falls outside is left out.
    @MainActor
    static func draft(fromFileAt url: URL) throws(ReadError) -> CountdownItem {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= maxFileSize,
              let data = try? Data(contentsOf: url) else {
            throw .unreadable
        }
        let decoder = JSONDecoder()
        if let version = try? decoder.decode(FormatVersion.self, from: data).version, version > currentVersion {
            throw .newerVersion
        }
        guard let shared = try? decoder.decode(SharedCountdown.self, from: data),
              let targetDate = shared.date.date else {
            throw .unreadable
        }

        var repeatFrequency = CountdownItem.RepeatFrequency(rawValue: shared.repeatFrequency) ?? .never
        if let period = repeatFrequency.period, !CustomRepeatSheet.intervalRange.contains(period.count) {
            repeatFrequency = .never
        }
        let emoji = shared.emoji.flatMap { $0.count == 1 && $0.unicodeScalars.count <= 16 ? $0 : nil }
        let photoData = shared.photoData.flatMap { coverPhotoData(from: $0) }
        let photoCrop = shared.photoCrop.flatMap { crop in
            crop.scale.isFinite && crop.scale >= 1 && crop.offset.width.isFinite && crop.offset.height.isFinite
                ? CountdownItem.PhotoCrop(scale: crop.scale, offset: crop.offset)
                : nil
        }

        return CountdownItem(
            id: UUID(),
            title: shared.title.trimmingCharacters(in: .whitespacesAndNewlines),
            targetDate: targetDate,
            createdAt: Date(),
            repeatFrequency: repeatFrequency,
            emoji: emoji,
            photoData: photoData,
            photoCrop: photoData == nil ? nil : photoCrop
        )
    }

    /// The photo redrawn the way the cover sheet stores one. Covers are
    /// sent at most 800 pixels a side, so anything far bigger is refused
    /// before it is decoded.
    @MainActor
    private static func coverPhotoData(from data: Data) -> Data? {
        guard let image = UIImage(data: data),
              max(image.size.width, image.size.height) <= 4096 else { return nil }
        return CoverPickerSheet.downsampledJPEGData(from: data)
    }

    /// Just the version, which reads whatever else a newer format changed.
    private struct FormatVersion: Decodable {
        var version: Int
    }
}
