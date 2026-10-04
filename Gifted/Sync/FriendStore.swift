//
//  FriendStore.swift
//  Gifted
//
//  Applies records fetched from friends' shared zones to the local read-only copies.
//  Kept separate from FriendsSync so it can be tested without iCloud.
//

import CloudKit
import Foundation
import SwiftData

struct FriendStore {
    let context: ModelContext

    // MARK: Friends

    func friend(ownerName: String) -> Friend? {
        try? context.fetch(FetchDescriptor<Friend>(predicate: #Predicate { $0.ownerName == ownerName })).first
    }

    /// Finds or creates the friend for a shared zone, updating their name when one is known.
    @discardableResult
    func ensureFriend(ownerName: String, displayName: String? = nil) -> Friend {
        if let existing = friend(ownerName: ownerName) {
            if let displayName, !displayName.isEmpty { existing.displayName = displayName }
            return existing
        }
        let friend = Friend(ownerName: ownerName, displayName: displayName ?? "Friend")
        context.insert(friend)
        return friend
    }

    func removeFriend(ownerName: String) {
        friend(ownerName: ownerName).map(context.delete)
    }

    func removeAllFriends() {
        for friend in (try? context.fetch(FetchDescriptor<Friend>())) ?? [] {
            context.delete(friend)
        }
    }

    // MARK: Records

    func apply(modifications records: [CKRecord], deletions: [(CKRecord.ID, CKRecord.RecordType)]) {
        // Shares and lists first so items in the same batch can link to them.
        for record in records {
            if let share = record as? CKShare {
                ensureFriend(ownerName: share.recordID.zoneID.ownerName,
                             displayName: ShareTitle.ownerDisplayName(for: share))
            }
        }
        for record in records where record.recordType == CloudSchema.RecordType.wishlist {
            upsertWishlist(from: record)
        }
        for record in records where record.recordType == CloudSchema.RecordType.item {
            upsertItem(from: record)
        }
        for (recordID, recordType) in deletions {
            let key = FriendKey.make(ownerName: recordID.zoneID.ownerName, recordName: recordID.recordName)
            switch recordType {
            case CloudSchema.RecordType.wishlist: wishlist(key: key).map(context.delete)
            case CloudSchema.RecordType.item: item(key: key).map(context.delete)
            default: break
            }
        }
    }

    private func upsertWishlist(from record: CKRecord) {
        let owner = record.recordID.zoneID.ownerName
        let list = wishlist(ownerName: owner, recordName: record.recordID.recordName)
        list.apply(record)
    }

    private func upsertItem(from record: CKRecord) {
        let owner = record.recordID.zoneID.ownerName
        let recordName = record.recordID.recordName
        let key = FriendKey.make(ownerName: owner, recordName: recordName)
        let item = item(key: key) ?? {
            let new = FriendItem(ownerName: owner, recordName: recordName)
            context.insert(new)
            new.friend = ensureFriend(ownerName: owner)
            return new
        }()
        let fields = ItemRecordFields(record)
        item.apply(fields)
        if let listName = fields.wishlistRecordName, item.wishlist?.recordName != listName {
            item.wishlist = wishlist(ownerName: owner, recordName: listName)
        }
    }

    /// Finds or creates a list. A list created here because one of its items arrived
    /// first gets its real name when its own record arrives.
    private func wishlist(ownerName: String, recordName: String) -> FriendWishlist {
        let key = FriendKey.make(ownerName: ownerName, recordName: recordName)
        if let existing = wishlist(key: key) { return existing }
        let list = FriendWishlist(ownerName: ownerName, recordName: recordName, name: "Wishlist")
        context.insert(list)
        list.friend = ensureFriend(ownerName: ownerName)
        return list
    }

    private func wishlist(key: String) -> FriendWishlist? {
        try? context.fetch(FetchDescriptor<FriendWishlist>(predicate: #Predicate { $0.key == key })).first
    }

    private func item(key: String) -> FriendItem? {
        try? context.fetch(FetchDescriptor<FriendItem>(predicate: #Predicate { $0.key == key })).first
    }
}
