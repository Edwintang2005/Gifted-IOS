//
//  LinkDetailsFetcher.swift
//  Gifted
//
//  Fills in an item from a product link: title, image and (when the shop publishes
//  it) price. Tries the page's own tags first, then falls back to LinkPresentation.
//

import Foundation
import LinkPresentation
import UniformTypeIdentifiers

nonisolated struct LinkDetails: Equatable {
    var url: URL
    var title: String?
    var imageData: Data?
    var price: Decimal?
    var currencyCode: String?
}

nonisolated enum LinkDetailsFetcher {
    private static let maxHTMLBytes = 2_000_000

    static func fetch(_ url: URL) async -> LinkDetails {
        var details = LinkDetails(url: url)
        var imageURL: URL?

        if let (html, finalURL) = await downloadHTML(url) {
            let metadata = PageMetadataParser.parse(html: html, baseURL: finalURL)
            details.title = metadata.title
            details.price = metadata.price
            details.currencyCode = metadata.currencyCode
            imageURL = metadata.imageURL
        }

        if let imageURL {
            details.imageData = await downloadImage(imageURL)
        }

        if details.title == nil || details.imageData == nil {
            let fallback = await linkPresentationDetails(for: url)
            details.title = details.title ?? fallback.title
            details.imageData = details.imageData ?? fallback.imageData
        }
        return details
    }

    /// Accepts "example.com/thing" as well as full URLs, and finds a link inside shared text.
    static func url(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
           let match = detector.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let url = match.url,
           url.scheme == "https" || url.scheme == "http" {
            return url
        }
        return nil
    }

    // MARK: - Networking

    private static func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 12)
        // Many shops serve a stripped page (or block) unknown user agents.
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent")
        request.setValue("en-AU,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        return request
    }

    private static func downloadHTML(_ url: URL) async -> (String, URL)? {
        guard let (data, response) = try? await URLSession.shared.data(for: request(for: url)),
              let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode)
        else { return nil }
        let slice = data.prefix(maxHTMLBytes)
        guard let html = String(data: slice, encoding: .utf8) ?? String(data: slice, encoding: .isoLatin1)
        else { return nil }
        return (html, response.url ?? url)
    }

    private static func downloadImage(_ url: URL) async -> Data? {
        guard let (data, response) = try? await URLSession.shared.data(for: request(for: url)),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return ImageProcessing.preparedJPEG(from: data)
    }

    private static func linkPresentationDetails(for url: URL) async -> (title: String?, imageData: Data?) {
        let provider = LPMetadataProvider()
        provider.timeout = 10
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return (nil, nil) }
        let title = metadata.title
        var imageData: Data?
        if let imageProvider = metadata.imageProvider {
            imageData = await withCheckedContinuation { continuation in
                _ = imageProvider.loadDataRepresentation(for: .image) { data, _ in
                    continuation.resume(returning: data)
                }
            }
            imageData = imageData.flatMap { ImageProcessing.preparedJPEG(from: $0) }
        }
        return (title, imageData)
    }
}
