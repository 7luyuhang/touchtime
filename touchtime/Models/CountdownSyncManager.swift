//
//  CountdownSyncManager.swift
//  touchtime
//
//  Syncs countdowns, and the order of the ones pinned to Home, across the
//  user's devices through their private iCloud database.
//

import CloudKit
import Foundation

/// What the sync manager keeps beside the countdowns themselves, saved as a
/// JSON file in Application Support.
struct CountdownSyncMetadata: Codable {
    struct RecordState: Codable {
        /// System fields of the last server version seen (see
        /// `CKRecord.systemFieldsData`); nil before the first save or fetch.
        var systemFields: Data?
        /// When the user last edited the record. On a conflict the later
        /// edit wins, whichever device uploads last.
        var modifiedAt: Date
        /// The cover photo the server version holds; nil when unknown, so
        /// the next save attaches the photo either way.
        var serverPhoto: CountdownItem.PhotoFingerprint?
    }

    var stateSerialization: CKSyncEngine.State.Serialization?
    /// Keyed by record name.
    var records: [String: RecordState] = [:]
    /// The iCloud account the countdowns here were last synced with.
    var userRecordName: String?
    /// Records edited while sync was turned off, uploaded once it's back on.
    var pendingSaves: Set<String> = []
    /// Records deleted on this device that the server hasn't confirmed
    /// deleting. The engine drops its queue when the account changes, and
    /// these would otherwise come back from the server.
    var pendingDeletes: Set<String> = []

    private static let fileURL = URL.applicationSupportDirectory.appending(path: "CountdownSync.json")

    static func load() -> CountdownSyncMetadata {
        guard let data = try? Data(contentsOf: fileURL),
              let metadata = try? JSONDecoder().decode(CountdownSyncMetadata.self, from: data) else {
            return CountdownSyncMetadata()
        }
        return metadata
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            try FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            print("Failed to save countdown sync state: \(error)")
        }
    }
}

/// Keeps `CountdownStore` in step with the user's private CloudKit database
/// through `CKSyncEngine`. The store stays the source of truth: it reports
/// each local edit here, and edits from other devices come back through
/// `CountdownStore.applyRemoteChanges`.
///
/// On a conflict the later edit wins (`modifiedAt`), and a deletion wins
/// over an edit.
final class CountdownSyncManager {
    static let shared = CountdownSyncManager()

    /// UserDefaults key of the Settings toggle; sync is on until turned off.
    static let enabledKey = "iCloudSyncEnabled"

    private static let containerIdentifier = "iCloud.com.time.touchtime"
    private static let zoneID = CKRecordZone.ID(zoneName: "Countdowns")
    private static let homeLayoutRecordType: CKRecord.RecordType = "HomeLayout"
    private static let homeLayoutRecordID = CKRecord.ID(recordName: "HomeLayout", zoneID: zoneID)
    /// Pinned countdown ids in Home's order, comma separated.
    private static let pinnedOrderField = "pinnedOrder"
    private static let temporaryPhotoDirectory = URL.temporaryDirectory.appending(path: "CountdownSync", directoryHint: .isDirectory)

    /// Edits from other devices, applied to the store in one go.
    private struct RemoteChanges {
        var upserts: [CountdownItem] = []
        var deletedIds: Set<UUID> = []
        var pinnedOrder: [UUID]?
    }

    private weak var store: CountdownStore?
    private var engine: CKSyncEngine?
    private var metadata = CountdownSyncMetadata.load()
    /// Photos attached to records still being sent, by record name; they
    /// become the record's `serverPhoto` once the server confirms the save.
    private var inFlightPhotos: [String: CountdownItem.PhotoFingerprint] = [:]

    private init() {}

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    // MARK: Lifecycle

    /// Called once at launch; syncs unless the user turned it off.
    func start(with store: CountdownStore) {
        self.store = store
        if isEnabled {
            startEngine()
        }
    }

    /// Follows the Settings toggle.
    func setEnabled(_ enabled: Bool) {
        if enabled {
            startEngine()
        } else {
            stopEngine()
        }
    }

    /// Fetches other devices' edits now rather than waiting for their push.
    func fetchChanges() {
        guard let engine else { return }
        Task {
            try? await engine.fetchChanges()
        }
    }

