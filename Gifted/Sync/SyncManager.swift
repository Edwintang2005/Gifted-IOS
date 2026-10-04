//
//  SyncManager.swift
//  Gifted
//
//  Keeps the local SwiftData store in sync with the user's private iCloud database
//  using CKSyncEngine. The engine decides when to fetch and send; this class tells it
//  what changed locally, builds records on request and applies what comes back.
//
//  Conflict policy:
//  - An object that has never reached the server loses to the server's copy
//    (e.g. the default wishlist created on a second device before its first sync).
//  - An object that has synced before and has unsent local edits wins.
//

import CloudKit
import Foundation
import Observation
import os
import SwiftData

/// What the rest of the app uses to report local changes that need uploading.
protocol SyncChangeRecorder: AnyObject {
    func recordSaves(_ ids: [String])
    func recordDeletes(_ ids: [String])
}

@Observable
final class SyncManager: SyncChangeRecorder {
    enum AccountState: Equatable {
        case unknown, available, noAccount, restricted, temporarilyUnavailable
    }

    private(set) var account: AccountState = .unknown
    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date? {
        didSet { UserDefaults.standard.set(lastSyncedAt, forKey: "lastSyncedAt") }
    }
    private(set) var lastError: String?

    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let stateURL: URL
    @ObservationIgnored private var engine: CKSyncEngine?
    @ObservationIgnored private lazy var container = CKContainer(identifier: AppConfig.cloudKitContainerID)
    @ObservationIgnored private let logger = Logger(subsystem: "com.edwintang.gifted", category: "Sync")

    /// Counts local edits per record so an edit made while an earlier version of the
    /// same record is mid-upload isn't marked as synced when that upload succeeds.
    @ObservationIgnored private var localEditCount: [String: Int] = [:]
    @ObservationIgnored private var sentEditCount: [String: Int] = [:]

    private static let batchSize = 100

    init(
        modelContext: ModelContext,
        stateURL: URL = .applicationSupportDirectory.appending(path: "SyncEngineState.json")
    ) {
        self.modelContext = modelContext
        self.stateURL = stateURL
        self.lastSyncedAt = UserDefaults.standard.object(forKey: "lastSyncedAt") as? Date
    }

    // MARK: - Lifecycle

