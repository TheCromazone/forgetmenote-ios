import Foundation
import SwiftData

/// Mirrors `com.imageorganizer.app.data.ImageItem` (Room v12 schema).
///
/// `filePath == nil` means this is a "Room" (a container with no photo).
/// `parentId == nil` means root level.
/// `rectangleOnParent` is set on items created by selecting an area on the parent image.
@Model
final class ImageItem {
    @Attribute(.unique) var id: String
    var name: String
    /// Stored in SwiftData as `[String]`. Exported to zip as Gson-style JSON string
    /// to keep the on-disk format compatible with the Android app.
    var tags: [String]
    var thumbnail: String?
    var filePath: String?
    var parentId: String?
    var childIds: [String]
    /// Stored as JSON string in the underlying SQLite to match Android's `rectangleOnParent`
    /// column type. The repository serializes/deserializes against the `rectangle` accessor.
    var rectangleJSON: String?
    /// Epoch milliseconds. Used as the sort key. Reorder mode rewrites this to
    /// preserve order, spaced by 1000 ms between siblings.
    var createdAt: Int64
    /// ARGB packed (`0xFFRRGGBB` style), nil = use settings default.
    var roomBackgroundColor: Int64?
    var roomTextColor: Int64?
    var notes: String
    var isUpdated: Bool
    /// JSON-encoded `TracePath` (freehand outline) in normalized coords relative
    /// to the parent image/region. Optional + nil default → additive, lightweight
    /// SwiftData migration. When set, `rectangleOnParent` holds its bounding box.
    var traceJSON: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        tags: [String] = [],
        thumbnail: String? = nil,
        filePath: String? = nil,
        parentId: String? = nil,
        childIds: [String] = [],
        rectangleOnParent: Rectangle? = nil,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        roomBackgroundColor: Int64? = nil,
        roomTextColor: Int64? = nil,
        notes: String = "",
        isUpdated: Bool = false,
        traceOnParent: TracePath? = nil
    ) {
        self.id = id
        self.name = name
        self.tags = tags
        self.thumbnail = thumbnail
        self.filePath = filePath
        self.parentId = parentId
        self.childIds = childIds
        self.rectangleJSON = rectangleOnParent?.encodeAsJSONString()
        self.createdAt = createdAt
        self.roomBackgroundColor = roomBackgroundColor
        self.roomTextColor = roomTextColor
        self.notes = notes
        self.isUpdated = isUpdated
        self.traceJSON = traceOnParent?.encodeAsJSONString()
    }

    /// Convenience accessor that hides the JSON round-trip.
    var rectangleOnParent: Rectangle? {
        get { Rectangle.decode(rectangleJSON) }
        set { rectangleJSON = newValue?.encodeAsJSONString() }
    }

    /// Freehand trace outline accessor (nil when the spot is a plain rectangle).
    var traceOnParent: TracePath? {
        get { TracePath.decode(traceJSON) }
        set { traceJSON = newValue?.encodeAsJSONString() }
    }

    /// True if this item is a "Room" — no underlying image, just a colored card.
    var isRoom: Bool { filePath == nil }

    /// True when this item is a region OF a photo (its own photo, OR a
    /// rectangle/trace anchored on an ancestor photo) — i.e. it has a picture to
    /// show and can be opened/traced, as opposed to a plain container room/box.
    var v3HasRegion: Bool { filePath != nil || rectangleOnParent != nil }
}