    private func startEngine() {
        guard engine == nil, store != nil else { return }
        let configuration = CKSyncEngine.Configuration(
            database: CKContainer(identifier: Self.containerIdentifier).privateCloudDatabase,
            stateSerialization: metadata.stateSerialization,
            delegate: self
        )
        let engine = CKSyncEngine(configuration)
        self.engine = engine

        let saves = metadata.pendingSaves.map { CKSyncEngine.PendingRecordZoneChange.saveRecord(recordID(named: $0)) }
        let deletes = metadata.pendingDeletes.map { CKSyncEngine.PendingRecordZoneChange.deleteRecord(recordID(named: $0)) }
        metadata.pendingSaves = []
        metadata.save()
        guard !saves.isEmpty || !deletes.isEmpty else { return }
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
        engine.state.add(pendingRecordZoneChanges: deletes + saves)
    }

    private func stopEngine() {
        guard let engine else { return }
        // Edits still waiting to go out are sent once sync is back on;
        // deletions are in `pendingDeletes` already.
        for case .saveRecord(let recordID) in engine.state.pendingRecordZoneChanges {
            metadata.pendingSaves.insert(recordID.recordName)
        }
        metadata.save()
        self.engine = nil
        inFlightPhotos = [:]
        Task {
            await engine.cancelOperations()
        }
    }

    // MARK: Local edits

