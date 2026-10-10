//
//  SettingsView.swift
//  Gifted
//

import SwiftUI

struct SettingsView: View {
    @Environment(SyncManager.self) private var sync
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        Label(accountText, systemImage: accountIcon)
                            .foregroundStyle(sync.account == .available ? Color.brandAccent : .secondary)
                    }
                    if sync.account == .available {
                        if let lastSyncedAt = sync.lastSyncedAt {
                            LabeledContent("Last Synced") {
                                Text(lastSyncedAt, format: .relative(presentation: .named))
                            }
                        }
                        if let error = sync.lastError {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    Button {
                        Task { await sync.syncNow() }
                    } label: {
                        HStack {
                            Text("Sync Now")
                            if sync.isSyncing {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(sync.account != .available || sync.isSyncing)
                } header: {
                    Text("iCloud")
                } footer: {
                    Text(accountFooter)
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.versionString)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await sync.refreshAccountStatus() }
        }
    }

    private var accountText: String {
        switch sync.account {
        case .available: "Syncing"
        case .noAccount: "Not Signed In"
        case .restricted: "Restricted"
        case .temporarilyUnavailable: "Needs Attention"
        case .unknown: "Checking…"
        }
    }

    private var accountIcon: String {
        switch sync.account {
        case .available: "checkmark.icloud"
        case .noAccount, .restricted: "xmark.icloud"
        case .temporarilyUnavailable, .unknown: "icloud"
        }
    }

    private var accountFooter: String {
        switch sync.account {
        case .noAccount:
            "Sign in to iCloud in the Settings app to keep your wishlists on all your devices. Until then they're saved on this device only."
        case .restricted:
            "iCloud is restricted on this device, so your wishlists are saved on this device only."
        case .temporarilyUnavailable:
            "Your Apple Account needs attention. Open the Settings app and sign in again; your wishlists will sync once that's done."
        default:
            "Your wishlists are stored in your private iCloud account. Only friends you invite can see them."
        }
    }
}

private extension Bundle {
    var versionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
