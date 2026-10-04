//
//  Inbox.swift
//  Gifted
//
//  Hand-off from the share extension to the app. The extension can't run the sync
//  engine, so it drops each saved item into the app group's Inbox folder. The app
//  imports and uploads them the next time it becomes active.
//

import Foundation

nonisolated struct InboxEntry: Codable, Equatable {
    var id: String = UUID().uuidString
    var wishlistID: String?
    var title: String
    var price: Decimal?
    var currencyCode: String
    var link: URL?
    var notes: String = ""
    var createdAt: Date = .now
    var imageFileName: String?
}

nonisolated struct Inbox {
    var directory: URL = AppConfig.inboxURL

    /// Writes the image first, then the JSON atomically, so a reader never sees an
    /// entry whose image is still being written.
    func add(_ entry: InboxEntry, imageData: Data?) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var entry = entry
        if let imageData {
            let fileName = "\(entry.id).jpg"
            try imageData.write(to: directory.appending(path: fileName), options: .atomic)
            entry.imageFileName = fileName
        }
        let json = try JSONEncoder().encode(entry)
        try json.write(to: directory.appending(path: "\(entry.id).json"), options: .atomic)
    }

    /// Entries waiting to be imported, oldest first.
    func pendingEntries() -> [(entry: InboxEntry, imageData: Data?)] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> (InboxEntry, Data?)? in
                guard let data = try? Data(contentsOf: url),
                      let entry = try? JSONDecoder().decode(InboxEntry.self, from: data)
                else { return nil }
                let image = entry.imageFileName.flatMap {
                    try? Data(contentsOf: directory.appending(path: $0))
                }
                return (entry, image)
            }
            .sorted { $0.0.createdAt < $1.0.createdAt }
    }

    func remove(_ entry: InboxEntry) {
        let fm = FileManager.default
        try? fm.removeItem(at: directory.appending(path: "\(entry.id).json"))
        if let image = entry.imageFileName {
            try? fm.removeItem(at: directory.appending(path: image))
        }
    }
}