    /// Reports an edit to the countdown list: added and changed countdowns
    /// are uploaded, removed ones deleted.
    func countdownsDidChange(from oldItems: [CountdownItem], to newItems: [CountdownItem]) {
        let oldItemsById = Dictionary(oldItems.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let newIds = Set(newItems.map(\.id))
        let saved = newItems
            .filter { oldItemsById[$0.id] != $0 }
            .map { CountdownItem.recordID(for: $0.id, in: Self.zoneID) }
        let deleted = oldItems
            .filter { !newIds.contains($0.id) }
            .map { CountdownItem.recordID(for: $0.id, in: Self.zoneID) }
        recordLocalChanges(saved: saved, deleted: deleted)
    }

    /// Reports a new arrangement of Home's pinned countdowns.
    func pinnedOrderDidChange() {
        recordLocalChanges(saved: [Self.homeLayoutRecordID], deleted: [])
    }

    private func recordLocalChanges(saved: [CKRecord.ID], deleted: [CKRecord.ID]) {
        guard !saved.isEmpty || !deleted.isEmpty else { return }
        let now = Date()
        for recordID in saved {
            updateState(of: recordID) { $0.modifiedAt = now }
        }
        for recordID in deleted {
            metadata.records[recordID.recordName] = nil
            metadata.pendingSaves.remove(recordID.recordName)
            metadata.pendingDeletes.insert(recordID.recordName)
        }
        if let engine {
            engine.state.add(pendingRecordZoneChanges: saved.map { .saveRecord($0) } + deleted.map { .deleteRecord($0) })
        } else {
            metadata.pendingSaves.formUnion(saved.map(\.recordName))
        }
        metadata.save()
    }

    // MARK: Records

    private func recordID(named name: String) -> CKRecord.ID {
        CKRecord.ID(recordName: name, zoneID: Self.zoneID)
    }

    /// When the user last edited a record. Countdowns not edited since sync
    /// started count from their creation, the layout from never.
    private func modifiedAt(of recordID: CKRecord.ID) -> Date {
        if let state = metadata.records[recordID.recordName] {
            return state.modifiedAt
        }
        if let id = CountdownItem.id(from: recordID),
           let item = store?.countdowns.first(where: { $0.id == id }) {
            return item.createdAt
        }
        return .distantPast
    }

    private func updateState(of recordID: CKRecord.ID, _ update: (inout CountdownSyncMetadata.RecordState) -> Void) {
        var state = metadata.records[recordID.recordName] ?? .init(modifiedAt: modifiedAt(of: recordID))
        update(&state)
        metadata.records[recordID.recordName] = state
    }

    private func isLocalEditNewer(than record: CKRecord) -> Bool {
        let remoteModifiedAt = record.encryptedValues[CountdownItem.RecordField.modifiedAt] as? Date ?? .distantPast
        return modifiedAt(of: record.recordID) > remoteModifiedAt
    }

    /// The record to upload for a pending save, built on the last server
    /// version's system fields so CloudKit can tell whether it's current.
    private func recordToSave(with recordID: CKRecord.ID) -> CKRecord? {
        guard let store, let engine else { return nil }
        let state = metadata.records[recordID.recordName]
        let serverVersion = state?.systemFields.flatMap { CKRecord.fromSystemFields($0) }

        if recordID == Self.homeLayoutRecordID {
            let record = serverVersion ?? CKRecord(recordType: Self.homeLayoutRecordType, recordID: recordID)
            record.encryptedValues[Self.pinnedOrderField] = store.pinnedOrder.map(\.uuidString).joined(separator: ",")
            record.encryptedValues[CountdownItem.RecordField.modifiedAt] = modifiedAt(of: recordID)
            return record
        }

        guard let id = CountdownItem.id(from: recordID),
              let item = store.countdowns.first(where: { $0.id == id }) else {
            // Deleted since the save was queued.
            engine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
            return nil
        }
        let record = serverVersion ?? CKRecord(recordType: CountdownItem.recordType, recordID: recordID)
        item.write(to: record, modifiedAt: modifiedAt(of: recordID))

        let photo = CountdownItem.PhotoFingerprint(item.photoData)
        if serverVersion == nil || state?.serverPhoto != photo {
            if let photoData = item.photoData {
                // Without a staged file the photo waits for the next save.
                guard let url = stageTemporaryPhoto(photoData, for: recordID) else { return record }
                record[CountdownItem.RecordField.photo] = CKAsset(fileURL: url)
            } else {
                record[CountdownItem.RecordField.photo] = nil
            }
            inFlightPhotos[recordID.recordName] = photo
        }
        return record
    }

    /// Takes the server's version of a record into `changes`, remembering
    /// its system fields, edit time and photo.
    private func adopt(_ record: CKRecord, into changes: inout RemoteChanges) {
        let remoteModifiedAt = record.encryptedValues[CountdownItem.RecordField.modifiedAt] as? Date ?? .distantPast
        switch record.recordType {
        case CountdownItem.recordType:
            guard let id = CountdownItem.id(from: record.recordID) else { return }
            let localPhoto = store?.countdowns.first(where: { $0.id == id })?.photoData
            let (photoData, serverPhoto) = Self.photo(in: record, keeping: localPhoto)
            guard let item = CountdownItem(record: record, photoData: photoData) else { return }
            changes.upserts.append(item)
            updateState(of: record.recordID) {
                $0.systemFields = record.systemFieldsData
                $0.modifiedAt = remoteModifiedAt
                $0.serverPhoto = serverPhoto
            }
        case Self.homeLayoutRecordType:
            let pinnedOrder = record.encryptedValues[Self.pinnedOrderField] as? String ?? ""
            changes.pinnedOrder = pinnedOrder.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
            updateState(of: record.recordID) {
                $0.systemFields = record.systemFieldsData
                $0.modifiedAt = remoteModifiedAt
            }
        default:
            break
        }
    }

    /// A fetched record's cover photo and its fingerprint. The asset is a
    /// temporary file, so it's read right away; one that can't be read
    /// keeps `localPhoto`, with the server's photo left unknown.
    private static func photo(in record: CKRecord, keeping localPhoto: Data?) -> (Data?, CountdownItem.PhotoFingerprint?) {
        guard let asset = record[CountdownItem.RecordField.photo] as? CKAsset else {
            return (nil, .noPhoto)
        }
        guard let url = asset.fileURL, let data = try? Data(contentsOf: url) else {
            return (localPhoto, nil)
        }
        return (data, CountdownItem.PhotoFingerprint(data))
    }

    private func apply(_ changes: RemoteChanges) {
        guard let store else { return }
        store.applyRemoteChanges(upserting: changes.upserts, deleting: changes.deletedIds)
        if let pinnedOrder = changes.pinnedOrder {
            store.applyRemotePinnedOrder(pinnedOrder)
        }
    }

    // MARK: Photo assets

    /// Writes a cover photo where its upload can read it; removed once the
    /// save went through or failed.
    private func stageTemporaryPhoto(_ data: Data, for recordID: CKRecord.ID) -> URL? {
        let url = temporaryPhotoURL(for: recordID)
        do {
            try FileManager.default.createDirectory(at: Self.temporaryPhotoDirectory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("Failed to stage countdown photo for upload: \(error)")
            return nil
        }
    }

    private func removeTemporaryPhoto(for recordID: CKRecord.ID) {
        try? FileManager.default.removeItem(at: temporaryPhotoURL(for: recordID))
    }

    private func temporaryPhotoURL(for recordID: CKRecord.ID) -> URL {
        Self.temporaryPhotoDirectory.appending(path: recordID.recordName.replacingOccurrences(of: ":", with: "-") + ".jpg")
    }

    // MARK: Events

    private func handleFetchedRecordZoneChanges(_ event: CKSyncEngine.Event.FetchedRecordZoneChanges) {
        guard let engine else { return }
        let pendingChanges = Set(engine.state.pendingRecordZoneChanges)
        var changes = RemoteChanges()

        for modification in event.modifications {
            let record = modification.record
            // A deletion made here that hasn't gone out yet wins over the edit.
            guard !metadata.pendingDeletes.contains(record.recordID.recordName) else { continue }
            if pendingChanges.contains(.saveRecord(record.recordID)), isLocalEditNewer(than: record) {
                // The local edit goes up on top of this version, photo included.
                updateState(of: record.recordID) {
                    $0.systemFields = record.systemFieldsData
                    $0.serverPhoto = nil
                }
                continue
            }
            engine.state.remove(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
            adopt(record, into: &changes)
        }

        for deletion in event.deletions {
            let recordID = deletion.recordID
            engine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
            metadata.records[recordID.recordName] = nil
            metadata.pendingDeletes.remove(recordID.recordName)
            if let id = CountdownItem.id(from: recordID) {
                changes.deletedIds.insert(id)
            }
        }

        apply(changes)
        metadata.save()
    }

    private func handleSentRecordZoneChanges(_ event: CKSyncEngine.Event.SentRecordZoneChanges) {
        guard let engine else { return }
        var changes = RemoteChanges()
        var retries: [CKSyncEngine.PendingRecordZoneChange] = []
        var needsZone = false

        for record in event.savedRecords {
            let photo = inFlightPhotos.removeValue(forKey: record.recordID.recordName)
            updateState(of: record.recordID) {
                $0.systemFields = record.systemFieldsData
                if let photo {
                    $0.serverPhoto = photo
                }
            }
            removeTemporaryPhoto(for: record.recordID)
        }

        for failure in event.failedRecordSaves {
            let recordID = failure.record.recordID
            inFlightPhotos[recordID.recordName] = nil
            removeTemporaryPhoto(for: recordID)

            switch failure.error.code {
            case .serverRecordChanged:
                // Another device saved since this one last fetched the record.
                guard let serverRecord = failure.error.serverRecord,
                      !metadata.pendingDeletes.contains(recordID.recordName) else { continue }
                if isLocalEditNewer(than: serverRecord) {
                    updateState(of: recordID) {
                        $0.systemFields = serverRecord.systemFieldsData
                        $0.serverPhoto = nil
                    }
                    retries.append(.saveRecord(recordID))
                } else {
                    adopt(serverRecord, into: &changes)
                }
            case .zoneNotFound:
                // The zone was never created, or was deleted: save it, then the
                // record from scratch.
                needsZone = true
                updateState(of: recordID) {
                    $0.systemFields = nil
                    $0.serverPhoto = nil
                }
                retries.append(.saveRecord(recordID))
            case .unknownItem:
                if let id = CountdownItem.id(from: recordID) {
                    // Deleted on another device since this one last fetched
                    // it; the deletion wins.
                    metadata.records[recordID.recordName] = nil
                    changes.deletedIds.insert(id)
                } else {
                    updateState(of: recordID) { $0.systemFields = nil }
                    retries.append(.saveRecord(recordID))
                }
            case .quotaExceeded:
                // The engine waits for free iCloud space but drops the change.
                retries.append(.saveRecord(recordID))
            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                 .notAuthenticated, .operationCancelled, .requestRateLimited:
                break
            default:
                print("Failed to sync countdown record \(recordID.recordName): \(failure.error)")
            }
        }

        for recordID in event.deletedRecordIDs {
            metadata.pendingDeletes.remove(recordID.recordName)
        }
        for (recordID, error) in event.failedRecordDeletes {
            switch error.code {
            case .unknownItem, .zoneNotFound:
                metadata.pendingDeletes.remove(recordID.recordName)
            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                 .notAuthenticated, .operationCancelled, .requestRateLimited:
                break
            default:
                print("Failed to delete countdown record \(recordID.recordName): \(error)")
            }
        }

        if needsZone {
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
        }
        engine.state.add(pendingRecordZoneChanges: retries)
        apply(changes)
        metadata.save()
    }

    private func handleFetchedDatabaseChanges(_ event: CKSyncEngine.Event.FetchedDatabaseChanges) {
        for deletion in event.deletions where deletion.zoneID == Self.zoneID {
            switch deletion.reason {
            case .encryptedDataReset:
                // Resetting end-to-end encryption during account recovery lost
                // the encrypted fields; upload everything again.
                for name in metadata.records.keys {
                    metadata.records[name]?.systemFields = nil
                    metadata.records[name]?.serverPhoto = nil
                }
                uploadAllLocalData()
            case .purged, .deleted:
                // TouchTime's data was deleted from iCloud (in Settings);
                // remove it here too rather than upload it again.
                clearLocalData()
            @unknown default:
                break
            }
        }
        metadata.save()
    }

    private func handleAccountChange(_ event: CKSyncEngine.Event.AccountChange) {
        switch event.changeType {
        case .signIn(let currentUser):
            // A different Apple Account than last time: the countdowns here
            // belong to the previous one.
            if let previousUser = metadata.userRecordName, previousUser != currentUser.recordName {
                clearLocalData()
            }
            metadata.userRecordName = currentUser.recordName
            uploadAllLocalData()
        case .switchAccounts(_, let currentUser):
            clearLocalData()
            metadata.userRecordName = currentUser.recordName
        case .signOut:
            // The countdowns stay on the device; `userRecordName` stays too,
            // so the next sign-in can tell whether it's the same account.
            break
        @unknown default:
            break
        }
        metadata.save()
    }

    /// Queues everything on the device, as on the first sync: records the
    /// server lacks are created, ones it has go through conflict handling.
    private func uploadAllLocalData() {
        guard let engine, let store else { return }
        var changes = store.countdowns.map {
            CKSyncEngine.PendingRecordZoneChange.saveRecord(CountdownItem.recordID(for: $0.id, in: Self.zoneID))
        }
        changes.append(.saveRecord(Self.homeLayoutRecordID))
        changes += metadata.pendingDeletes.map { .deleteRecord(recordID(named: $0)) }
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
        engine.state.add(pendingRecordZoneChanges: changes)
    }

    /// Removes the countdowns of an iCloud account that's no longer the one
    /// signed in, along with everything recorded about their sync.
    private func clearLocalData() {
        metadata.records = [:]
        metadata.pendingSaves = []
        metadata.pendingDeletes = []
        inFlightPhotos = [:]
        guard let store else { return }
        store.applyRemoteChanges(upserting: [], deleting: Set(store.countdowns.map(\.id)))
        store.applyRemotePinnedOrder([])
    }
}

extension CountdownSyncManager: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        // Events from an engine the Settings toggle has since stopped.
        guard syncEngine === engine else { return }
        switch event {
        case .stateUpdate(let update):
            metadata.stateSerialization = update.stateSerialization
            metadata.save()
        case .accountChange(let change):
            handleAccountChange(change)
        case .fetchedDatabaseChanges(let changes):
            handleFetchedDatabaseChanges(changes)
        case .fetchedRecordZoneChanges(let changes):
            handleFetchedRecordZoneChanges(changes)
        case .sentRecordZoneChanges(let sent):
            handleSentRecordZoneChanges(sent)
        case .sentDatabaseChanges(let sent):
            for failure in sent.failedZoneSaves {
                print("Failed to create the countdown sync zone: \(failure.error)")
            }
        case .willFetchChanges, .willFetchRecordZoneChanges, .didFetchRecordZoneChanges,
             .didFetchChanges, .willSendChanges, .didSendChanges:
            break
        @unknown default:
            break
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard syncEngine === engine else { return nil }
        let scope = context.options.scope
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { recordID in
            await self.recordToSave(with: recordID)
        }
    }
}
