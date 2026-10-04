//
//  FriendsScreen.swift
//  Gifted
//
//  Friends whose wishlists this user can see. A friend appears here after the user
//  opens that friend's invite link.
//

import SwiftData
import SwiftUI

struct FriendsScreen: View {
    @Environment(FriendsSync.self) private var friendsSync
    @Query(sort: \Friend.displayName) private var friends: [Friend]

    @State private var showingShareSheet = false
    @State private var friendToRemove: Friend?

    var body: some View {
        List {
            Section {
                GradientTitle(text: "Friends")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            }

            if friendsSync.isJoining {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Opening your friend's wishlists…")
                    }
                }
            }
            if let error = friendsSync.lastError {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }

            if !friends.isEmpty {
                Section {
                    ForEach(friends) { friend in
                        NavigationLink(value: friend) {
                            FriendRow(friend: friend)
                        }
                        .swipeActions {
                            Button("Remove", role: .destructive) { friendToRemove = friend }
                        }
                    }
                }
            }
        }
        .overlay {
            if friends.isEmpty && !friendsSync.isJoining {
                emptyState
            }
        }
        .navigationTitle("Friends")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Invite Friends", systemImage: "person.badge.plus") { showingShareSheet = true }
            }
        }
        .navigationDestination(for: Friend.self) { friend in
            FriendProfileView(friend: friend)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareWishlistsSheet()
        }
        .confirmationDialog(
            "Remove \(friendToRemove?.displayName ?? "friend")?",
            isPresented: Binding(get: { friendToRemove != nil }, set: { if !$0 { friendToRemove = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let friend = friendToRemove { friendsSync.remove(friend) }
            }
        } message: {
            Text("You'll stop seeing their wishlists. They'd need to invite you again.")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No friends yet", systemImage: "person.2")
        } description: {
            Text("When a friend sends you their Gifted invite link, open it and their wishlists will show up here.")
        } actions: {
            Button("Invite Friends") { showingShareSheet = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct FriendRow: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: 14) {
            FriendAvatar(name: friend.displayName, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.headline)
                    .foregroundStyle(Color.brandInk)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var summary: String {
        let lists = friend.wishlists.count
        let gifts = friend.items.count
        return "\(lists) \(lists == 1 ? "list" : "lists") · \(gifts) \(gifts == 1 ? "gift" : "gifts")"
    }
}

struct FriendAvatar: View {
    let name: String
    var size: CGFloat = 40

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(.brandGradient))
            .accessibilityHidden(true)
    }

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}
