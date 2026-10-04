//
//  Library.swift
//  Gifted
//
//  Every change to wishlists and items goes through here so it's saved locally and
//  queued for iCloud in one place. Views read with @Query and write with Library.
//

import Foundation
import Observation
import os
import SwiftData

/// The editable fields of an item, used by the editor and the share-extension import.
struct ItemDraft: Equatable {
    var title = ""
    var price: Decimal?
    var currencyCode = Locale.current.currency?.identifier ?? "AUD"
    var link: URL?
    var notes = ""
    var imageData: Data?

    var isValid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

extension ItemDraft {
    init(_ item: WishItem) {
        self.init(title: item.title, price: item.price, currencyCode: item.currencyCode,
                  link: item.link, notes: item.notes, imageData: item.imageData)
    }
}

@Observable
final class Library {
    @ObservationIgnored let context: ModelContext
    @ObservationIgnored private let sync: SyncChangeRecorder?
    @ObservationIgnored private let inbox: Inbox
    @ObservationIgnored private let logger = Logger(subsystem: "com.edwintang.gifted", category: "Library")

    init(context: ModelContext, sync: SyncChangeRecorder?, inbox: Inbox = Inbox()) {
        self.context = context
        self.sync = sync
        self.inbox = inbox
    }

    // MARK: - Wishlists

    func allWishlists() -> [Wishlist] {
        (try? context.fetch(FetchDescriptor<Wishlist>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    /// Every user has at least one list. Uses a fixed ID so devices agree on it.
    @discardableResult
    func ensureDefaultWishlist() -> Wishlist {
        if let existing = allWishlists().first { return existing }
        let list = Wishlist(id: AppConfig.defaultWishlistID, name: AppConfig.defaultWishlistName,
                            createdAt: .distantPast)
        context.insert(list)
        commit(saved: [list.id])
        return list
    }

    @discardableResult
    func createWishlist(named name: String) -> Wishlist {
        let list = Wishlist(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(list)
        commit(saved: [list.id])
        return list
    }

    func rename(_ list: Wishlist, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != list.name else { return }
        list.name = trimmed
        list.needsUpload = true
        commit(saved: [list.id])
    }

    func delete(_ list: Wishlist) {
        let ids = [list.id] + list.items.map(\.id)
        context.delete(list) // Cascades to its items.
        commit(deleted: ids)
    }

    // MARK: - Items

    @discardableResult
    func addItem(_ draft: ItemDraft, to list: Wishlist, id: String = UUID().uuidString, createdAt: Date = .now) -> WishItem {
        let item = WishItem(
            id: id,
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            price: draft.price,
            currencyCode: draft.currencyCode,
            link: draft.link,
            notes: draft.notes,
            imageData: draft.imageData,
            createdAt: createdAt
        )
        context.insert(item)
        item.wishlist = list
        commit(saved: [item.id])
        return item
    }

    func update(_ item: WishItem, with draft: ItemDraft) {
        item.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.price = draft.price
        item.currencyCode = draft.currencyCode
        item.link = draft.link
        item.notes = draft.notes
        if item.imageData != draft.imageData {
            item.imageData = draft.imageData
            item.imageNeedsUpload = true
        }
        item.needsUpload = true
        commit(saved: [item.id])
    }

    func move(_ item: WishItem, to list: Wishlist) {
        guard item.wishlist?.id != list.id else { return }
        item.wishlist = list
        item.needsUpload = true
        commit(saved: [item.id])
    }

    func delete(_ item: WishItem) {
        let id = item.id
        context.delete(item)
        commit(deleted: [id])
    }

    // MARK: - Share extension inbox

    /// Moves items saved from the share extension into the store. Returns how many arrived.
    @discardableResult
    func importInbox() -> Int {
        let pending = inbox.pendingEntries()
        guard !pending.isEmpty else { return 0 }

        var imported = 0
        for (entry, imageData) in pending {
            // The inbox may be re-read if the app was killed mid-import.
            let entryID = entry.id
            let alreadyImported = (try? context.fetchCount(
                FetchDescriptor<WishItem>(predicate: #Predicate { $0.id == entryID }))) ?? 0 > 0
            if !alreadyImported {
                let list = entry.wishlistID.flatMap(wishlist(id:)) ?? ensureDefaultWishlist()
                let draft = ItemDraft(title: entry.title, price: entry.price, currencyCode: entry.currencyCode,
                                      link: entry.link, notes: entry.notes, imageData: imageData)
                addItem(draft, to: list, id: entry.id, createdAt: entry.createdAt)
                imported += 1
            }
            inbox.remove(entry)
        }
        return imported
    }

    // MARK: - Helpers

    private func wishlist(id: String) -> Wishlist? {
        try? context.fetch(FetchDescriptor<Wishlist>(predicate: #Predicate { $0.id == id })).first
    }

    private func commit(saved: [String] = [], deleted: [String] = []) {
        do {
            try context.save()
        } catch {
            logger.error("Couldn't save: \(error)")
            return
        }
        if !saved.isEmpty { sync?.recordSaves(saved) }
        if !deleted.isEmpty { sync?.recordDeletes(deleted) }
    }
}
