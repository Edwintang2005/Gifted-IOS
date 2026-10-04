//
//  ShareInvitations.swift
//  Gifted
//
//  iOS hands an opened invite link to the scene delegate, which can run before the
//  SwiftUI app has wired up its sync objects (when the link launches the app), so
//  invitations wait here until a handler is set.
//

import CloudKit
import UIKit

enum ShareInvitations {
    private static var pending: [CKShare.Metadata] = []

    static var handler: ((CKShare.Metadata) -> Void)? {
        didSet {
            guard let handler else { return }
            let waiting = pending
            pending.removeAll()
            waiting.forEach(handler)
        }
    }

    static func receive(_ metadata: CKShare.Metadata) {
        if let handler {
            handler(metadata)
        } else {
            pending.append(metadata)
        }
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            ShareInvitations.receive(metadata)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        ShareInvitations.receive(cloudKitShareMetadata)
    }
}
