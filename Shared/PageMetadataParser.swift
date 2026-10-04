//
//  PageMetadataParser.swift
//  Gifted
//
//  Pulls a product's title, image and price out of a web page's HTML using the
//  Open Graph / Twitter / schema.org tags most shops publish.
//

import Foundation

nonisolated struct PageMetadata: Equatable {
    var title: String?
    var imageURL: URL?
    var price: Decimal?
    var currencyCode: String?
}

nonisolated enum PageMetadataParser {
    static func parse(html: String, baseURL: URL) -> PageMetadata {
        let meta = metaTags(in: html)
        var result = PageMetadata()

        result.title = first(of: ["og:title", "twitter:title"], in: meta)
            ?? firstCapture(#"<title[^>]*>([\s\S]*?)</title>"#, in: html).map(decodeEntities)
        result.title = result.title.map(collapseWhitespace).flatMap { $0.isEmpty ? nil : $0 }

        let imageCandidate = first(of: ["og:image:secure_url", "og:image", "og:image:url",
                                        "twitter:image", "twitter:image:src", "image"], in: meta)
            ?? firstCapture(#"<link[^>]+rel=["']image_src["'][^>]+href=["']([^"']+)["']"#, in: html)
        if let imageCandidate,
           let url = URL(string: imageCandidate, relativeTo: baseURL)?.absoluteURL,
           url.scheme == "https" || url.scheme == "http" {
            result.imageURL = url
        }

        // Only trust JSON prices inside schema.org blocks: other page JSON often holds
        // prices in cents (Shopify's product JSON says 10000 for $100).
        let structuredData = jsonLDBlocks(in: html).joined(separator: "\n")
        let priceText = first(of: ["product:price:amount", "og:price:amount", "price"], in: meta)
            ?? firstCapture(#""(?:price|lowPrice)"\s*:\s*"?([0-9][0-9.,]*)"#, in: structuredData)
        result.price = priceText.flatMap(PriceParser.parse).flatMap { $0 > 0 ? $0 : nil }

        let currency = first(of: ["product:price:currency", "og:price:currency", "pricecurrency"], in: meta)
            ?? firstCapture(#""priceCurrency"\s*:\s*"([A-Za-z]{3})""#, in: structuredData)
        result.currencyCode = currency.map { $0.uppercased() }.flatMap { $0.count == 3 ? $0 : nil }

        return result
    }

    /// Maps each `<meta>` tag's key (property, name or itemprop, lowercased) to its content.
    /// The first occurrence of a key wins, matching how link previews usually behave.
    static func metaTags(in html: String) -> [String: String] {
        guard let tagPattern = try? Regex(#"<meta\b[^>]*>"#).ignoresCase(),
              let attributePattern = try? Regex(#"([a-zA-Z:_-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))"#)
        else { return [:] }

        var tags: [String: String] = [:]
        for tagMatch in html.matches(of: tagPattern) {
            var attributes: [String: String] = [:]
            for match in html[tagMatch.range].matches(of: attributePattern) {
                guard let name = match.output[1].substring else { continue }
                let value = (2...4).lazy.compactMap { match.output[$0].substring }.first ?? ""
                attributes[name.lowercased()] = String(value)
            }
            guard let content = attributes["content"],
                  let key = attributes["property"] ?? attributes["name"] ?? attributes["itemprop"]
            else { continue }
            let normalisedKey = key.lowercased()
            if tags[normalisedKey] == nil {
                tags[normalisedKey] = decodeEntities(content)
            }
        }
        return tags
    }

    static func jsonLDBlocks(in html: String) -> [String] {
        guard let pattern = try? Regex(#"<script[^>]*application/ld\+json[^>]*>([\s\S]*?)</script>"#).ignoresCase()
        else { return [] }
        return html.matches(of: pattern).compactMap { $0.output[1].substring.map(String.init) }
    }

    private static func first(of keys: [String], in tags: [String: String]) -> String? {
        keys.lazy.compactMap { tags[$0] }.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? Regex(pattern).ignoresCase(),
              let match = text.firstMatch(of: regex),
              let capture = match.output[1].substring
        else { return nil }
        return String(capture)
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text
        let named = ["&quot;": "\"", "&apos;": "'", "&#39;": "'", "&#x27;": "'",
                     "&lt;": "<", "&gt;": ">", "&nbsp;": " ", "&ndash;": "–", "&mdash;": "—"]
        for (entity, replacement) in named {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        if let numeric = try? Regex(#"&#(x?)([0-9a-fA-F]+);"#) {
            result = result.replacing(numeric) { match in
                let isHex = !(match.output[1].substring?.isEmpty ?? true)
                guard let digits = match.output[2].substring,
                      let code = UInt32(digits, radix: isHex ? 16 : 10),
                      let scalar = Unicode.Scalar(code)
                else { return "" }
                return String(Character(scalar))
            }
        }
        // &amp; last so "&amp;quot;" becomes "&quot;" rather than a quote.
        return result.replacingOccurrences(of: "&amp;", with: "&")
    }
}
