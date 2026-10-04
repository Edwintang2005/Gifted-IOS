//
//  ImageProcessing.swift
//  Gifted
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum ImageProcessing {
    /// Downsizes any image the system can decode into a JPEG no larger than `maxPixelSize`
    /// on its longest edge. Uses ImageIO so the full-size image is never decoded into
    /// memory, which matters inside the share extension's tight memory limit.
    static func preparedJPEG(from data: Data, maxPixelSize: Int = 1200, quality: Double = 0.8) -> Data? {
        guard let image = thumbnail(from: data, maxPixelSize: maxPixelSize) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(
            destination, image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// Decodes an image scaled so its longest edge is at most `maxPixelSize`,
    /// keeping its aspect ratio and EXIF orientation.
    static func thumbnail(from data: Data, maxPixelSize: Int) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions)
    }
}
