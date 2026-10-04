//
//  WishlistScreen.swift
//  Gifted
//
//  Home screen: the selected wishlist's gifts, with a menu under the title to switch,
//  create, rename or delete lists.
//

import SwiftData
import SwiftUI

enum ItemSort: String, CaseIterable, Identifiable {
    case newest, oldest, priceLowToHigh, priceHighToLow, name

    var id: Self { self }

    var label: String {
        switch self {
        case .newest: "Newest First"
        case .oldest: "Oldest First"
        case .priceLowToHigh: "Price: Low to High"
        case .priceHighToLow: "Price: High to Low"
        case .name: "Name"
        }
    }

    func sorted(_ items: [WishItem]) -> [WishItem] {
        switch self {
        case .newest: items.sorted { $0.createdAt > $1.createdAt }
        case .oldest: items.sorted { $0.createdAt < $1.createdAt }
        // Items without a price go last either way.
        case .priceLowToHigh: items.sorted { ($0.price ?? .greatestFiniteMagnitude) < ($1.price ?? .greatestFiniteMagnitude) }
        case .priceHighToLow: items.sorted { ($0.price ?? -1) > ($1.price ?? -1) }
        case .name: items.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }
}

struct WishlistScreen: View {
    @Environment(Library.self) private var library
    @Query(sort: \Wishlist.createdAt) private var lists: [Wishlist]

    @AppStorage("selectedWishlistID") private var selectedID = AppConfig.defaultWishlistID
    @AppStorage("itemSort") private var sort: ItemSort = .newest

    @State private var addingItem = false
    @State private var showingSettings = false
    @State private var listPrompt: ListPrompt?
    @State private var listNameDraft = ""
    @State private var confirmingDelete = false

    private enum ListPrompt: Identifiable {
        case create, rename
        var id: Self { self }
    }

    private var selectedList: Wishlist? {
        lists.first { $0.id == selectedID } ?? lists.first
    }

    var body: some View {
        Group {
            if let list = selectedList {
                WishlistContent(list: list, sort: sort, header: header(for: list), onAdd: { addingItem = true })
            } else {
                ProgressView()
            }
        }
        // The gradient header shows the name; the title is kept for accessibility and history.
        .navigationTitle(selectedList?.name ?? "Wishlist")
        .toolbarTitleDisplayMode(.inline)
        .toolbar(content: toolbarContent)
        .toolbar {
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
        }
        .onChange(of: lists.isEmpty, initial: true) { _, isEmpty in
            if isEmpty { library.ensureDefaultWishlist() }
        }
        .sheet(isPresented: $addingItem) {
            if let list = selectedList {
                ItemEditorView(mode: .add(list))
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert(listPrompt == .rename ? "Rename Wishlist" : "New Wishlist", isPresented: isPromptPresented) {
            TextField("Name", text: $listNameDraft)
            Button("Cancel", role: .cancel) {}
            Button(listPrompt == .rename ? "Save" : "Create", action: submitListPrompt)
        }
        .confirmationDialog(
            "Delete \u{201C}\(selectedList?.name ?? "")\u{201D}?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Wishlist", role: .destructive) {
                if let list = selectedList {
                    library.delete(list)
                    selectedID = lists.first { $0.id != list.id }?.id ?? AppConfig.defaultWishlistID
                }
            }
        } message: {
            let count = selectedList?.items.count ?? 0
            Text("This deletes the list and its \(count) \(count == 1 ? "gift" : "gifts") from all your devices.")
        }
    }

    // MARK: - Header & toolbar

    private func header(for list: Wishlist) -> some View {
        Menu {
            Picker("Wishlist", selection: $selectedID) {
                ForEach(lists) { Text($0.name).tag($0.id) }
            }
            Divider()
            Button("New Wishlist…", systemImage: "plus") { showPrompt(.create) }
            Button("Rename…", systemImage: "pencil") { showPrompt(.rename) }
            Button("Delete…", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                .disabled(lists.count < 2)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                GradientTitle(text: list.name)
                Image(systemName: "chevron.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.brandAccent)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("\(list.name), switch wishlist")
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Settings", systemImage: "gearshape") { showingSettings = true }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu("Sort", systemImage: "arrow.up.arrow.down") {
                Picker("Sort", selection: $sort) {
                    ForEach(ItemSort.allCases) { Text($0.label).tag($0) }
                }
            }
            Button("Add Gift", systemImage: "plus") { addingItem = true }
                .disabled(selectedList == nil)
        }
    }

    // MARK: - List prompts

    private var isPromptPresented: Binding<Bool> {
        Binding(get: { listPrompt != nil }, set: { if !$0 { listPrompt = nil } })
    }

    private func showPrompt(_ prompt: ListPrompt) {
        listNameDraft = prompt == .rename ? (selectedList?.name ?? "") : ""
        listPrompt = prompt
    }

    private func submitListPrompt() {
        let name = listNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        switch listPrompt {
        case .create:
            selectedID = library.createWishlist(named: name).id
        case .rename:
            if let list = selectedList { library.rename(list, to: name) }
        case nil:
            break
        }
    }
}

// MARK: - Content

private struct WishlistContent<Header: View>: View {
    let list: Wishlist
    let sort: ItemSort
    let header: Header
    let onAdd: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        let items = sort.sorted(list.items)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    header
                    if !items.isEmpty {
                        Text(summary(for: items))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if items.isEmpty {
                    emptyState
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
        .navigationDestination(for: WishItem.self) { item in
            ItemDetailView(item: item)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No gifts yet", systemImage: "gift")
        } description: {
            Text("Add things you'd love to receive.\nTip: tap Share on any product page and choose Gifted.")
        } actions: {
            Button("Add a Gift", action: onAdd)
                .buttonStyle(.borderedProminent)
        }
        .padding(.top, 40)
    }

    private func summary(for items: [WishItem]) -> String {
        let count = "\(items.count) \(items.count == 1 ? "gift" : "gifts")"
        // Only total when every priced item shares a currency.
        let priced = items.filter { $0.price != nil }
        guard let currency = priced.first?.currencyCode,
              priced.allSatisfy({ $0.currencyCode == currency }), !priced.isEmpty
        else { return count }
        let total = priced.reduce(Decimal.zero) { $0 + ($1.price ?? 0) }
        return "\(count) · \(total.formatted(.currency(code: currency))) total"
    }
}

#if DEBUG
#Preview {
    let library = SampleData.previewLibrary
    NavigationStack { WishlistScreen() }
        .environment(library)
        .modelContainer(library.context.container)
}
#endif
