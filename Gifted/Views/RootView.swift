//
//  RootView.swift
//  Gifted
//

import SwiftUI

struct RootView: View {
    enum Tab: Hashable {
        case mine, friends
    }

    @Environment(FriendsSync.self) private var friends
    @State private var tab: Tab = .mine

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                WishlistScreen()
            }
            .tabItem { Label("My Lists", systemImage: "gift") }
            .tag(Tab.mine)

            NavigationStack {
                FriendsScreen()
            }
            .tabItem { Label("Friends", systemImage: "person.2") }
            .tag(Tab.friends)
        }
        // Opening a friend's invite link lands on the Friends tab.
        .onChange(of: friends.isJoining) { _, joining in
            if joining { tab = .friends }
        }
    }
}
