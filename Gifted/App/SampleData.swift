//
//  SampleData.swift
//  Gifted
//
//  Debug-only sample content for previews and screenshots. Launch with the
//  `-seedSampleData` argument to fill an empty store.
//

#if DEBUG
import SwiftData
import SwiftUI

enum SampleData {
    static func seedIfEmpty(_ library: Library) {
        guard library.allWishlists().isEmpty else { return }
        let main = library.ensureDefaultWishlist()
        let birthday = library.createWishlist(named: "Birthday")

        let gifts: [(String, Decimal?, String, Color)] = [
            ("Bellroy Tokyo Totepack", 189, "https://bellroy.com", .teal),
            ("Apple iPad 64GB Wi-Fi (Silver)", 549, "https://apple.com/au/ipad", .gray),
            ("Le Creuset Signature Round Casserole 24cm", 579.95, "", .orange),
            ("Concert tickets", nil, "", .purple),
        ]
        for (index, gift) in gifts.enumerated() {
            let draft = ItemDraft(
                title: gift.0, price: gift.1, currencyCode: "AUD",
                link: URL(string: gift.2), notes: index == 0 ? "Navy if they have it." : "",
                imageData: swatch(gift.3))
            library.addItem(draft, to: main, createdAt: .now.addingTimeInterval(Double(-index) * 3600))
        }
        library.addItem(ItemDraft(title: "Hiking boots", price: 249, currencyCode: "AUD"), to: birthday)
    }

    /// A pretend friend so the Friends tab can be previewed without a second iCloud account.
    static func seedFriendIfNone(_ context: ModelContext) {
        guard ((try? context.fetchCount(FetchDescriptor<Friend>())) ?? 0) == 0 else { return }
        let owner = "_sample_friend"
        let friend = Friend(ownerName: owner, displayName: "Sam Lee")
        context.insert(friend)

        let lists = [("Birthday", 0.0), ("Christmas", 1.0)].map { name, offset in
            let list = FriendWishlist(ownerName: owner, recordName: name, name: name,
                                      createdAt: .now.addingTimeInterval(offset))
            context.insert(list)
            list.friend = friend
            return list
        }
        let gifts: [(String, Decimal?, Color, Int)] = [
            ("Polaroid Go Generation 2", 129.95, .red, 0),
            ("Aesop Resurrection Hand Balm", 49, .brown, 0),
            ("Board game night: Wingspan", 89, .blue, 0),
            ("Merino wool socks", 35, .green, 1),
        ]
        for (index, gift) in gifts.enumerated() {
            let item = FriendItem(ownerName: owner, recordName: "gift-\(index)")
            context.insert(item)
            item.title = gift.0
            item.price = gift.1
            item.imageData = swatch(gift.2)
            item.createdAt = .now.addingTimeInterval(Double(-index) * 60)
            item.friend = friend
            item.wishlist = lists[gift.3]
        }
        try? context.save()
    }

    @MainActor
    static var previewLibrary: Library {
        let container = GiftedSchema.makeInMemoryContainer()
        let library = Library(context: container.mainContext, sync: nil)
        seedIfEmpty(library)
        return library
    }

    /// A soft coloured square so sample items have something to show.
    private static func swatch(_ color: Color) -> Data? {
        let renderer = ImageRenderer(content:
            ZStack {
                LinearGradient(colors: [color.opacity(0.35), color.opacity(0.75)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "gift.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(width: 400, height: 400)
        )
        return renderer.uiImage?.jpegData(compressionQuality: 0.8)
    }
}
#endif
