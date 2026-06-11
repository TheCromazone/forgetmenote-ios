import UIKit

/// Shared, memory-bounded thumbnail cache for v3 list/grid/carousel cells.
///
/// Cells used to call `UIImage(contentsOfFile:)` (a full-resolution decode)
/// synchronously inside `body`, so a grid of N photos did N full decodes on
/// every render pass / keystroke. `V3Thumbnail.load` decodes ONCE per
/// (path, pixel-size) off the main thread via `V3ImageDownsampler`, caches the
/// small result in an `NSCache`, and returns it. Cards hold the result in
/// `@State` filled from a `.task(id: filePath)`.
enum V3Thumbnail {
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 240          // plenty for any visible grid/carousel
        return c
    }()

    private static func key(_ path: String, _ maxPixelSize: CGFloat) -> NSString {
        "\(path)|\(Int(maxPixelSize))" as NSString
    }

    /// Synchronous cache peek — returns an already-decoded thumbnail if present
    /// so the first frame can show it without a flash.
    static func cached(path: String, maxPixelSize: CGFloat) -> UIImage? {
        cache.object(forKey: key(path, maxPixelSize))
    }

    /// Load (or fetch-from-cache) a downsampled thumbnail off the main thread.
    static func load(path: String?, maxPixelSize: CGFloat) async -> UIImage? {
        guard let path else { return nil }
        let k = key(path, maxPixelSize)
        if let hit = cache.object(forKey: k) { return hit }
        let img = await Task.detached(priority: .utility) {
            V3ImageDownsampler.downsample(path: path, maxPixelSize: maxPixelSize)
        }.value
        if let img { cache.setObject(img, forKey: k) }
        return img
    }
}
