//
//  CountdownItem+CloudKit.swift
//  touchtime
//
//  How a countdown is stored as a record in the user's private iCloud
//  database, for CountdownSyncManager.
//

import CloudKit
import CryptoKit

extension CountdownItem {
    static let recordType: CKRecord.RecordType = "Countdown"
    private static let recordNamePrefix = "Countdown:"

    /// Record field keys. Every value except the photo asset is stored in
    /// `encryptedValues`, end-to-end encrypted.
    enum RecordField {
        static let title = "title"
        static let targetDate = "targetDate"
        static let createdAt = "createdAt"
        static let isPinned = "isPinned"
        static let repeatFrequency = "repeatFrequency"
        static let emoji = "emoji"
        static let photo = "photo"
        static let photoCrop = "photoCrop"
        static let reminderTime = "reminderTime"
        static let reminderCity = "reminderCity"
        static let reminderLeadDays = "reminderLeadDays"
        static let reminderKind = "reminderKind"
        static let contact = "contact"
        static let scheduledMessage = "scheduledMessage"
        static let pausedAt = "pausedAt"
        /// When the user last edited the countdown, on whichever device.
        static let modifiedAt = "modifiedAt"
    }

    /// Which cover photo a copy of a countdown has, compared by content so
    /// an edit that leaves the photo alone doesn't upload it again.
    enum PhotoFingerprint: Codable, Equatable {
        case noPhoto
        case photo(sha256: String)

        init(_ photoData: Data?) {
            if let photoData {
                let digest = SHA256.hash(data: photoData)
                self = .photo(sha256: digest.map { String(format: "%02x", $0) }.joined())
            } else {
                self = .noPhoto
            }
        }
    }

    static func recordID(for id: UUID, in zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: recordNamePrefix + id.uuidString, zoneID: zoneID)
    }

    /// The countdown a record is named after; nil for other record types.
    static func id(from recordID: CKRecord.ID) -> UUID? {
        guard recordID.recordName.hasPrefix(recordNamePrefix) else { return nil }
        return UUID(uuidString: String(recordID.recordName.dropFirst(recordNamePrefix.count)))
    }

    /// Writes every field except the photo, which CountdownSyncManager
    /// attaches as an asset only when it changed.
    ///
    /// Later fields need new keys rather than new values for an existing
    /// key: an older app version writes back the value it decoded, and only
    /// leaves the keys it doesn't know untouched.
    func write(to record: CKRecord, modifiedAt: Date) {
        let values = record.encryptedValues
        values[RecordField.title] = title
        values[RecordField.targetDate] = targetDate
        values[RecordField.createdAt] = createdAt
        values[RecordField.isPinned] = isPinned
        values[RecordField.repeatFrequency] = repeatFrequency.rawValue
        values[RecordField.emoji] = emoji
        values[RecordField.photoCrop] = Self.encoded(photoCrop)
        values[RecordField.reminderTime] = reminderTime
        values[RecordField.reminderCity] = Self.encoded(reminderCity)
        values[RecordField.reminderLeadDays] = reminderLeadDays
        values[RecordField.reminderKind] = reminderKind.rawValue
        values[RecordField.contact] = Self.encoded(contact)
        values[RecordField.scheduledMessage] = scheduledMessage
        values[RecordField.pausedAt] = pausedAt
        values[RecordField.modifiedAt] = modifiedAt
    }

    /// The countdown a fetched record describes, with the cover photo read
    /// from its asset. Nil when the record lacks what every countdown has.
    init?(record: CKRecord, photoData: Data?) {
        let values = record.encryptedValues
        guard let id = Self.id(from: record.recordID),
              let title = values[RecordField.title] as? String,
              let targetDate = values[RecordField.targetDate] as? Date else {
            return nil
        }
        // Like the JSON decoder, a raw value from a newer app version falls
        // back to the default instead of dropping the countdown.
        let repeatFrequency = (values[RecordField.repeatFrequency] as? String).flatMap { RepeatFrequency(rawValue: $0) }
        let reminderKind = (values[RecordField.reminderKind] as? String).flatMap { ReminderKind(rawValue: $0) }
        self.init(
            id: id,
            title: title,
            targetDate: targetDate,
            createdAt: values[RecordField.createdAt] as? Date ?? record.creationDate ?? Date(),
            isPinned: values[RecordField.isPinned] as? Bool ?? false,
            repeatFrequency: repeatFrequency ?? .never,
            emoji: values[RecordField.emoji] as? String,
            photoData: photoData,
            photoCrop: Self.decoded(PhotoCrop.self, from: values[RecordField.photoCrop]),
            reminderTime: values[RecordField.reminderTime] as? Date,
            reminderCity: Self.decoded(WorldClock.self, from: values[RecordField.reminderCity]),
            reminderLeadDays: values[RecordField.reminderLeadDays] as? Int ?? 0,
            reminderKind: reminderKind ?? .notification,
            contact: Self.decoded(LinkedContact.self, from: values[RecordField.contact]),
            scheduledMessage: values[RecordField.scheduledMessage] as? String,
            pausedAt: values[RecordField.pausedAt] as? Date
        )
    }

    private static func encoded<Value: Encodable>(_ value: Value?) -> Data? {
        value.flatMap { try? JSONEncoder().encode($0) }
    }

    private static func decoded<Value: Decodable>(_ type: Value.Type, from value: (any CKRecordValueProtocol)?) -> Value? {
        guard let data = value as? Data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

extension CKRecord {
    /// The record's system fields (identity and change tag) without its
    /// values, enough to save an edit on top of this server version.
    var systemFieldsData: Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    static func fromSystemFields(_ data: Data) -> CKRecord? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = true
        defer { unarchiver.finishDecoding() }
        return CKRecord(coder: unarchiver)
    }
}
