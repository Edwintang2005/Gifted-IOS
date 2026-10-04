# Gifted App

A wishlist app for iOS and iPadOS, written in SwiftUI. Save things you'd love to receive by pasting a product link, sharing a page from Safari, or snapping a photo. Your wishlists sync across your devices with iCloud, and you can invite friends to see them.

Supports: iOS and iPadOS 17.0+

# Significance

This app started as the project I used to learn Git, AWS and UI/UX design. Undertaken as a passion project, it is designed to mitigate the social awkwardness of trying to figure out what someone wants come gift-giving season. Users update it as they find products they would like, either by snapping a photo for a quick add or by importing website links.

The original version ran on AWS Amplify. Version 2 replaces it with CloudKit, so there are no accounts to create or servers to run.

# Architecture

| Folder | What's in it |
|---|---|
| `Shared/` | Code compiled into both the app and the share extension: SwiftData models, the share-extension inbox, link/price parsing, image downsizing. |
| `Gifted/Library/` | `Library`: every change to wishlists and items goes through here, so it's saved locally and queued for iCloud in one place. |
| `Gifted/Sync/` | `SyncManager` (your lists ↔ private database, plus creating the share), `FriendsSync` and `FriendStore` (friends' lists from the shared database), and the model ↔ CKRecord mapping. |
| `Gifted/Views/` | SwiftUI screens. |
| `GiftedShareExtension/` | "Share → Gifted" from Safari, shopping apps or Photos. |
| `GiftedTests/` | Unit tests (Swift Testing). |

- **Local first.** Data lives in a SwiftData store in the app group container. The app works fully offline and without an iCloud account.
- **Sync.** `CKSyncEngine` mirrors the store into a custom zone (`Wishlists`) in the user's private iCloud database. Keeping all of a user's lists in one zone lets them be shared as a whole.
- **Friends.** Sharing uses one zone-wide `CKShare`: an invite gives read-only access to all of the owner's wishlists. Invites are sent and managed with the system `UICloudSharingController`. Opening an invite link reaches `SceneDelegate`, then `FriendsSync`, which accepts it and mirrors that friend's zone from the shared database into separate read-only models (`Friend`, `FriendWishlist`, `FriendItem`). They're kept apart from your own models because record names are only unique within one person's zone.
- **Share extension.** The extension doesn't write to the database or talk to iCloud. It drops each saved item into an `Inbox` folder in the app group, and the app imports and uploads them the next time it becomes active.

# Building

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). After adding or removing files, or changing settings, regenerate it:

```bash
xcodegen generate
```

Before the first device build, open the project in Xcode, select the **Gifted** target, go to **Signing & Capabilities**, and check that the iCloud container `iCloud.com.edwintang.gifted` and the app group `group.com.edwintang.gifted` are registered and ticked. These identifiers are also in `Shared/AppConfig.swift`.

To fill an empty store with sample gifts and a pretend friend in a Debug build, add `-seedSampleData` to the scheme's launch arguments.

Development builds use CloudKit's **Development** environment, while TestFlight and App Store builds use **Production**. Before testing sharing over TestFlight, deploy the schema to Production in the [CloudKit Console](https://icloud.developer.apple.com). Two people can only share with each other when both are running builds that use the same environment.

# Roadmap

1. ~~Remove Amplify; local wishlist with iCloud sync; share extension~~
2. ~~Share wishlists with friends via invite links~~
3. Gift circles: claim gifts or split them with other gifters, hidden from the recipient
4. Notifications and polish

# Credits
Credits given to:
- Roger Yao for Code contributions and UI/UX design assistance
- Michelle Zhang for UI/UX insight
- Saf Basha and the wonderful team at Project Academy for insights and advice
