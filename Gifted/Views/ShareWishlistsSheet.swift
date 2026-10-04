//
//  ShareWishlistsSheet.swift
//  Gifted
//
//  Explains what friends will see, asks for the name to show them, then hands over
//  to the system sharing UI (invite via Messages/Mail/link, see who joined, stop sharing).
//

import CloudKit
import SwiftUI
import UIKit

struct ShareWishlistsSheet: View {
    @Environment(SyncManager.self) private var sync
    @Environment(\.dismiss) private var dismiss
    @AppStorage("profileName") private var profileName = ""

    @State private var share: CKShare?
    @State private var loadingShare = true
    @State private var isPreparing = false
    @State private var errorMessage: String?

    private var trimmedName: String { profileName.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var joinedCount: Int {
        share?.participants.filter { $0.role != .owner && $0.acceptanceStatus == .accepted }.count ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "person.2.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.brandGradient)
                        Text("Share your wishlists")
                            .font(.title2.bold())
                            .foregroundStyle(Color.brandInk)
                        Text("Friends you invite can see all your wishlists: names, photos, prices and links. They can't change anything, and you can stop sharing at any time.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    TextField("Your name", text: $profileName)
                        .textContentType(.givenName)
                        .submitLabel(.done)
                } header: {
                    Text("Your name")
                } footer: {
                    if trimmedName.isEmpty {
                        Text("The name your friends know you by.")
                    } else {
                        Text("Friends will see your lists as \u{201C}\(ShareTitle.make(ownerName: trimmedName))\u{201D}.")
                    }
                }

                if share != nil {
                    Section {
                        LabeledContent("Friends who've joined", value: "\(joinedCount)")
                    }
                }

                Section {
                    Button(action: openSharing) {
                        HStack {
                            Text(share == nil ? "Invite Friends" : "Invite or Manage Friends")
                            Spacer()
                            if isPreparing || loadingShare { ProgressView() }
                        }
                    }
                    .disabled(trimmedName.isEmpty || isPreparing || sync.account != .available)
                } footer: {
                    if sync.account != .available {
                        Text("Sign in to iCloud to share your wishlists.")
                    } else if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await loadShare() }
        }
    }

    private func loadShare() async {
        guard sync.account == .available else {
            loadingShare = false
            return
        }
        loadingShare = true
        share = try? await sync.fetchShare()
        loadingShare = false
    }

    private func openSharing() {
        isPreparing = true
        errorMessage = nil
        Task {
            defer { isPreparing = false }
            do {
                let prepared = try await sync.prepareShare(ownerName: trimmedName)
                share = prepared
                CloudSharingPresenter.present(
                    share: prepared,
                    container: sync.cloudContainer,
                    itemTitle: ShareTitle.make(ownerName: trimmedName),
                    onChange: { Task { await loadShare() } }
                )
            } catch {
                errorMessage = "Couldn't set up sharing. Check your connection and try again."
            }
        }
    }
}

/// Presents UICloudSharingController from UIKit; it doesn't display reliably when
/// wrapped in a SwiftUI sheet.
enum CloudSharingPresenter {
    private static var activeDelegate: SharingDelegate?

    static func present(share: CKShare, container: CKContainer, itemTitle: String, onChange: @escaping () -> Void) {
        let controller = UICloudSharingController(share: share, container: container)
        // Friends get read-only access; the owner chooses invite-only or anyone with the link.
        controller.availablePermissions = [.allowReadOnly, .allowPrivate, .allowPublic]
        let delegate = SharingDelegate(itemTitle: itemTitle, onChange: onChange)
        controller.delegate = delegate
        activeDelegate = delegate
        topViewController()?.present(controller, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    private final class SharingDelegate: NSObject, UICloudSharingControllerDelegate {
        let itemTitle: String
        let onChange: () -> Void

        init(itemTitle: String, onChange: @escaping () -> Void) {
            self.itemTitle = itemTitle
            self.onChange = onChange
        }

        func itemTitle(for csc: UICloudSharingController) -> String? { itemTitle }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            UIImage(named: "AppIcon")?.pngData()
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            onChange()
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) { onChange() }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) { onChange() }
    }
}
