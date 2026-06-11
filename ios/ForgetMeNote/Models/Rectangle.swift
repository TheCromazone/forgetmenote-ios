import Foundation

/// Normalized bounding rectangle, all values 0.0 ... 1.0 relative to the
/// containing image's width/height. Mirrors `com.imageorganizer.app.data.Rectangle`.
struct Rectangle: Codable, Hashable, Sendable {
    var x: Float
    var y: Float
    var width: Float
    var height: Float

    init(x: Float, y: Float, width: Float, height: Float) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Parses the Gson-encoded JSON form stored in Android's `rectangleOnParent`
    /// column: `{"x":0.1,"y":0.2,"width":0.3,"height":0.4}`.
    static func decode(_ json: String?) -> Rectangle? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Rectangle.self, from: data)
    }

    /// Encodes to the same JSON shape Android uses, for round-trip export.
    func encodeAsJSONString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
