//
//  RecordMapping.swift
//  Gifted
//
//  Converts between SwiftData models and CloudKit records. All of a user's wishlists
//  live in one custom zone in their private database, which phase 2 will share with
//  friends as a whole via a zone-wide CKShare.
//

import CloudKit
import Foundation

nonisolated enum CloudSchema {
    static let zoneID = CKRecordZone.ID(zoneName: "Wishlists")

    enum RecordType {
        static let wishlist = "Wishlist"
        static let item = "WishItem"
    }

    enum Field {
        static let name = "name"
        static let createdAt = "createdAt"
        static let title = "title"
        static let price = "price"
        static let currencyCode = "currencyCode"
        static let link = "link"
        static let notes = "notes"
        static let image = "image"
        static let wishlist = "wishlist"
    }

    static func recordID(for id: String) -> CKRecord.ID {
        CKRecord.ID(recordName: id, zoneID: zoneID)
    }
}

// MARK: - System fields

nonisolated extension CKRecord {
    /// The record's metadata (ID, change tag, etc.) without its values; enough to
    /// tell the server which version of the record a later save is based on.
    var encodedSystemFields: Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    static func fromSystemFields(_ data: Data) -> CKRecord? {
        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true
        defer { coder.finishDecoding() }
        return CKRecord(coder: coder)
    }
}

/// Starts from the last-known server record when there is one, so saves carry the
/// right change tag; otherwise creates a brand-new record.
private nonisolated func baseRecord(type: String, id: String, systemFields: Data?) -> CKRecord {
    if let systemFields, let record = CKRecord.fromSystemFields(systemFields) {
        return record
    }
    return CKRecord(recordType: type, recordID: CloudSchema.recordID(for: id))
}

// MARK: - Wishlist

extension Wishlist {
    func makeRecord() -> CKRecord {
        let record = baseRecord(type: CloudSchema.RecordType.wishlist, id: id, systemFields: cloudSystemFields)
        record[CloudSchema.Field.name] = name
        record[CloudSchema.Field.createdAt] = createdAt
        return record
    }

    func apply(_ record: CKRecord) {
        name = record[CloudSchema.Field.name] as? String ?? name
        createdAt = record[CloudSchema.Field.createdAt] as? Date ?? createdAt
    }
}

// MARK: - WishItem

extension WishItem {
    /// Only sets the image when it has changed: keys left unset on a record are left
    /// untouched on the server, so unchanged images aren't re-uploaded on every edit.
    func makeRecord(imageFileDirectory: URL = FileManager.default.temporaryDirectory) -> CKRecord {
        let record = baseRecord(type: CloudSchema.RecordType.item, id: id, systemFields: cloudSystemFields)
        record[CloudSchema.Field.title] = title
        // CloudKit has no decimal type; a string keeps prices exact.
        record[CloudSchema.Field.price] = price.map { "\($0)" }
        record[CloudSchema.Field.currencyCode] = currencyCode
        record[CloudSchema.Field.link] = link?.absoluteString
        record[CloudSchema.Field.notes] = notes
        record[CloudSchema.Field.createdAt] = createdAt
        record[CloudSchema.Field.wishlist] = wishlist.map {
            CKRecord.Reference(recordID: CloudSchema.recordID(for: $0.id), action: .none)
        }

        if imageNeedsUpload {
            if let imageData {
                let fileURL = imageFileDirectory.appending(path: "upload-\(id).jpg")
                if (try? imageData.write(to: fileURL, options: .atomic)) != nil {
                    record[CloudSchema.Field.image] = CKAsset(fileURL: fileURL)
                }
            } else {
                record[CloudSchema.Field.image] = nil
            }
        }
        return record
    }

    func apply(_ record: CKRecord) {
        title = record[CloudSchema.Field.title] as? String ?? title
        price = (record[CloudSchema.Field.price] as? String).flatMap {
            Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX"))
        }
        currencyCode = record[CloudSchema.Field.currencyCode] as? String ?? currencyCode
        link = (record[CloudSchema.Field.link] as? String).flatMap(URL.init(string:))
        notes = record[CloudSchema.Field.notes] as? String ?? ""
        createdAt = record[CloudSchema.Field.createdAt] as? Date ?? createdAt

        // Records from the server carry every field, so a missing image means it was removed.
        let asset = record[CloudSchema.Field.image] as? CKAsset
        imageData = asset?.fileURL.flatMap { try? Data(contentsOf: $0) }
        imageNeedsUpload = false
    }

    static func wishlistID(in record: CKRecord) -> String? {
        (record[CloudSchema.Field.wishlist] as? CKRecord.Reference)?.recordID.recordName
    }
}
