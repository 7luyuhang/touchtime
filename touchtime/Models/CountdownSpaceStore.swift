//
//  CountdownSpaceStore.swift
//  touchtime
//
//  Shared storage for the attachments saved in each countdown's space.
//

import Foundation
import Observation
import UIKit

/// One item saved in a countdown's Space page: a text note or a photo.
struct SpaceAttachment: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case text
        case image
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date
    /// Note content for `.text`.
    var text: String?
    /// Downsampled JPEG for `.image`.
    var imageData: Data?

    init(id: UUID = UUID(), kind: Kind, createdAt: Date = Date(), text: String? = nil, imageData: Data? = nil) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.text = text
        self.imageData = imageData
    }

    // Decoded via the raw kind string so an unknown kind from a newer app
    // version degrades to a text note instead of dropping the whole store.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        if let rawKind = try container.decodeIfPresent(String.self, forKey: .kind),
           let decodedKind = Kind(rawValue: rawKind) {
            kind = decodedKind
        } else {
            kind = .text
        }
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        text = try container.decodeIfPresent(String.self, forKey: .text)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
    }
}

/// Single source of truth for space attachments, keyed by countdown id and
/// persisted to UserDefaults automatically, mirroring `CountdownStore`.
@Observable
final class CountdownSpaceStore {
    static let shared = CountdownSpaceStore()

    private static let storageKey = "countdownSpaceAttachments"

    /// Attachments per countdown id (as uuidString), newest first.
    private(set) var attachmentsByCountdown: [String: [SpaceAttachment]] {
        didSet {
            Self.persist(attachmentsByCountdown)
        }
    }

    private init() {
        attachmentsByCountdown = Self.load()
    }

    func attachments(for countdownID: UUID) -> [SpaceAttachment] {
        attachmentsByCountdown[countdownID.uuidString] ?? []
    }

    /// Inserts a new attachment at the front (the grid shows newest first).
    func add(_ attachment: SpaceAttachment, to countdownID: UUID) {
        var items = attachments(for: countdownID)
        items.insert(attachment, at: 0)
        attachmentsByCountdown[countdownID.uuidString] = items
    }

    func remove(_ attachmentID: UUID, from countdownID: UUID) {
        var items = attachments(for: countdownID)
        items.removeAll { $0.id == attachmentID }
        attachmentsByCountdown[countdownID.uuidString] = items.isEmpty ? nil : items
    }

    /// Drops the attachments of countdowns that no longer exist, called on
    /// every countdown mutation so deleted events take their space along.
    func prune(keeping countdownIDs: [UUID]) {
        let keptKeys = Set(countdownIDs.map(\.uuidString))
        let pruned = attachmentsByCountdown.filter { keptKeys.contains($0.key) }
        guard pruned.count != attachmentsByCountdown.count else { return }
        attachmentsByCountdown = pruned
    }

    private static func load() -> [String: [SpaceAttachment]] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([String: [SpaceAttachment]].self, from: data) else {
            return [:]
        }
        return items
    }

    private static func persist(_ items: [String: [SpaceAttachment]]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// Shrinks a picked photo so the store never holds multi-megabyte
    /// originals; also bakes in the orientation. Slightly larger than the
    /// cover photo limit because space photos open in a full-size viewer.
    static func downsampledJPEGData(from data: Data, maxDimension: CGFloat = 1200) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let largestSide = max(image.size.width, image.size.height)
        guard largestSide > 0 else { return nil }

        let scale = min(1, maxDimension / largestSide)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}
