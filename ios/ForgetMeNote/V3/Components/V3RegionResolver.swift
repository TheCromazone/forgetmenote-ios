import UIKit

/// Where an item's picture actually lives. Either the item has its own photo
/// (`rect` == full frame) or it's a rectangle/trace region of some ancestor's
/// photo, in which case `rect` is its normalized box WITHIN that photo.
struct V3Region: Hashable {
    let path: String
    let rect: Rectangle
}

/// Resolves an item to the photo it should display, composing the chain of
/// `rectangleOnParent`s up to the nearest photo-bearing ancestor. This is what
/// lets a traced shelf (no photo of its own) show the cropped slice of the room
/// photo, and a traced object on that shelf show its slice — recursively.
enum V3RegionResolver {
    static func region(for item: ImageItem, byId: [String: ImageItem]) -> V3Region? {
        if let fp = item.filePath {
            return V3Region(path: fp, rect: Rectangle(x: 0, y: 0, width: 1, height: 1))
        }
        var rects: [Rectangle] = []
        var cur: ImageItem? = item
        var hops = 0
        while let c = cur, hops < 64 {
            hops += 1
            if let fp = c.filePath {
                var region = Rectangle(x: 0, y: 0, width: 1, height: 1)
                for r in rects.reversed() { region = compose(region, r) }
                return V3Region(path: fp, rect: region)
            }
            guard let r = c.rectangleOnParent else { return nil }  // a plain room/box
            rects.append(r)
            cur = c.parentId.flatMap { byId[$0] }
        }
        return nil
    }

    /// id → region for every item that has a picture, built once per render.
    static func map(items: [ImageItem]) -> [String: V3Region] {
        let byId = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var out: [String: V3Region] = [:]
        for item in items {
            if let region = region(for: item, byId: byId) { out[item.id] = region }
        }
        return out
    }

    /// Place `inner` (normalized within `outer`'s region) into the photo frame.
    static func compose(_ outer: Rectangle, _ inner: Rectangle) -> Rectangle {
        Rectangle(
            x: outer.x + inner.x * outer.width,
            y: outer.y + inner.y * outer.height,
            width: inner.width * outer.width,
            height: inner.height * outer.height
        )
    }
}

/// Loads (and crops) the slice of a photo a region occupies. Built on the
/// existing off-main `V3Thumbnail` decode, then crops to the normalized rect.
enum V3RegionImage {
    static func cached(_ region: V3Region, maxPixelSize: CGFloat) -> UIImage? {
        guard let full = V3Thumbnail.cached(path: region.path, maxPixelSize: maxPixelSize) else { return nil }
        return crop(full, region.rect)
    }

    static func load(_ region: V3Region, maxPixelSize: CGFloat) async -> UIImage? {
        guard let full = await V3Thumbnail.load(path: region.path, maxPixelSize: maxPixelSize) else { return nil }
        return crop(full, region.rect)
    }

    static func crop(_ image: UIImage, _ r: Rectangle) -> UIImage? {
        // Whole-frame region → no work.
        if r.x <= 0.0001, r.y <= 0.0001, r.width >= 0.9999, r.height >= 0.9999 { return image }
        guard let cg = image.cgImage else { return image }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let raw = CGRect(x: CGFloat(r.x) * w, y: CGFloat(r.y) * h,
                         width: CGFloat(r.width) * w, height: CGFloat(r.height) * h)
        let bounds = CGRect(x: 0, y: 0, width: w, height: h)
        let rect = raw.integral.intersection(bounds)
        guard rect.width >= 1, rect.height >= 1, let cropped = cg.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}
