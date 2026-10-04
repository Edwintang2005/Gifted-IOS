//
//  FriendStoreTests.swift
//  GiftedTests
//

import CloudKit
import Foundation
import SwiftData
import Testing
@testable import Gifted

struct FriendStoreTests {
    let container = GiftedSchema.makeInMemoryContainer()
    var context: ModelContext { container.mainContext }
    var store: FriendStore { FriendStore(context: context) }

    private func zone(_ owner: String) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: CloudSchema.zoneID.zoneName, ownerName: owner)
    }

    private func listRecord(_ name: String, owner: String, title: String) -> CKRecord {
        let record = CKRecord(recordType: CloudSchema.RecordType.wishlist,
                              recordID: CKRecord.ID(recordName: name, zoneID: zone(owner)))
        record[CloudSchema.Field.name] = title
        return record
    }

    private func itemRecord(_ name: String, owner: String, title: String, list: String) -> CKRecord {
        let record = CKRecord(recordType: CloudSchema.RecordType.item,
                              recordID: CKRecord.ID(recordName: name, zoneID: zone(owner)))
        record[CloudSchema.Field.title] = title
        record[CloudSchema.Field.price] = "25.50"
        record[CloudSchema.Field.wishlist] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: list, zoneID: zone(owner)), action: .none)
        return record
    }

    private func allFriends() -> [Friend] {
        (try? context.fetch(FetchDescriptor<Friend>())) ?? []
    }

    @Test func friendsWithTheSameRecordNamesStayApart() throws {
        // Everyone's first list is "default-wishlist".
        store.apply(modifications: [
            listRecord(AppConfig.defaultWishlistID, owner: "alice", title: "Alice's list"),
            listRecord(AppConfig.defaultWishlistID, owner: "bob", title: "Bob's list"),
            itemRecord("i1", owner: "alice", title: "Scarf", list: AppConfig.defaultWishlistID),
            itemRecord("i1", owner: "bob", title: "Kite", list: AppConfig.defaultWishlistID),
        ], deletions: [])

        let alice = try #require(store.friend(ownerName: "alice"))
        let bob = try #require(store.friend(ownerName: "bob"))
        #expect(alice.wishlists.map(\.name) == ["Alice's list"])
        #expect(bob.wishlists.map(\.name) == ["Bob's list"])
        #expect(alice.items.map(\.title) == ["Scarf"])
        #expect(bob.items.first?.wishlist?.name == "Bob's list")
        #expect(bob.items.first?.price == Decimal(string: "25.50"))
    }

    @Test func itemArrivingBeforeItsListIsLinkedWhenTheListArrives() throws {
        store.apply(modifications: [itemRecord("i1", owner: "alice", title: "Scarf", list: "xmas")], deletions: [])
        let friend = try #require(store.friend(ownerName: "alice"))
        #expect(friend.wishlists.map(\.name) == ["Wishlist"])

        store.apply(modifications: [listRecord("xmas", owner: "alice", title: "Christmas")], deletions: [])
        #expect(friend.wishlists.count == 1)
        #expect(friend.items.first?.wishlist?.name == "Christmas")
    }

    @Test func shareRecordNamesTheFriend() throws {
        let share = CKShare(recordZoneID: zone("alice"))
        share[CKShare.SystemFieldKey.title] = ShareTitle.make(ownerName: "Alice")
        store.apply(modifications: [share], deletions: [])
        #expect(store.friend(ownerName: "alice")?.displayName == "Alice")
    }

    @Test func deletionsAndRemovalCleanUp() throws {
        store.apply(modifications: [
            listRecord("l1", owner: "alice", title: "Birthday"),
            itemRecord("i1", owner: "alice", title: "Scarf", list: "l1"),
            itemRecord("i2", owner: "alice", title: "Hat", list: "l1"),
        ], deletions: [])
        store.apply(modifications: [], deletions: [
            (CKRecord.ID(recordName: "i1", zoneID: zone("alice")), CloudSchema.RecordType.item),
        ])
        try context.save() // FriendsSync saves after every applied batch.
        let friend = try #require(store.friend(ownerName: "alice"))
        #expect(friend.items.map(\.title) == ["Hat"])

        store.removeFriend(ownerName: "alice")
        try context.save()
        #expect(allFriends().isEmpty)
        #expect(((try? context.fetchCount(FetchDescriptor<FriendItem>())) ?? -1) == 0)
        #expect(((try? context.fetchCount(FetchDescriptor<FriendWishlist>())) ?? -1) == 0)
    }

    @Test func friendsDataNeverTouchesOwnLists() throws {
        let library = Library(context: context, sync: nil)
        library.ensureDefaultWishlist()
        store.apply(modifications: [listRecord(AppConfig.defaultWishlistID, owner: "alice", title: "Alice's")],
                    deletions: [])
        #expect(library.allWishlists().map(\.name) == [AppConfig.defaultWishlistName])
    }
}

struct ShareTitleTests {
    @Test func roundTripsOwnerName() {
        #expect(ShareTitle.make(ownerName: " Edwin ") == "Edwin\u{2019}s Wishlists")
        #expect(ShareTitle.ownerName(from: "Edwin\u{2019}s Wishlists") == "Edwin")
        #expect(ShareTitle.ownerName(from: "Some other title") == "Some other title")
        #expect(ShareTitle.ownerName(from: "  ") == nil)
    }
}
