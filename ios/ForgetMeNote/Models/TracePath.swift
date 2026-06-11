import Foundation

/// A single normalized point (0…1) inside the containing image/region.
struct TracePoint: Codable, Hashable, Sendable {
    var x: Float
    var y: Float
}

/// A freehand traced outline (closed polygon) in normalized coords relative to
/// the parent image/region — the "trace an object" companion to `Rectangle`.
/// Persisted as a JSON string on `ImageItem.traceJSON`; its `boundingBox` is
/// stored alongside as `rectangleOnParent` so all the region/nesting math
/// (cropping, sub-trees) reuses the existing rectangle pipeline.
struct TracePath: Codable, Hashable, Sendable {
    var points: [TracePoint]

    static func decode(_ json: String?) -> TracePath? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TracePath.self, from: data)
    }

    func encodeAsJSONString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Tight normalized bounding rectangle around the traced points.
    var boundingBox: Rectangle {
        guard let first = points.first else {
            return Rectangle(x: 0, y: 0, width: 1, height: 1)
        }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for p in points {
            minX = min(minX, p.x); minY = min(minY, p.y)
            maxX = max(maxX, p.x); maxY = max(maxY, p.y)
        }
        return Rectangle(x: minX, y: minY,
                         width: max(0.001, maxX - minX),
                         height: max(0.001, maxY - minY))
    }
}