    func start() {
        guard engine == nil else { return }
        startEngine()
        Task {
            await refreshAccountStatus()
            for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
                await refreshAccountStatus()
            }
        }
    }

    private func startEngine() {
        let savedState = loadState()
        let configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: savedState,
            delegate: self
        )
        let engine = CKSyncEngine(configuration)
        self.engine = engine
        if savedState == nil {
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: CloudSchema.zoneID))])
        }
        enqueueUnsyncedObjects()
    }

    /// Fetches then sends immediately rather than waiting for the engine's own schedule.
    func syncNow() async {
        guard let engine else { return }
        do {
            try await engine.fetchChanges()
            try await engine.sendChanges()
        } catch {
            logger.error("Manual sync failed: \(error)")
            lastError = Self.message(for: error)
        }
    }

    func refreshAccountStatus() async {
        do {
            account = switch try await container.accountStatus() {
            case .available: .available
            case .noAccount: .noAccount
            case .restricted: .restricted
            case .temporarilyUnavailable: .temporarilyUnavailable
            case .couldNotDetermine: .unknown
            @unknown default: .unknown
            }
        } catch {
            account = .unknown
        }
    }

    // MARK: - SyncChangeRecorder

    func recordSaves(_ ids: [String]) {
        for id in ids { localEditCount[id, default: 0] += 1 }
        engine?.state.add(pendingRecordZoneChanges: ids.map { .saveRecord(CloudSchema.recordID(for: $0)) })
    }

    func recordDeletes(_ ids: [String]) {
        guard let engine else { return }
        let recordIDs = ids.map(CloudSchema.recordID(for:))
        engine.state.remove(pendingRecordZoneChanges: recordIDs.map { .saveRecord($0) })
        engine.state.add(pendingRecordZoneChanges: recordIDs.map { .deleteRecord($0) })
    }

    /// Picks up anything changed while the engine wasn't running, including items
    /// imported from the share extension.
    private func enqueueUnsyncedObjects() {
        let lists = (try? modelContext.fetch(FetchDescriptor<Wishlist>(predicate: #Predicate { $0.needsUpload }))) ?? []
        let items = (try? modelContext.fetch(FetchDescriptor<WishItem>(predicate: #Predicate { $0.needsUpload }))) ?? []
        let ids = lists.map(\.id) + items.map(\.id)
        guard !ids.isEmpty else { return }
        engine?.state.add(pendingRecordZoneChanges: ids.map { .saveRecord(CloudSchema.recordID(for: $0)) })
    }

    // MARK: - State persistence

    private func loadState() -> CKSyncEngine.State.Serialization? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func saveState(_ state: CKSyncEngine.State.Serialization) {
        do {
            try FileManager.default.createDirectory(
                at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(to: stateURL, options: .atomic)
        } catch {
            logger.error("Couldn't save sync state: \(error)")
        }
    }

    // MARK: - Local lookups

    private func wishlist(id: String) -> Wishlist? {
        try? modelContext.fetch(FetchDescriptor<Wishlist>(predicate: #Predicate { $0.id == id })).first
    }

    private func item(id: String) -> WishItem? {
        try? modelContext.fetch(FetchDescriptor<WishItem>(predicate: #Predicate { $0.id == id })).first
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            logger.error("Couldn't save local changes from sync: \(error)")
        }
    }

    private static func message(for error: Error) -> String {
        guard let ckError = error as? CKError else { return error.localizedDescription }
        switch ckError.code {
        case .notAuthenticated: return "Sign in to iCloud to sync your wishlists."
        case .quotaExceeded: return "Your iCloud storage is full, so changes aren't syncing."
        case .networkUnavailable, .networkFailure: return "You're offline. Changes will sync when you reconnect."
        default: return ckError.localizedDescription
        }
    }
}

// MARK: - CKSyncEngineDelegate

extension SyncManager: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            saveState(update.stateSerialization)
        case .accountChange(let change):
            handleAccountChange(change, engine: syncEngine)
        case .fetchedDatabaseChanges(let changes):
            handleFetchedDatabaseChanges(changes, engine: syncEngine)
        case .fetchedRecordZoneChanges(let changes):
            applyFetchedRecordZoneChanges(changes)
        case .sentRecordZoneChanges(let sent):
            handleSentRecordZoneChanges(sent, engine: syncEngine)
        case .sentDatabaseChanges(let sent):
            for failure in sent.failedZoneSaves {
                logger.error("Couldn't create zone \(failure.zone.zoneID.zoneName): \(failure.error)")
                lastError = Self.message(for: failure.error)
            }
        case .willFetchChanges, .willSendChanges:
            isSyncing = true
            lastError = nil
        case .didFetchChanges, .didSendChanges:
            isSyncing = false
            // The engine also cycles when it can't reach iCloud; only count real syncs.
            if account == .available { lastSyncedAt = .now }
        case .willFetchRecordZoneChanges, .didFetchRecordZoneChanges:
            break
        @unknown default:
            logger.info("Unhandled sync event: \(event)")
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        var recordsToSave: [CKRecord] = []
        var recordIDsToDelete: [CKRecord.ID] = []
        var orphanedSaves: [CKSyncEngine.PendingRecordZoneChange] = []

        for change in pending {
            guard recordsToSave.count + recordIDsToDelete.count < Self.batchSize else { break }
            switch change {
            case .saveRecord(let recordID):
                let id = recordID.recordName
                if let record = wishlist(id: id)?.makeRecord() ?? item(id: id)?.makeRecord() {
                    recordsToSave.append(record)
                    sentEditCount[id] = localEditCount[id, default: 0]
                } else {
                    // Deleted locally before it was ever sent.
                    orphanedSaves.append(change)
                }
            case .deleteRecord(let recordID):
                recordIDsToDelete.append(recordID)
            @unknown default:
                break
            }
        }

        if !orphanedSaves.isEmpty {
            syncEngine.state.remove(pendingRecordZoneChanges: orphanedSaves)
        }
        guard !recordsToSave.isEmpty || !recordIDsToDelete.isEmpty else { return nil }
        return CKSyncEngine.RecordZoneChangeBatch(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)
    }

    // MARK: Account changes

    private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange, engine: CKSyncEngine) {
        switch change.changeType {
        case .signIn:
            reuploadEverything(engine: engine)
        case .signOut, .switchAccounts:
            // Local data belongs to the previous account.
            deleteAllLocalData()
            try? FileManager.default.removeItem(at: stateURL)
            self.engine = nil
            startEngine()
        @unknown default:
            break
        }
        Task { await refreshAccountStatus() }
    }

    private func reuploadEverything(engine: CKSyncEngine) {
        let lists = (try? modelContext.fetch(FetchDescriptor<Wishlist>())) ?? []
        let items = (try? modelContext.fetch(FetchDescriptor<WishItem>())) ?? []
        lists.forEach { $0.needsUpload = true }
        items.forEach {
            $0.needsUpload = true
            $0.imageNeedsUpload = $0.imageData != nil
        }
        save()
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: CloudSchema.zoneID))])
        let ids = lists.map(\.id) + items.map(\.id)
        engine.state.add(pendingRecordZoneChanges: ids.map { .saveRecord(CloudSchema.recordID(for: $0)) })
    }

    private func deleteAllLocalData() {
        for list in (try? modelContext.fetch(FetchDescriptor<Wishlist>())) ?? [] {
            modelContext.delete(list)
        }
        for item in (try? modelContext.fetch(FetchDescriptor<WishItem>())) ?? [] {
            modelContext.delete(item)
        }
        save()
    }

    // MARK: Fetched changes

    private func handleFetchedDatabaseChanges(_ changes: CKSyncEngine.Event.FetchedDatabaseChanges, engine: CKSyncEngine) {
        for deletion in changes.deletions where deletion.zoneID == CloudSchema.zoneID {
            switch deletion.reason {
            case .encryptedDataReset:
                // The user reset their encrypted iCloud data; our copy is now the only one.
                let lists = (try? modelContext.fetch(FetchDescriptor<Wishlist>())) ?? []
                let items = (try? modelContext.fetch(FetchDescriptor<WishItem>())) ?? []
                lists.forEach { $0.cloudSystemFields = nil }
                items.forEach { $0.cloudSystemFields = nil }
                reuploadEverything(engine: engine)
            default:
                // Deleted from another device or from iCloud settings.
                deleteAllLocalData()
            }
        }
    }

    private func applyFetchedRecordZoneChanges(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges) {
        let records = changes.modifications.map(\.record)
        // Lists first so items in the same batch can link to them.
        for record in records where record.recordType == CloudSchema.RecordType.wishlist {
            upsertWishlist(from: record)
        }
        for record in records where record.recordType == CloudSchema.RecordType.item {
            upsertItem(from: record)
        }
        for deletion in changes.deletions {
            let id = deletion.recordID.recordName
            switch deletion.recordType {
            case CloudSchema.RecordType.wishlist: wishlist(id: id).map(modelContext.delete)
            case CloudSchema.RecordType.item: item(id: id).map(modelContext.delete)
            default: break
            }
        }
        save()
    }

    private func upsertWishlist(from record: CKRecord) {
        let id = record.recordID.recordName
        let list = wishlist(id: id) ?? {
            let new = Wishlist(id: id, name: "")
            modelContext.insert(new)
            new.needsUpload = false
            return new
        }()
        let hasUnsentEdits = list.needsUpload && list.cloudSystemFields != nil
        if !hasUnsentEdits {
            list.apply(record)
            list.needsUpload = false
        }
        list.cloudSystemFields = record.encodedSystemFields
    }

    private func upsertItem(from record: CKRecord) {
        let id = record.recordID.recordName
        let item = item(id: id) ?? {
            let new = WishItem(id: id, title: "")
            modelContext.insert(new)
            new.needsUpload = false
            return new
        }()
        let hasUnsentEdits = item.needsUpload && item.cloudSystemFields != nil
        if !hasUnsentEdits {
            item.apply(record)
            item.needsUpload = false
            if let listID = WishItem.wishlistID(in: record), item.wishlist?.id != listID {
                item.wishlist = wishlist(id: listID) ?? placeholderWishlist(id: listID)
            }
        }
        item.cloudSystemFields = record.encodedSystemFields
    }

    /// Stands in for a list whose record hasn't arrived yet; filled in when it does.
    private func placeholderWishlist(id: String) -> Wishlist {
        let list = Wishlist(id: id, name: "Wishlist")
        modelContext.insert(list)
        list.needsUpload = false
        return list
    }

    // MARK: Sent changes

    private func handleSentRecordZoneChanges(_ sent: CKSyncEngine.Event.SentRecordZoneChanges, engine: CKSyncEngine) {
        var retries: [CKSyncEngine.PendingRecordZoneChange] = []
        var needsZone = false

        for record in sent.savedRecords {
            let id = record.recordID.recordName
            let editedSinceSend = localEditCount[id, default: 0] != sentEditCount[id, default: 0]
            if let list = wishlist(id: id) {
                list.cloudSystemFields = record.encodedSystemFields
                list.needsUpload = editedSinceSend
            } else if let item = item(id: id) {
                item.cloudSystemFields = record.encodedSystemFields
                item.needsUpload = editedSinceSend
                if !editedSinceSend { item.imageNeedsUpload = false }
            }
            if editedSinceSend { retries.append(.saveRecord(record.recordID)) }
        }

        for failure in sent.failedRecordSaves {
            let recordID = failure.record.recordID
            let id = recordID.recordName
            switch failure.error.code {
            case .serverRecordChanged:
                guard let serverRecord = failure.error.serverRecord else { continue }
                if resolveConflict(id: id, serverRecord: serverRecord) {
                    retries.append(.saveRecord(recordID))
                }
            case .zoneNotFound:
                needsZone = true
                wishlist(id: id)?.cloudSystemFields = nil
                item(id: id)?.cloudSystemFields = nil
                retries.append(.saveRecord(recordID))
            case .unknownItem:
                // Deleted on another device while we were editing it here.
                wishlist(id: id).map(modelContext.delete)
                item(id: id).map(modelContext.delete)
            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                 .notAuthenticated, .operationCancelled, .requestRateLimited, .batchRequestFailed:
                break // The engine retries these itself.
            default:
                logger.error("Couldn't save \(id): \(failure.error)")
                lastError = Self.message(for: failure.error)
            }
        }

        for (recordID, error) in sent.failedRecordDeletes where error.code != .unknownItem {
            logger.error("Couldn't delete \(recordID.recordName): \(error)")
        }

        if needsZone {
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: CloudSchema.zoneID))])
        }
        if !retries.isEmpty {
            engine.state.add(pendingRecordZoneChanges: retries)
        }
        save()
    }

    /// Returns true if the local version should be re-sent on top of the server's.
    private func resolveConflict(id: String, serverRecord: CKRecord) -> Bool {
        if let list = wishlist(id: id) {
            let localWins = list.cloudSystemFields != nil
            if !localWins {
                list.apply(serverRecord)
                list.needsUpload = false
            }
            list.cloudSystemFields = serverRecord.encodedSystemFields
            return localWins
        }
        if let item = item(id: id) {
            let localWins = item.cloudSystemFields != nil
            if !localWins {
                item.apply(serverRecord)
                item.needsUpload = false
            }
            item.cloudSystemFields = serverRecord.encodedSystemFields
            return localWins
        }
        return false
    }
}
