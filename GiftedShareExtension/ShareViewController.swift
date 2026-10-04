//
//  ShareViewController.swift
//  GiftedShareExtension
//
//  Created by Edwin Tang on 4/1/2023.
//
//  "Share → Gifted" from Safari, a shopping app or Photos. Saves into the app group
//  inbox; the app imports and syncs it next time it opens.
//

import SwiftUI
import UIKit

final class ShareViewController: UIViewController {
    private lazy var model = ShareModel(
        inputItems: extensionContext?.inputItems as? [NSExtensionItem] ?? [],
        onFinish: { [weak self] saved in self?.finish(saved: saved) }
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareView(model: model))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        Task { await model.load() }
    }

    private func finish(saved: Bool) {
        if saved {
            extensionContext?.completeRequest(returningItems: nil)
        } else {
            extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
        }
    }
}
