//
//  FriendsSync.swift
//  Gifted
//
//  Mirrors the wishlists friends have shared with this user. Each accepted invite
//  appears as one zone (the friend's "Wishlists" zone) in the user's shared database.
//  Friends' data is read-only, so this engine only ever fetches; the one change it
//  sends is deleting a zone, which is how a participant leaves a share.
//

import CloudKit
import Foundation
import Observation
import os
import SwiftData

@Observable
final class FriendsSync {
    private(set) var isJoining = false
    private(set) var lastError: String?
    /// Set after an invite is accepted so the UI can show the new friend.
    private(set) var lastJoinedOwnerName: String?

    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let store: FriendStore
    @ObservationIgnored private let stateURL: URL
    @ObservationIgnored private var engine: CKSyncEngine?
    @ObservationIgnored private lazy var container = CKContainer(identifier: AppConfig.cloudKitContainerID)
    @ObservationIgnored private let logger = Logger(subsystem: "com.edwintang.gifted", category: "FriendsSync")

    init(
        modelContext: ModelContext,
        stateURL: URL = .applicationSupportDirectory.appending(path: "SharedSyncEngineState.json")
    ) {
        self.modelContext = modelContext
        self.store = FriendStore(context: modelContext)
        self.stateURL = stateURL
    }

    func start() {
        guard engine == nil else { return }
        let configuration = CKSyncEngine.Configuration(
            database: container.sharedCloudDatabase,
            stateSerialization: loadState(),
            delegate: self
        )
        engine = CKSyncEngine(configuration)
    }

    func syncNow() async {
        do {
            try await engine?.fetchChanges()
        } catch {
            logger.error("Fetching friends' wishlists failed: \(error)")
        }
    }

    // MARK: - Joining and leaving

    /// Called when the user opens a friend's invite link.
    func accept(_ metadata: CKShare.Metadata) async {
        let ownerName = metadata.share.recordID.zoneID.ownerName
        guard metadata.participantRole != .owner else {
            lastError = "That's your own invite link. Send it to friends so they can see your wishlists."
            return
        }

        isJoining = true
        lastError = nil
        defer { isJoining = false }
        do {
            _ = try await container.accept(metadata)
            store.ensureFriend(ownerName: ownerName, displayName: ShareTitle.ownerDisplayName(for: metadata.share))
            save()
            lastJoinedOwnerName = ownerName
            try await engine?.fetchChanges()
        } catch {
            logger.error("Couldn't accept share: \(error)")
            lastError = "Couldn't open that invite. Check you're signed in to iCloud and try again."
        }
    }

    /// Stops following a friend: leaves their share and forgets their lists locally.
    func remove(_ friend: Friend) {
        let zoneID = CKRecordZone.ID(zoneName: CloudSchema.zoneID.zoneName, ownerName: friend.ownerName)
        engine?.state.add(pendingDatabaseChanges: [.deleteZone(zoneID)])
        store.removeFriend(ownerName: friend.ownerName)
        save()
    }

    func clearLastJoined() {
        lastJoinedOwnerName = nil
    }

    // MARK: - Persistence

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
            logger.error("Couldn't save shared sync state: \(error)")
        }
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            logger.error("Couldn't save friends' data: \(error)")
        }
    }
}

// MARK: - CKSyncEngineDelegate

extension FriendsSync: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            saveState(update.stateSerialization)

        case .accountChange(let change):
            switch change.changeType {
            case .signOut, .switchAccounts:
                // Shares were accepted by the previous account.
                store.removeAllFriends()
                save()
                try? FileManager.default.removeItem(at: stateURL)
                engine = nil
                start()
            default:
                break
            }

        case .fetchedDatabaseChanges(let changes):
            for modification in changes.modifications {
                store.ensureFriend(ownerName: modification.zoneID.ownerName)
            }
            for deletion in changes.deletions {
                // The friend stopped sharing, removed this user, or this user left.
                store.removeFriend(ownerName: deletion.zoneID.ownerName)
            }
            save()

        case .fetchedRecordZoneChanges(let changes):
            store.apply(
                modifications: changes.modifications.map(\.record),
                deletions: changes.deletions.map { ($0.recordID, $0.recordType) }
            )
            save()

        case .sentDatabaseChanges(let sent):
            for zoneID in sent.deletedZoneIDs {
                store.removeFriend(ownerName: zoneID.ownerName)
            }
            for (zoneID, error) in sent.failedZoneDeletes {
                logger.error("Couldn't leave \(zoneID.ownerName)'s share: \(error)")
            }
            save()

        case .sentRecordZoneChanges, .willFetchChanges, .willFetchRecordZoneChanges,
             .didFetchRecordZoneChanges, .didFetchChanges, .willSendChanges, .didSendChanges:
            break

        @unknown default:
            logger.info("Unhandled shared sync event: \(event)")
        }
    }

    /// Friends' wishlists are read-only here, so there are never records to send.
    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        nil
    }
}
