import Foundation
import SwiftData

/// Mirrors Android's `ImageRepository.DeletionStrategy` enum.
enum DeletionStrategy {
    case deleteAllChildren           // recursive cascade
    case attachChildrenToParent      // orphan reparent
    case deleteOnlyIfNoChildren      // throws if children present
}

enum RepositoryError: Error {
    case deletionBlockedByChildren(itemId: String)
    case importMissingDatabaseEntry
}

/// SwiftData-backed port of `com.imageorganizer.app.repository.ImageRepository`.
///
/// Uses `@ModelActor` so all DB work happens off the main actor with its own
/// private `ModelContext`. Views read items via `@Query` directly; this actor
/// handles mutations, search, default-room init, orphan checks, and the
/// import/export paths (zip handling and Android-SQLite reading land in later
/// phases — for now this file ports the core CRUD + business logic).
@ModelActor
actor ImageRepository {

    // MARK: - Path helpers

    /// `~/Documents/images/` — where saved photo files live, per the iOS-side
    /// equivalent of Android's `context.filesDir/images/`.
    nonisolated var imagesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Path produced for a new image file. Matches the Android pattern
    /// `{uuid}_{name}.jpg`.
    nonisolated func imagePath(id: String, name: String) -> URL {
        // Replace path-hostile chars in the name; mirrors implicit filesystem assumptions.
        let safeName = name.replacingOccurrences(of: "/", with: "_")
        return imagesDirectory.appendingPathComponent("\(id)_\(safeName).jpg")
    }

    // MARK: - One-shot reads

    func image(id: String) -> ImageItem? {
        let descriptor = FetchDescriptor<ImageItem>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    func allImages() -> [ImageItem] {
        let descriptor = FetchDescriptor<ImageItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func rootImages() -> [ImageItem] {
        let descriptor = FetchDescriptor<ImageItem>(
            predicate: #Predicate { $0.parentId == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func children(of parentId: String) -> [ImageItem] {
        let descriptor = FetchDescriptor<ImageItem>(
            predicate: #Predicate { $0.parentId == parentId },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func updatedItemsCount() -> Int {
        let descriptor = FetchDescriptor<ImageItem>(predicate: #Predicate { $0.isUpdated == true })
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    /// Distinct, sorted set of every tag across every item.
    func allUniqueTags() -> [String] {
        var tags = Set<String>()
        for item in allImages() {
            for tag in item.tags where !tag.isEmpty {
                tags.insert(tag)
            }
        }
        return tags.sorted()
    }

    /// Case-insensitive search across name + tags + notes (FR-NOTE-004).
    func search(query: String) -> [ImageItem] {
        let needle = query.lowercased()
        guard !needle.isEmpty else { return allImages() }
        return allImages().filter { item in
            item.name.lowercased().contains(needle) ||
            item.notes.lowercased().contains(needle) ||
            item.tags.contains(where: { $0.lowercased().contains(needle) })
        }
    }

    // MARK: - Mutations

    @discardableResult
    func createRoom(
        name: String,
        tags: [String] = [],
        parentId: String? = nil,
        backgroundColor: Int64? = nil,
        textColor: Int64? = nil
    ) throws -> String {
        let item = ImageItem(
            name: name,
            tags: tags,
            thumbnail: nil,
            filePath: nil,
            parentId: parentId,
            roomBackgroundColor: backgroundColor,
            roomTextColor: textColor
        )
        modelContext.insert(item)
        try attachToParent(itemId: item.id, parentId: parentId)
        try modelContext.save()
        return item.id
    }

    /// Create a sub-space (region) anchored on a parent photo by a rectangle,
    /// WITHOUT its own photo. Used by the v3 detection / "mark a spot" flow when
    /// the user doesn't attach a picture. Additive — mirrors `createRoom` plus a
    /// `rectangleOnParent`.
    @discardableResult
    func createSubSpace(
        name: String,
        tags: [String] = [],
        parentId: String,
        rectangleOnParent: Rectangle?,
        traceOnParent: TracePath? = nil
    ) throws -> String {
        let item = ImageItem(
            name: name,
            tags: tags,
            thumbnail: nil,
            filePath: nil,
            parentId: parentId,
            rectangleOnParent: rectangleOnParent,
            traceOnParent: traceOnParent
        )
        modelContext.insert(item)
        try attachToParent(itemId: item.id, parentId: parentId)
        try modelContext.save()
        return item.id
    }

    @discardableResult
    func saveImage(
        jpegData: Data,
        name: String,
        tags: [String] = [],
        parentId: String? = nil,
        rectangleOnParent: Rectangle? = nil,
        traceOnParent: TracePath? = nil
    ) throws -> String {
        let id = UUID().uuidString
        let url = imagePath(id: id, name: name)
        try jpegData.write(to: url, options: .atomic)

        // Treat the magic ROOT_PARENT_SENTINEL as "no parent".
        let effectiveParent: String? = (parentId == "__root__") ? nil : parentId

        let item = ImageItem(
            id: id,
            name: name,
            tags: tags,
            thumbnail: url.path,
            filePath: url.path,
            parentId: effectiveParent,
            rectangleOnParent: (effectiveParent == nil) ? nil : rectangleOnParent,
            traceOnParent: (effectiveParent == nil) ? nil : traceOnParent
        )
        modelContext.insert(item)
        try attachToParent(itemId: id, parentId: effectiveParent)
        try modelContext.save()
        return id
    }

    func update(_ image: ImageItem) throws {
        // Image is already managed by the context — just save.
        try modelContext.save()
    }

    // MARK: - Per-field updates (used by edit-in-place UI)

    func updateName(itemId: String, name: String) throws {
        guard let item = image(id: itemId) else { return }
        item.name = name
        try modelContext.save()
    }

    func updateTags(itemId: String, tags: [String]) throws {
        guard let item = image(id: itemId) else { return }
        item.tags = tags
        try modelContext.save()
    }

    func updateNotes(itemId: String, notes: String) throws {
        guard let item = image(id: itemId) else { return }
        item.notes = notes
        try modelContext.save()
    }

    /// Flip the `isUpdated` flag and persist. Returns the new value.
    @discardableResult
    func toggleUpdated(itemId: String) throws -> Bool {
        guard let item = image(id: itemId) else { return false }
        item.isUpdated.toggle()
        try modelContext.save()
        return item.isUpdated
    }

    func setUpdated(itemId: String, value: Bool) throws {
        guard let item = image(id: itemId) else { return }
        item.isUpdated = value
        try modelContext.save()
    }

    /// Replaces an item's photo file. Mirrors Android's
    /// `updateImageFromBitmap` — including the `isUpdated = false` side effect
    /// (FR-UPDATE-006).
    func replaceImageFile(itemId: String, with jpegData: Data) throws {
        guard let item = image(id: itemId) else { return }
        if let oldPath = item.filePath {
            try? FileManager.default.removeItem(atPath: oldPath)
        }
        let url = imagePath(id: item.id, name: item.name)
        try jpegData.write(to: url, options: .atomic)
        item.filePath = url.path
        item.thumbnail = url.path
        item.isUpdated = false
        try modelContext.save()
    }

    /// Rewrites `createdAt` on the given items to preserve their order,
    /// spaced 1000 ms apart. Matches Android `updateImageOrder`.
    func reorder(ids orderedIds: [String]) throws {
        let baseTime = Int64(Date().timeIntervalSince1970 * 1000)
        for (index, id) in orderedIds.enumerated() {
            if let item = image(id: id) {
                item.createdAt = baseTime + Int64(index) * 1000
            }
        }
        try modelContext.save()
    }

    func delete(itemId: String, strategy: DeletionStrategy) throws {
        guard let item = image(id: itemId) else { return }
        switch strategy {
        case .deleteAllChildren:
            try deleteRecursive(item)
        case .attachChildrenToParent:
            try deleteAndReparent(item)
        case .deleteOnlyIfNoChildren:
            if !item.childIds.isEmpty {
                throw RepositoryError.deletionBlockedByChildren(itemId: item.id)
            }
            try deleteRecursive(item)
        }
        try modelContext.save()
    }

    // MARK: - Default rooms (first-launch seeding)

    private static let defaultRoomsFlagKey = "com.imageorganizer.app.defaultRoomsCreated"

    /// On first launch, create "My home", "Good things", "Bad things" rooms.
    /// Mirrors Android `initializeDefaultRoomsIfNeeded`.
    func initializeDefaultRoomsIfNeeded() throws {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.defaultRoomsFlagKey) else { return }
        let base = Int64(Date().timeIntervalSince1970 * 1000)

        let myHome = ImageItem(name: "My home", createdAt: base)
        let goodThings = ImageItem(name: "Good things", createdAt: base + 1000)
        let badThings = ImageItem(name: "Bad things", createdAt: base + 2000)

        modelContext.insert(myHome)
        modelContext.insert(goodThings)
        modelContext.insert(badThings)
        try modelContext.save()
        defaults.set(true, forKey: Self.defaultRoomsFlagKey)
    }

    // MARK: - Orphan detection

    func checkOrphanedImages() -> [ImageItem] {
        allImages().filter { item in
            guard let path = item.filePath else { return false } // rooms aren't orphans
            return !FileManager.default.fileExists(atPath: path)
        }
    }

    @discardableResult
    func removeOrphanedImages() throws -> Int {
        // Direction 1: DB rows whose file is missing — delete the row.
        let orphans = checkOrphanedImages()
        for orphan in orphans {
            detachFromParent(orphan)
            modelContext.delete(orphan)
        }
        try modelContext.save()

        // Direction 2: files on disk that no DB row references — delete the file.
        let onDiskOrphans = orphanFilesOnDisk()
        for url in onDiskOrphans {
            try? FileManager.default.removeItem(at: url)
        }

        return orphans.count + onDiskOrphans.count
    }

    /// Files inside the images dir that are not referenced by any ImageItem.
    /// These accumulate when items are deleted via cascade and the on-disk
    /// file deletion fails or is skipped.
    func orphanFilesOnDisk() -> [URL] {
        let fm = FileManager.default
        let dir = imagesDirectory
        guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        let referenced = Set(allImages().compactMap { $0.filePath })
        return contents.filter { !referenced.contains($0.path) }
    }

    // MARK: - Settings

    /// Lazy single-row Settings. Insert defaults if none.
    func settings() -> AppSettings {
        if let existing = try? modelContext.fetch(FetchDescriptor<AppSettings>()).first {
            return existing
        }
        let fresh = AppSettings()
        modelContext.insert(fresh)
        try? modelContext.save()
        return fresh
    }

    func saveSettings() throws {
        try modelContext.save()
    }

    // MARK: - Private helpers

    private func attachToParent(itemId: String, parentId: String?) throws {
        guard let parentId, let parent = image(id: parentId) else { return }
        if !parent.childIds.contains(itemId) {
            parent.childIds.append(itemId)
        }
    }

    private func detachFromParent(_ item: ImageItem) {
        guard let parentId = item.parentId, let parent = image(id: parentId) else { return }
        parent.childIds.removeAll { $0 == item.id }
    }

    private func deleteRecursive(_ item: ImageItem) throws {
        // Delete the on-disk image file
        if let path = item.filePath { try? FileManager.default.removeItem(atPath: path) }
        if let thumb = item.thumbnail, thumb != item.filePath {
            try? FileManager.default.removeItem(atPath: thumb)
        }

        // Recurse into children
        for child in childItems(for: item) {
            try deleteRecursive(child)
        }

        // Remove from parent
        detachFromParent(item)
        modelContext.delete(item)
    }

    private func deleteAndReparent(_ item: ImageItem) throws {
        if let path = item.filePath { try? FileManager.default.removeItem(atPath: path) }
        if let thumb = item.thumbnail, thumb != item.filePath {
            try? FileManager.default.removeItem(atPath: thumb)
        }

        let children = childItems(for: item)
        let childIds = children.map(\.id)
        for child in children {
            child.parentId = item.parentId
        }

        // Splice child ids into the parent in this item's place
        if let parentId = item.parentId, let parent = image(id: parentId) {
            parent.childIds.removeAll { $0 == item.id }
            for cid in childIds where !parent.childIds.contains(cid) {
                parent.childIds.append(cid)
            }
        }

        modelContext.delete(item)
    }

    private func childItems(for item: ImageItem) -> [ImageItem] {
        var seen = Set<String>()
        var result: [ImageItem] = []
        for childId in item.childIds {
            guard let child = image(id: childId), seen.insert(child.id).inserted else { continue }
            result.append(child)
        }
        for child in children(of: item.id) where seen.insert(child.id).inserted {
            result.append(child)
        }
        return result
    }
}
