//
//  ShareModel.swift
//  GiftedShareExtension
//

import Foundation
import Observation
import SwiftData
import UniformTypeIdentifiers

@Observable
final class ShareModel {
    struct ListOption: Identifiable, Hashable {
        let id: String
        let name: String
    }

    var title = ""
    var priceText = ""
    var currencyCode = Locale.current.currency?.identifier ?? "AUD"
    var notes = ""
    var imageData: Data?
    private(set) var link: URL?

    private(set) var lists: [ListOption] = []
    var selectedListID = AppConfig.defaultWishlistID

    private(set) var isFetchingDetails = false
    private(set) var errorMessage: String?

    var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    @ObservationIgnored private let inputItems: [NSExtensionItem]
    @ObservationIgnored private let onFinish: (Bool) -> Void

    init(inputItems: [NSExtensionItem], onFinish: @escaping (Bool) -> Void) {
        self.inputItems = inputItems
        self.onFinish = onFinish
    }

    // MARK: - Loading

    func load() async {
        loadLists()

        // Safari passes the page title alongside the URL.
        if let pageTitle = inputItems.first?.attributedContentText?.string, !pageTitle.isEmpty {
            title = pageTitle
        }

        let providers = inputItems.flatMap { $0.attachments ?? [] }
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let url = await Self.loadURL(from: provider), url.scheme?.hasPrefix("http") == true {
                link = url
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
                      let data = await Self.loadImageData(from: provider) {
                imageData = ImageProcessing.preparedJPEG(from: data)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                      let text = await Self.loadText(from: provider) {
                if let url = LinkDetailsFetcher.url(from: text) {
                    link = link ?? url
                } else if title.isEmpty {
                    title = text
                }
            }
        }

        guard let link else { return }
        let titleBeforeFetch = title
        isFetchingDetails = true
        let details = await LinkDetailsFetcher.fetch(link)
        isFetchingDetails = false

        // The page's product title is usually cleaner than the tab title Safari sends,
        // but don't clobber anything typed while the page was loading.
        if title == titleBeforeFetch, let fetchedTitle = details.title { title = fetchedTitle }
        if imageData == nil { imageData = details.imageData }
        if priceText.isEmpty, let price = details.price {
            priceText = "\(price)"
            if let currency = details.currencyCode { currencyCode = currency }
        }
    }

    private func loadLists() {
        guard let container = try? GiftedSchema.makeContainer(readOnly: true),
              let stored = try? ModelContext(container).fetch(
                FetchDescriptor<Wishlist>(sortBy: [SortDescriptor(\.createdAt)]))
        else { return }
        lists = stored.map { ListOption(id: $0.id, name: $0.name) }
        if let first = lists.first, !lists.contains(where: { $0.id == selectedListID }) {
            selectedListID = first.id
        }
    }

    // MARK: - Actions

    func save() {
        let entry = InboxEntry(
            wishlistID: lists.isEmpty ? nil : selectedListID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            price: PriceParser.parse(priceText),
            currencyCode: currencyCode,
            link: link,
            notes: notes
        )
        do {
            try Inbox().add(entry, imageData: imageData)
            onFinish(true)
        } catch {
            errorMessage = "Couldn't save to Gifted. Please try again."
        }
    }

    func cancel() {
        onFinish(false)
    }

    // MARK: - Item provider loading
    // Nonisolated so the completion handlers aren't treated as main-actor code; the
    // system calls them on a background queue.

    private nonisolated static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }

    private nonisolated static func loadText(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: String.self) { text, _ in
                continuation.resume(returning: text)
            }
        }
    }

    private nonisolated static func loadImageData(from provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
