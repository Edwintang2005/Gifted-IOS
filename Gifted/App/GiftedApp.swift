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

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedSampleData") {
            SampleData.seedIfEmpty(library)
        }
        #endif

        if !AppEnvironment.isRunningTests {
            sync.start()
        }

        self.modelContainer = container
        _sync = State(initialValue: sync)
        _library = State(initialValue: library)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.brandAccent)
                .environment(sync)
                .environment(library)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active, !AppEnvironment.isRunningTests else { return }
            library.importInbox()
            Task { await sync.syncNow() }
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
}

struct RootView: View {
    var body: some View {
        NavigationStack {
            WishlistScreen()
        }
    }
}
