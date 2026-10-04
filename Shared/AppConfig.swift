//
//  AppConfig.swift
//  Gifted
//
//  Identifiers shared by the app and the share extension. These must match the
//  entitlements files and the capabilities registered in the developer portal.
//

import Foundation

nonisolated enum AppConfig {
    static let appGroupID = "group.com.edwintang.gifted"
    static let cloudKitContainerID = "iCloud.com.edwintang.gifted"

    /// Record name of the wishlist every user starts with. Using a fixed name means
    /// two devices that each create it before their first sync end up with one list.
    static let defaultWishlistID = "default-wishlist"
    static let defaultWishlistName = "My Wishlist"

    /// Directory shared between the app and its extensions. Falls back to the app's own
    /// Application Support directory if the app group isn't available (e.g. unsigned builds).
    static var sharedContainerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? URL.applicationSupportDirectory
    }

    static var storeURL: URL {
        sharedContainerURL.appending(path: "Gifted.store")
    }

    static var inboxURL: URL {
        sharedContainerURL.appending(path: "Inbox", directoryHint: .isDirectory)
    }
}
