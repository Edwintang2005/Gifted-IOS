//
//  ItemEditorView.swift
//  Gifted
//
//  Add or edit a gift. Pasting a product link fills in the title, photo and price.
//

import PhotosUI
import SwiftData
import SwiftUI

struct ItemEditorView: View {
    enum Mode {
        case add(Wishlist)
        case edit(WishItem)
    }

    let mode: Mode

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Wishlist.createdAt) private var lists: [Wishlist]

    @State private var draft = ItemDraft()
    @State private var priceText = ""
    @State private var linkText = ""
    @State private var listID = ""
    @State private var loaded = false

    @State private var isFetching = false
    @State private var fetchMessage: String?
    @State private var photoSelection: PhotosPickerItem?
    @State private var showingCamera = false

    private var isEditing: Bool {
        if case .edit = mode { true } else { false }
    }

    var body: some View {
        NavigationStack {
            Form {
                linkSection
                photoSection
                detailsSection
                if lists.count > 1 {
                    Section {
                        Picker("Wishlist", selection: $listID) {
                            ForEach(lists) { Text($0.name).tag($0.id) }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Gift" : "New Gift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add", action: save)
                        .disabled(!draft.isValid)
                }
            }
            .onAppear(perform: load)
            .onChange(of: photoSelection) { _, selection in
                Task { await loadPhoto(selection) }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { data in
                    draft.imageData = data.flatMap { ImageProcessing.preparedJPEG(from: $0) }
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Sections

    private var linkSection: some View {
        Section {
            HStack {
                TextField("Paste a product link", text: $linkText)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit { Task { await fillFromLink() } }
                if linkText.isEmpty {
                    PasteButton(payloadType: URL.self) { urls in
                        guard let url = urls.first else { return }
                        linkText = url.absoluteString
                        Task { await fillFromLink() }
                    }
                    .labelStyle(.iconOnly)
                    .buttonBorderShape(.capsule)
                }
            }
            if !linkText.isEmpty {
                Button {
                    Task { await fillFromLink() }
                } label: {
                    HStack {
                        Label("Fill In From Link", systemImage: "wand.and.stars")
                        if isFetching {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isFetching || LinkDetailsFetcher.url(from: linkText) == nil)
            }
        } header: {
            Text("Link")
        } footer: {
            if let fetchMessage { Text(fetchMessage) }
        }
    }

    private var photoSection: some View {
        Section("Photo") {
            if draft.imageData != nil {
                ItemImage(data: draft.imageData, maxPixelSize: 800, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 220)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }
            // The label closure is @Sendable, so work out the title outside it.
            let pickerTitle = draft.imageData == nil ? "Choose Photo" : "Replace Photo"
            PhotosPicker(selection: $photoSelection, matching: .images) {
                Label(pickerTitle, systemImage: "photo.on.rectangle")
            }
            if CameraPicker.isAvailable {
                Button("Take Photo", systemImage: "camera") { showingCamera = true }
            }
            if draft.imageData != nil {
                Button("Remove Photo", systemImage: "trash", role: .destructive) {
                    draft.imageData = nil
                    photoSelection = nil
                }
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("What is it?", text: $draft.title, axis: .vertical)
                .font(.headline)
            HStack {
                Picker("Currency", selection: $draft.currencyCode) {
                    ForEach(CurrencyOptions.codes(including: draft.currencyCode), id: \.self) { Text($0) }
                }
                .labelsHidden()
                .fixedSize()
                TextField("Price", text: $priceText)
                    .keyboardType(.decimalPad)
                    .onChange(of: priceText) { _, text in draft.price = PriceParser.parse(text) }
            }
            TextField("Notes — size, colour, anything that helps", text: $draft.notes, axis: .vertical)
                .lineLimit(2...6)
        }
    }

    // MARK: - Actions

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch mode {
        case .add(let list):
            listID = list.id
        case .edit(let item):
            draft = ItemDraft(item)
            listID = item.wishlist?.id ?? lists.first?.id ?? ""
            linkText = item.link?.absoluteString ?? ""
            priceText = item.price.map { "\($0)" } ?? ""
        }
    }

    private func fillFromLink() async {
        guard let url = LinkDetailsFetcher.url(from: linkText) else {
            fetchMessage = "That doesn't look like a web link."
            return
        }
        linkText = url.absoluteString
        isFetching = true
        fetchMessage = nil
        let details = await LinkDetailsFetcher.fetch(url)
        isFetching = false

        // Fill gaps only; never overwrite what the person typed.
        var filled: [String] = []
        if draft.title.isEmpty, let title = details.title {
            draft.title = title
            filled.append("name")
        }
        if draft.imageData == nil, let image = details.imageData {
            draft.imageData = image
            filled.append("photo")
        }
        if draft.price == nil, let price = details.price {
            draft.price = price
            priceText = "\(price)"
            if let currency = details.currencyCode { draft.currencyCode = currency }
            filled.append("price")
        }
        fetchMessage = filled.isEmpty
            ? "Couldn't find any details on that page. You can fill them in yourself."
            : "Added the \(ListFormatter.localizedString(byJoining: filled)) from the page."
    }

    private func loadPhoto(_ selection: PhotosPickerItem?) async {
        guard let selection,
              let data = try? await selection.loadTransferable(type: Data.self)
        else { return }
        draft.imageData = ImageProcessing.preparedJPEG(from: data)
    }

    private func save() {
        draft.link = LinkDetailsFetcher.url(from: linkText)
        draft.price = PriceParser.parse(priceText)
        let targetList = lists.first { $0.id == listID }

        switch mode {
        case .add(let list):
            library.addItem(draft, to: targetList ?? list)
        case .edit(let item):
            library.update(item, with: draft)
            if let targetList { library.move(item, to: targetList) }
        }
        dismiss()
    }
}

enum CurrencyOptions {
    private static let common = ["AUD", "USD", "NZD", "GBP", "EUR", "CAD", "JPY", "CNY", "HKD", "SGD"]

    static func codes(including current: String) -> [String] {
        var codes = common
        if let local = Locale.current.currency?.identifier, !codes.contains(local) { codes.insert(local, at: 0) }
        if !codes.contains(current) { codes.append(current) }
        return codes
    }
}
