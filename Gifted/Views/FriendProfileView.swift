//
//  FriendProfileView.swift
//  Gifted
//
//  A friend's wishlists, read-only.
//

import SwiftUI

struct FriendProfileView: View {
    let friend: Friend

    @Environment(FriendsSync.self) private var friendsSync
    @Environment(\.dismiss) private var dismiss
    @State private var selectedListKey: String?
    @State private var confirmingRemove = false

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        // The friend can stop sharing at any time, which deletes them locally.
        if friend.modelContext == nil || friend.isDeleted {
            ContentUnavailableView("No longer shared", systemImage: "person.crop.circle.badge.xmark",
                                   description: Text("These wishlists aren't shared with you any more."))
        } else {
            content
        }
    }

    private var lists: [FriendWishlist] {
        friend.wishlists.sorted { $0.createdAt < $1.createdAt }
    }

    private var selectedList: FriendWishlist? {
        lists.first { $0.key == selectedListKey } ?? lists.first
    }

    private var content: some View {
        let items = (selectedList?.items ?? []).sorted { $0.createdAt > $1.createdAt }
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    FriendAvatar(name: friend.displayName, size: 56)
                    GradientTitle(text: friend.displayName)
                }

                if lists.count > 1 {
                    listChips
                }

                if items.isEmpty {
                    ContentUnavailableView(
                        "Nothing here yet", systemImage: "gift",
                        description: Text("\(friend.displayName) hasn't added any gifts to this list."))
                        .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                ItemCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(friend.displayName)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Remove Friend", systemImage: "person.badge.minus", role: .destructive) {
                        confirmingRemove = true
                    }
                }
            }
        }
        .navigationDestination(for: FriendItem.self) { item in
            FriendItemDetailView(item: item)
        }
        .confirmationDialog("Remove \(friend.displayName)?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                dismiss()
                friendsSync.remove(friend)
            }
        } message: {
            Text("You'll stop seeing their wishlists. They'd need to invite you again.")
        }
    }

    private var listChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(lists) { list in
                    let isSelected = list.key == selectedList?.key
                    Button {
                        selectedListKey = list.key
                    } label: {
                        Text(list.name)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(isSelected ? Color.white : Color.brandInk)
                            .background(Capsule().fill(isSelected ? Color.brandAccent : Color.cardBackground))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}

struct FriendItemDetailView: View {
    let item: FriendItem

    var body: some View {
        if item.modelContext == nil || item.isDeleted {
            ContentUnavailableView("Gift removed", systemImage: "gift")
        } else {
            GiftDetailContent(gift: item, listName: item.wishlist?.name)
                .background(Color(.systemGroupedBackground))
                .navigationTitle(item.title)
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    if let link = item.link {
                        ToolbarItem(placement: .topBarTrailing) {
                            ShareLink(item: link)
                        }
                    }
                }
        }
    }
}
