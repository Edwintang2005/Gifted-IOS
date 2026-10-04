//
//  ParsingTests.swift
//  GiftedTests
//

import Foundation
import Testing
@testable import Gifted

struct PriceParserTests {
    @Test(arguments: [
        ("$1,299.00", Decimal(1299)),
        ("1.299,00 €", Decimal(1299)),
        ("49.95", Decimal(string: "49.95")!),
        ("12,50", Decimal(string: "12.5")!),
        ("1,299", Decimal(1299)),
        ("1.299.000", Decimal(1_299_000)),
        ("AU$ 89", Decimal(89)),
        ("Rs. 500", Decimal(500)),
    ])
    func parsesCommonFormats(text: String, expected: Decimal) {
        #expect(PriceParser.parse(text) == expected)
    }

    @Test(arguments: ["", "free", "$", "..."])
    func rejectsTextWithoutNumbers(text: String) {
        #expect(PriceParser.parse(text) == nil)
    }
}

struct PageMetadataParserTests {
    let base = URL(string: "https://shop.example.com/products/tote")!

    @Test func readsOpenGraphTags() {
        let html = """
        <html><head>
        <title>Ignored | Shop</title>
        <meta property="og:title" content="Tokyo Totepack &amp; Strap">
        <meta content="/images/tote.jpg" property="og:image" />
        <meta property="product:price:amount" content="189.00">
        <meta property="product:price:currency" content="aud">
        </head></html>
        """
        let metadata = PageMetadataParser.parse(html: html, baseURL: base)
        #expect(metadata.title == "Tokyo Totepack & Strap")
        #expect(metadata.imageURL == URL(string: "https://shop.example.com/images/tote.jpg"))
        #expect(metadata.price == 189)
        #expect(metadata.currencyCode == "AUD")
    }

    @Test func fallsBackToTitleTagAndJSONLD() {
        let html = """
        <head><title>
          Le Creuset   Casserole
        </title>
        <script type="application/ld+json">
        {"@type":"Product","offers":{"@type":"Offer","price":"579.95","priceCurrency":"AUD"}}
        </script></head>
        """
        let metadata = PageMetadataParser.parse(html: html, baseURL: base)
        #expect(metadata.title == "Le Creuset Casserole")
        #expect(metadata.price == Decimal(string: "579.95"))
        #expect(metadata.currencyCode == "AUD")
        #expect(metadata.imageURL == nil)
    }

    @Test func ignoresCentPricesOutsideStructuredData() {
        // Shopify embeds product JSON with prices in cents alongside correct JSON-LD.
        let html = """
        <meta property='og:price:currency' content='USD'>
        <script>var meta = {"product":{"variants":[{"price":10000}]}};</script>
        <script type="application/ld+json">{"offers":[{"@type":"Offer","price": 100,"priceCurrency":"USD"}]}</script>
        """
        let metadata = PageMetadataParser.parse(html: html, baseURL: base)
        #expect(metadata.price == 100)
        #expect(metadata.currencyCode == "USD")

        let withoutStructuredData = PageMetadataParser.parse(
            html: #"<script>{"price":10000}</script>"#, baseURL: base)
        #expect(withoutStructuredData.price == nil)
    }

    @Test func firstTagWinsAndIgnoresNonHTTPImages() {
        let html = """
        <meta name="twitter:title" content="Second">
        <meta property="og:title" content="First">
        <meta property="og:title" content="Duplicate">
        <meta property="og:image" content="data:image/png;base64,AAAA">
        """
        let metadata = PageMetadataParser.parse(html: html, baseURL: base)
        #expect(metadata.title == "First")
        #expect(metadata.imageURL == nil)
    }

    @Test func decodesNumericEntities() {
        #expect(PageMetadataParser.decodeEntities("Kids&#39; Bike &#x2014; Red &amp;quot;") == "Kids' Bike — Red &quot;")
    }
}

struct LinkDetectionTests {
    @Test func findsLinksInSharedText() {
        #expect(LinkDetailsFetcher.url(from: "Look at this https://example.com/a?b=1 !")
                == URL(string: "https://example.com/a?b=1"))
        #expect(LinkDetailsFetcher.url(from: "example.com/thing")?.host() == "example.com")
        #expect(LinkDetailsFetcher.url(from: "just some words") == nil)
    }
}
