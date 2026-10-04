//
//  GiftedApp.swift
//  Gifted
//
//  Created by Edwin Tang on 3/12/2022.
//

import SwiftData
import SwiftUI
import UIKit

@main
struct GiftedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer
    @State private var sync: SyncManager
    @State private var library: Library
    @State private var friends: FriendsSync

    init() {
        let container: ModelContainer
        if AppEnvironment.isRunningTests {
            // Unit tests run inside the app; keep them away from the real store and iCloud.
            container = GiftedSchema.makeInMemoryContainer()
        } else {
            do {
                container = try GiftedSchema.makeContainer()
            } catch {
                fatalError("Couldn't open the Gifted database: \(error)")
            }
        }
        let sync = SyncManager(modelContext: container.mainContext)
        let library = Library(context: container.mainContext, sync: sync)
        let friends = FriendsSync(modelContext: container.mainContext)

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedSampleData") {
            SampleData.seedIfEmpty(library)
            SampleData.seedFriendIfNone(container.mainContext)
        }
        #endif

        if !AppEnvironment.isRunningTests {
            sync.start()
            friends.start()
            ShareInvitations.handler = { metadata in
                Task { await friends.accept(metadata) }
            }
        }

        self.modelContainer = container
        _sync = State(initialValue: sync)
        _library = State(initialValue: library)
        _friends = State(initialValue: friends)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.brandAccent)
                .environment(sync)
                .environment(library)
                .environment(friends)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active, !AppEnvironment.isRunningTests else { return }
            library.importInbox()
            Task {
                await sync.syncNow()
                await friends.syncNow()
            }
        }
    }
}

enum AppEnvironment {
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // CKSyncEngine listens for its own silent pushes once the app is registered.
        application.registerForRemoteNotifications()
        return true
    }

    /// Routes opened invite links to SceneDelegate.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
