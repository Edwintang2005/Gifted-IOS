//
//  Models.swift
//  Gifted
//
//  Local SwiftData models. Each model maps 1:1 to a CloudKit record whose record name
//  is the model's `id`. See Gifted/Sync for the mapping and sync logic.
//

import Foundation
import SwiftData

@Model
final class Wishlist {
    @Attribute(.unique) var id: String
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WishItem.wishlist)
    var items: [WishItem] = []

    // MARK: Sync bookkeeping
    /// Archived CKRecord system fields (record ID, change tag) from the last successful sync.
    var cloudSystemFields: Data?
    /// True when local changes haven't been confirmed as saved to iCloud yet.
    var needsUpload: Bool = true

    init(id: String = UUID().uuidString, name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class WishItem {
    @Attribute(.unique) var id: String
    var title: String
    var price: Decimal?
    var currencyCode: String
    var link: URL?
    var notes: String
    @Attribute(.externalStorage) var imageData: Data?
    var createdAt: Date
    var wishlist: Wishlist?

    // MARK: Sync bookkeeping
    var cloudSystemFields: Data?
    var needsUpload: Bool = true
    /// Images are only re-uploaded when they change, not on every edit.
    var imageNeedsUpload: Bool = false

    init(
        id: String = UUID().uuidString,
        title: String,
        price: Decimal? = nil,
        currencyCode: String = Locale.current.currency?.identifier ?? "AUD",
        link: URL? = nil,
        notes: String = "",
        imageData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.price = price
        self.currencyCode = currencyCode
        self.link = link
        self.notes = notes
        self.imageData = imageData
        self.imageNeedsUpload = imageData != nil
        self.createdAt = createdAt
    }
}

extension WishItem {
    var formattedPrice: String? {
        price.map { $0.formatted(.currency(code: currencyCode)) }
    }
}

nonisolated enum GiftedSchema {
    static let models: [any PersistentModel.Type] = [Wishlist.self, WishItem.self]

    /// The on-disk store in the app group container, readable by the share extension.
    static func makeContainer(readOnly: Bool = false) throws -> ModelContainer {
        try FileManager.default.createDirectory(
            at: AppConfig.sharedContainerURL, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(
            schema: Schema(models),
            url: AppConfig.storeURL,
            allowsSave: !readOnly,
            cloudKitDatabase: .none // Sync is handled by SyncManager, not SwiftData.
        )
        return try ModelContainer(for: Schema(models), configurations: configuration)
    }

    static func makeInMemoryContainer() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try! ModelContainer(for: Schema(models), configurations: configuration)
    }
}
