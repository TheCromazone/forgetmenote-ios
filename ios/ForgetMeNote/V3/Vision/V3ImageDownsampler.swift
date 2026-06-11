import UIKit
import ImageIO

/// ImageIO-based downsampling so we never decode a full-resolution camera
/// bitmap into memory just to show it behind the crop box. v3-only.
enum V3ImageDownsampler {

    /// Downsample an image file to roughly `maxPixelSize` on its longest edge.
    static func downsample(path: String, maxPixelSize: CGFloat = 1400) -> UIImage? {
        let url = URL(fileURLWithPath: path)
        let srcOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithURL(url as CFURL, srcOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixelSize, 1)
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// Downsample an in-memory image (e.g. a freshly captured temp photo).
    static func downsample(_ image: UIImage, maxPixelSize: CGFloat = 1400) -> UIImage {
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > maxPixelSize else { return image }
        let ratio = maxPixelSize / maxSide
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize, format: .default())
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
