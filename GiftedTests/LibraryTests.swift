//
//  LibraryTests.swift
//  GiftedTests
//

import CloudKit
import Foundation
import SwiftData
import Testing
@testable import Gifted

final class RecorderSpy: SyncChangeRecorder {
    var saved: [String] = []
    var deleted: [String] = []
    func recordSaves(_ ids: [String]) { saved += ids }
    func recordDeletes(_ ids: [String]) { deleted += ids }
}

struct LibraryTests {
    let spy = RecorderSpy()
    let inbox = Inbox(directory: FileManager.default.temporaryDirectory
        .appending(path: "GiftedTests-\(UUID().uuidString)", directoryHint: .isDirectory))
    let container = GiftedSchema.makeInMemoryContainer()
    let library: Library

    init() {
        library = Library(context: container.mainContext, sync: spy, inbox: inbox)
    }

    @Test func defaultWishlistIsCreatedOnce() {
        let first = library.ensureDefaultWishlist()
        let second = library.ensureDefaultWishlist()
        #expect(first.id == AppConfig.defaultWishlistID)
        #expect(first.id == second.id)
        #expect(library.allWishlists().count == 1)
        #expect(spy.saved == [AppConfig.defaultWishlistID])
    }

    @Test func addingAndEditingItemsQueuesUploads() throws {
        let list = library.ensureDefaultWishlist()
        let item = library.addItem(ItemDraft(title: "  Boots  ", price: 249), to: list)
        #expect(item.title == "Boots")
        #expect(item.wishlist?.id == list.id)
        #expect(!item.imageNeedsUpload)

        var draft = ItemDraft(item)
        draft.imageData = Data([1, 2, 3])
        library.update(item, with: draft)
        #expect(item.imageNeedsUpload)
        #expect(spy.saved.filter { $0 == item.id }.count == 2)
    }

    @Test func deletingAListDeletesItsItemsEverywhere() {
        let list = library.createWishlist(named: "Birthday")
        let a = library.addItem(ItemDraft(title: "A"), to: list)
        let b = library.addItem(ItemDraft(title: "B"), to: list)
        let ids = [list.id, a.id, b.id]

        library.delete(list)

        #expect(Set(spy.deleted) == Set(ids))
        let remaining = (try? library.context.fetch(FetchDescriptor<WishItem>())) ?? []
        #expect(remaining.isEmpty)
    }

    @Test func importsShareExtensionInboxOnce() throws {
        let birthday = library.createWishlist(named: "Birthday")
        let entry = InboxEntry(wishlistID: birthday.id, title: "Shared thing", price: 20,
                               currencyCode: "AUD", link: URL(string: "https://example.com"))
        try inbox.add(entry, imageData: Data([9, 9]))

        #expect(library.importInbox() == 1)
        #expect(library.importInbox() == 0)
        #expect(inbox.pendingEntries().isEmpty)

        let item = try #require(birthday.items.first)
        #expect(item.id == entry.id)
        #expect(item.imageData == Data([9, 9]))
        #expect(item.needsUpload)
    }

    @Test func inboxEntryForMissingListGoesToDefault() throws {
        try inbox.add(InboxEntry(wishlistID: "gone", title: "Orphan", currencyCode: "AUD"), imageData: nil)
        library.importInbox()
        let list = library.ensureDefaultWishlist()
        #expect(list.items.map(\.title) == ["Orphan"])
    }
}

struct RecordMappingTests {
    let container = GiftedSchema.makeInMemoryContainer()
    var context: ModelContext { container.mainContext }

    @Test func itemRoundTripsThroughARecord() throws {
        let list = Wishlist(id: "list-1", name: "Mine")
        let item = WishItem(id: "item-1", title: "Tote", price: Decimal(string: "189.95"),
                            currencyCode: "AUD", link: URL(string: "https://bellroy.com"),
                            notes: "Navy", imageData: Data([1, 2, 3]))
        context.insert(list)
        context.insert(item)
        item.wishlist = list

        let record = item.makeRecord()
        #expect(record.recordID.zoneID == CloudSchema.zoneID)
        #expect(record[CloudSchema.Field.price] as? String == "189.95")
        #expect(WishItem.wishlistID(in: record) == "list-1")
        #expect(record[CloudSchema.Field.image] is CKAsset)

        let copy = WishItem(id: "item-1", title: "")
        copy.apply(record)
        #expect(copy.title == "Tote")
        #expect(copy.price == Decimal(string: "189.95"))
        #expect(copy.link == item.link)
        #expect(copy.notes == "Navy")
        #expect(copy.imageData == Data([1, 2, 3]))
    }

    @Test func unchangedImagesAreNotReuploaded() {
        let item = WishItem(title: "Tote", imageData: Data([1]))
        item.imageNeedsUpload = false
        #expect(!item.makeRecord().allKeys().contains(CloudSchema.Field.image))
    }

    @Test func systemFieldsArePreserved() throws {
        let record = CKRecord(recordType: CloudSchema.RecordType.wishlist,
                              recordID: CloudSchema.recordID(for: "abc"))
        let list = Wishlist(id: "abc", name: "Renamed")
        list.cloudSystemFields = record.encodedSystemFields

        let rebuilt = list.makeRecord()
        #expect(rebuilt.recordID == record.recordID)
        #expect(rebuilt[CloudSchema.Field.name] as? String == "Renamed")
    }
}
