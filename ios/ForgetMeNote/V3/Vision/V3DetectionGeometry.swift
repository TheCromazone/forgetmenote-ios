import CoreGraphics

/// Pure geometry helpers shared by the V3 detection overlay and service.
/// Kept free of UIKit/Vision so it is trivially unit-testable.
enum V3DetectionGeometry {

    /// Map a normalized rect (0..1, origin top-left) into pixel coordinates
    /// within a container of the given `size`. Mirrors how `V3SpaceScreen`
    /// already positions sub-space rectangles (normalized × frame size).
    static func displayRect(for r: Rectangle, in size: CGSize) -> CGRect {
        CGRect(
            x: CGFloat(r.x) * size.width,
            y: CGFloat(r.y) * size.height,
            width: CGFloat(r.width) * size.width,
            height: CGFloat(r.height) * size.height
        )
    }

    /// Intersection-over-union of two normalized rects (0 = disjoint, 1 = equal).
    static func iou(_ a: Rectangle, _ b: Rectangle) -> Float {
        let ax2 = a.x + a.width, ay2 = a.y + a.height
        let bx2 = b.x + b.width, by2 = b.y + b.height
        let ix = max(0, min(ax2, bx2) - max(a.x, b.x))
        let iy = max(0, min(ay2, by2) - max(a.y, b.y))
        let intersection = ix * iy
        let union = a.width * a.height + b.width * b.height - intersection
        guard union > 0 else { return 0 }
        return intersection / union
    }
}
