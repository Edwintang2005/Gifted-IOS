//
//  ItemCard.swift
//  Gifted
//

import SwiftUI
import UIKit

struct ItemCard<Gift: GiftPresentable>: View {
    let item: Gift

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { ItemImage(data: item.imageData, maxPixelSize: 600) }
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.brandInk)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                Text(item.formattedPrice ?? " ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brandAccent)
            }
            .padding(12)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .accessibilityElement(children: .combine)
    }
}

/// Decodes an item's photo off the main thread at the size it's shown.
struct ItemImage: View {
    let data: Data?
    var maxPixelSize = 1200
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ItemImagePlaceholder()
            }
        }
        .task(id: data) {
            guard let data else {
                image = nil
                return
            }
            let maxPixelSize = maxPixelSize
            image = await Task.detached(priority: .userInitiated) {
                ImageProcessing.thumbnail(from: data, maxPixelSize: maxPixelSize).map { UIImage(cgImage: $0) }
            }.value
        }
        .accessibilityHidden(true)
    }
}
