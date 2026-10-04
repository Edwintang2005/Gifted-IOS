//
//  ItemDetailView.swift
//  Gifted
//

import SwiftData
import SwiftUI

struct ItemDetailView: View {
    let item: WishItem

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Wishlist.createdAt) private var lists: [Wishlist]

    @State private var editing = false
    @State private var confirmingDelete = false

    var body: some View {
        // Guard against rendering an item that was just deleted (here or by sync).
        if item.modelContext == nil || item.isDeleted {
            ContentUnavailableView("Gift removed", systemImage: "gift")
        } else {
            content
        }
    }

    private var content: some View {
        GiftDetailContent(gift: item, listName: item.wishlist?.name)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(item.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Edit") { editing = true }
                    moreMenu
                }
            }
            .sheet(isPresented: $editing) {
                ItemEditorView(mode: .edit(item))
            }
            .confirmationDialog("Delete this gift?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete Gift", role: .destructive) {
                    library.delete(item)
                    dismiss()
                }
            } message: {
                Text("It will be removed from all your devices.")
            }
    }

    private var moreMenu: some View {
        Menu("More", systemImage: "ellipsis.circle") {
            if let link = item.link {
                ShareLink(item: link) { Label("Share Link", systemImage: "square.and.arrow.up") }
            }
            if lists.count > 1 {
                Menu("Move To", systemImage: "folder") {
                    ForEach(lists.filter { $0.id != item.wishlist?.id }) { list in
                        Button(list.name) { library.move(item, to: list) }
                    }
                }
            }
            Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
        }
    }
}

/// The body of a gift's detail page, shared by the user's own items and friends' items.
struct GiftDetailContent<Gift: GiftPresentable>: View {
    let gift: Gift
    var listName: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ItemImage(data: gift.imageData, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: gift.imageData == nil ? 220 : nil)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(gift.title)
                        .font(.title2.bold())
                        .foregroundStyle(Color.brandInk)
                        .textSelection(.enabled)
                    if let price = gift.formattedPrice {
                        Text(price)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.brandAccent)
                    }
                    if let listName {
                        Label(listName, systemImage: "list.bullet")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !gift.notes.isEmpty {
                    Text(gift.notes)
                        .font(.body)
                        .textSelection(.enabled)
                }

                if let link = gift.link {
                    Link(destination: link) {
                        Label("View in Store", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text(link.host() ?? link.absoluteString)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
    }
}
