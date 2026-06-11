import Foundation
import SwiftData
import UIKit
import ZIPFoundation

/// JSON-manifest export/import for the prototype. The on-disk zip is laid out
/// portably (manifest.json + images/) so a future cross-platform bridge can
/// read it; for now it's iOS↔iOS only.
///
/// Note: we do NOT export the raw SwiftData store file. SwiftData and Android's
/// Room store differ in schema and binary layout; portable JSON survives both.
enum ExportImportService {

    static let manifestName = "manifest.json"
    static let imagesFolder = "images"
    static let manifestVersion = 1

    // MARK: - DTOs

    struct ExportManifest: Codable {
        var version: Int
        var exportedAt: Int64                  // ms since epoch
        var producedBy: String                 // "iOS 0.1.0"
        var items: [ItemDTO]
        var settings: SettingsDTO?
    }

    struct ItemDTO: Codable {
        var id: String
        var name: String
        var tags: [String]
        var thumbnail: String?
        var fileName: String?                  // basename inside images/, nil for Rooms
        var parentId: String?
        var childIds: [String]
        var rectangleJSON: String?
        var createdAt: Int64
        var roomBackgroundColor: Int64?
        var roomTextColor: Int64?
        var notes: String
        var isUpdated: Bool
    }

    struct SettingsDTO: Codable {
        var childRectangleTransparency: Float
        var childRectangleBorderWidth: Float
        var childRectangleBorderTransparency: Float
        var enableTagsListEdit: Bool
        var checkOrphanedImages: Bool
        var searchThroughCollapsedImages: Bool
        var roomBackgroundColor: Int64
        var roomTextColor: Int64
        var updatedHighlightColor: Int64
        var updatedHighlightPercentage: Float
        var showUpdatedBadge: Bool
        var updatedRemindersEnabled: Bool
        var updatedRemindersFrequency: String
        var scaleDownPhotos: Bool
        var scaleDownMinWidth: Int
    }

    // MARK: - Export

    /// Write an export zip to the given URL (typically tmp dir). Returns the
    /// final URL the caller can hand to UIActivityViewController.
    @MainActor
    static func exportToTempFile(modelContext: ModelContext) async throws -> URL {
        let items = (try? modelContext.fetch(FetchDescriptor<ImageItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        ))) ?? []
        let settings = (try? modelContext.fetch(FetchDescriptor<AppSettings>()))?.first

