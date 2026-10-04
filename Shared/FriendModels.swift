//
//  FriendModels.swift
//  Gifted
//
//  Read-only local copies of wishlists that friends have shared with this user.
//  They live apart from the user's own models because record names are only unique
//  within one person's zone (everyone has a "default-wishlist"), so every friend
//  record is keyed by "<zone owner>/<record name>".
//

import Foundation
import SwiftData

@Model
final class Friend {
    /// The owner name of the friend's shared zone; stable for the life of the share.
    @Attribute(.unique) var ownerName: String
    var displayName: String
    var joinedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \FriendWishlist.friend)
    var wishlists: [FriendWishlist] = []

    @Relationship(deleteRule: .cascade, inverse: \FriendItem.friend)
    var items: [FriendItem] = []

    init(ownerName: String, displayName: String, joinedAt: Date = .now) {
        self.ownerName = ownerName
        self.displayName = displayName
        self.joinedAt = joinedAt
    }
}

@Model
final class FriendWishlist {
    @Attribute(.unique) var key: String
    var recordName: String
    var name: String
    var createdAt: Date
    var friend: Friend?

    @Relationship(deleteRule: .cascade, inverse: \FriendItem.wishlist)
    var items: [FriendItem] = []

    init(ownerName: String, recordName: String, name: String = "", createdAt: Date = .now) {
        self.key = FriendKey.make(ownerName: ownerName, recordName: recordName)
        self.recordName = recordName
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class FriendItem {
    @Attribute(.unique) var key: String
    var recordName: String
    var title: String
    var price: Decimal?
    var currencyCode: String
    var link: URL?
    var notes: String
    @Attribute(.externalStorage) var imageData: Data?
    var createdAt: Date
    var friend: Friend?
    var wishlist: FriendWishlist?

    init(ownerName: String, recordName: String) {
        self.key = FriendKey.make(ownerName: ownerName, recordName: recordName)
        self.recordName = recordName
        self.title = ""
        self.currencyCode = "AUD"
        self.notes = ""
        self.createdAt = .now
    }
}

nonisolated enum FriendKey {
    static func make(ownerName: String, recordName: String) -> String {
        "\(ownerName)/\(recordName)"
    }
}

// MARK: - Display

/// Anything shown as a gift card or detail page: the user's own items and friends'.
nonisolated protocol GiftPresentable {
    var title: String { get }
    var price: Decimal? { get }
    var currencyCode: String { get }
    var link: URL? { get }
    var notes: String { get }
    var imageData: Data? { get }
}

extension GiftPresentable {
    var formattedPrice: String? {
        price.map { $0.formatted(.currency(code: currencyCode)) }
    }
}

extension WishItem: GiftPresentable {}
extension FriendItem: GiftPresentable {}