        let manifest = ExportManifest(
            version: manifestVersion,
            exportedAt: Int64(Date().timeIntervalSince1970 * 1000),
            producedBy: "iOS \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")",
            items: items.map(itemDTO(from:)),
            settings: settings.map(settingsDTO(from:))
        )

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let tmpDir = FileManager.default.temporaryDirectory
        let zipURL = tmpDir.appendingPathComponent("ForgetMeNote-\(timestamp).zip")
        try? FileManager.default.removeItem(at: zipURL)

        guard let archive = Archive(url: zipURL, accessMode: .create) else {
            throw NSError(domain: "ExportImportService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not create zip"])
        }

        // 1) Manifest
        let manifestData = try JSONEncoder().encode(manifest)
        try archive.addEntry(
            with: manifestName,
            type: .file,
            uncompressedSize: Int64(manifestData.count),
            provider: { position, size -> Data in
                let start = Int(position)
                let end = min(start + size, manifestData.count)
                return manifestData.subdata(in: start..<end)
            }
        )

        // 2) Images
        for item in items {
            guard let filePath = item.filePath else { continue }
            let url = URL(fileURLWithPath: filePath)
            guard FileManager.default.fileExists(atPath: filePath) else { continue }
            let attrs = try? FileManager.default.attributesOfItem(atPath: filePath)
            let size = (attrs?[.size] as? Int64) ?? 0
            let entryName = "\(imagesFolder)/\(url.lastPathComponent)"
            try archive.addEntry(
                with: entryName,
                type: .file,
                uncompressedSize: size,
                provider: { position, requested -> Data in
                    let handle = try FileHandle(forReadingFrom: url)
                    defer { try? handle.close() }
                    try handle.seek(toOffset: UInt64(position))
                    return handle.readData(ofLength: requested)
                }
            )
        }

        return zipURL
    }

    // MARK: - Import

    /// Non-destructive merge. Returns counts for a summary toast.
    struct ImportSummary {
        let added: Int
        let updated: Int
        let imagesCopied: Int
    }

    @MainActor
    static func importFromZip(_ zipURL: URL, modelContext: ModelContext) async throws -> ImportSummary {
        guard let archive = Archive(url: zipURL, accessMode: .read) else {
            throw NSError(domain: "ExportImportService", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not open zip"])
        }

        // 1) Find + decode manifest
        guard let manifestEntry = archive[manifestName] else {
            throw NSError(domain: "ExportImportService", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Zip is missing manifest.json"])
        }
        var manifestData = Data()
        _ = try archive.extract(manifestEntry) { chunk in manifestData.append(chunk) }
        let manifest = try JSONDecoder().decode(ExportManifest.self, from: manifestData)

        // 2) Compute the images destination directory (matches repo layout).
        let imagesDir = imagesDirectory()
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        // Index by old fileName so we can rewrite filePath after extraction.
        var imagesCopied = 0
        var oldToNewPath: [String: String] = [:]

        // 3) Extract every images/* entry into the images dir (renaming to avoid
        // collision: prepend a UUID prefix).
        for entry in archive where entry.path.hasPrefix("\(imagesFolder)/") {
            let basename = (entry.path as NSString).lastPathComponent
            let newName = "\(UUID().uuidString)_\(basename)"
            let dest = imagesDir.appendingPathComponent(newName)
            try? FileManager.default.removeItem(at: dest)
            FileManager.default.createFile(atPath: dest.path, contents: nil)
            let handle = try FileHandle(forWritingTo: dest)
            _ = try archive.extract(entry) { chunk in
                try? handle.write(contentsOf: chunk)
            }
            try? handle.close()
            oldToNewPath[basename] = dest.path
            imagesCopied += 1
        }

        // 4) Upsert every item.
        var added = 0, updated = 0
        for dto in manifest.items {
            let id = dto.id
            let existing = (try? modelContext.fetch(FetchDescriptor<ImageItem>(
                predicate: #Predicate { $0.id == id }
            )))?.first

            let newFilePath: String? = {
                guard let f = dto.fileName else { return nil }
                return oldToNewPath[f]
            }()

            if let existing {
                existing.name = dto.name
                existing.tags = dto.tags
                existing.thumbnail = dto.thumbnail
                if let newFilePath { existing.filePath = newFilePath }
                existing.parentId = dto.parentId
                existing.childIds = dto.childIds
                existing.rectangleJSON = dto.rectangleJSON
                existing.createdAt = dto.createdAt
                existing.roomBackgroundColor = dto.roomBackgroundColor
                existing.roomTextColor = dto.roomTextColor
                existing.notes = dto.notes
                existing.isUpdated = dto.isUpdated
                updated += 1
            } else {
                let inserted = ImageItem(
                    id: dto.id,
                    name: dto.name,
                    tags: dto.tags,
                    thumbnail: dto.thumbnail,
                    filePath: newFilePath,
                    parentId: dto.parentId,
                    childIds: dto.childIds,
                    rectangleOnParent: nil,    // assigned via rectangleJSON below
                    createdAt: dto.createdAt,
                    roomBackgroundColor: dto.roomBackgroundColor,
                    roomTextColor: dto.roomTextColor,
                    notes: dto.notes,
                    isUpdated: dto.isUpdated
                )
                inserted.rectangleJSON = dto.rectangleJSON
                modelContext.insert(inserted)
                added += 1
            }
        }

        try modelContext.save()
        return ImportSummary(added: added, updated: updated, imagesCopied: imagesCopied)
    }

    // MARK: - Helpers

    private static func itemDTO(from item: ImageItem) -> ItemDTO {
        let fileName = item.filePath.map { ($0 as NSString).lastPathComponent }
        return ItemDTO(
            id: item.id,
            name: item.name,
            tags: item.tags,
            thumbnail: item.thumbnail,
            fileName: fileName,
            parentId: item.parentId,
            childIds: item.childIds,
            rectangleJSON: item.rectangleJSON,
            createdAt: item.createdAt,
            roomBackgroundColor: item.roomBackgroundColor,
            roomTextColor: item.roomTextColor,
            notes: item.notes,
            isUpdated: item.isUpdated
        )
    }

    private static func settingsDTO(from s: AppSettings) -> SettingsDTO {
        SettingsDTO(
            childRectangleTransparency: s.childRectangleTransparency,
            childRectangleBorderWidth: s.childRectangleBorderWidth,
            childRectangleBorderTransparency: s.childRectangleBorderTransparency,
            enableTagsListEdit: s.enableTagsListEdit,
            checkOrphanedImages: s.checkOrphanedImages,
            searchThroughCollapsedImages: s.searchThroughCollapsedImages,
            roomBackgroundColor: s.roomBackgroundColor,
            roomTextColor: s.roomTextColor,
            updatedHighlightColor: s.updatedHighlightColor,
            updatedHighlightPercentage: s.updatedHighlightPercentage,
            showUpdatedBadge: s.showUpdatedBadge,
            updatedRemindersEnabled: s.updatedRemindersEnabled,
            updatedRemindersFrequency: s.updatedRemindersFrequency,
            scaleDownPhotos: s.scaleDownPhotos,
            scaleDownMinWidth: s.scaleDownMinWidth
        )
    }

    /// Documents/images directory used by ImageRepository. Mirrored here so
    /// the import can place extracted images in the same place.
    private static func imagesDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("images", isDirectory: true)
    }
}
