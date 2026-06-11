import SwiftUI

/// Port of `InteractiveRectangleSelector.kt`.
///
/// Displays an image with a draggable, resizable rectangle overlay used to
/// select an area on a parent image when creating a child sub-space.
///
/// Behavior:
/// - Drag inside the rectangle → translate it (clamped to image bounds)
/// - Drag on a corner (8pt hit zone) → resize from that corner
/// - Drag on an edge (8pt hit zone) → resize from that edge
/// - Drag outside the rectangle → create a new rectangle from the drag start
///
/// The `rect` binding is in normalized (0...1) image-space coordinates,
/// matching `Rectangle` (the model type) and the on-disk format.
struct InteractiveRectangleSelector: View {
    let image: UIImage
    @Binding var rect: Rectangle
    /// Optional list of child rectangles to render in blue underneath the
    /// editable green rectangle (read-only display for existing children).
    var existingChildren: [Rectangle] = []
    /// Optional list of detected-object rectangles to render in semi-transparent green.
    var detectedObjects: [(rect: Rectangle, label: String)] = []

    private static let cornerHitSize: CGFloat = 32
    private static let edgeHitSize: CGFloat = 24

    /// Which part of the rectangle is currently being dragged.
    private enum DragMode {
        case translate
        case resizeCorner(Corner)
        case resizeEdge(Edge)
        case newRect(start: CGPoint)
    }
    private enum Corner { case topLeft, topRight, bottomLeft, bottomRight }
    private enum Edge { case top, bottom, leading, trailing }

    @State private var dragMode: DragMode?
    @State private var rectAtDragStart: Rectangle?

    var body: some View {
        GeometryReader { geo in
            let imageFrame = aspectFitFrame(imageSize: image.size, in: geo.size)
            ZStack {
                Color.clear
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageFrame.width, height: imageFrame.height)
                    .position(x: imageFrame.midX, y: imageFrame.midY)

                Canvas { ctx, size in
                    // Children: solid blue, low alpha fill + blue border
                    for child in existingChildren {
                        let r = denormalize(child, in: imageFrame)
                        ctx.fill(Path(roundedRect: r, cornerSize: .zero),
                                 with: .color(.blue.opacity(0.18)))
                        ctx.stroke(Path(roundedRect: r, cornerSize: .zero),
                                   with: .color(.blue), lineWidth: 2)
                    }
                    // Detected objects: green dashed border
                    for det in detectedObjects {
                        let r = denormalize(det.rect, in: imageFrame)
                        ctx.stroke(Path(roundedRect: r, cornerSize: .zero),
                                   with: .color(.green), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    }
                    // Editable rectangle: green border + corner handles
                    let r = denormalize(rect, in: imageFrame)
                    ctx.stroke(Path(roundedRect: r, cornerSize: .zero),
                               with: .color(.green), lineWidth: 3)
                    let handles: [(CGFloat, CGFloat)] = [
                        (r.minX, r.minY), (r.maxX, r.minY),
                        (r.minX, r.maxY), (r.maxX, r.maxY)
                    ]
                    for (x, y) in handles {
                        let handleRect = CGRect(x: x - 6, y: y - 6, width: 12, height: 12)
                        ctx.fill(Path(ellipseIn: handleRect), with: .color(.green))
                        ctx.stroke(Path(ellipseIn: handleRect), with: .color(.white), lineWidth: 2)
                    }
                }
                .frame(width: imageFrame.width, height: imageFrame.height)
                .position(x: imageFrame.midX, y: imageFrame.midY)

                // Invisible interaction layer matching the image frame.
                Color.clear
                    .contentShape(SwiftUI.Rectangle())
                    .frame(width: imageFrame.width, height: imageFrame.height)
                    .position(x: imageFrame.midX, y: imageFrame.midY)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                handleDragChanged(value, imageFrame: imageFrame)
                            }
                            .onEnded { _ in
                                dragMode = nil
                                rectAtDragStart = nil
                            }
                    )
            }
        }
    }

    // MARK: - Drag handling

    private func handleDragChanged(_ value: DragGesture.Value, imageFrame: CGRect) {
        let local = CGPoint(x: value.location.x - imageFrame.minX,
                            y: value.location.y - imageFrame.minY)
        let startLocal = CGPoint(x: value.startLocation.x - imageFrame.minX,
                                 y: value.startLocation.y - imageFrame.minY)

        // Initialize dragMode on first onChanged tick
        if dragMode == nil {
            rectAtDragStart = rect
            let r = denormalize(rect, in: CGRect(origin: .zero, size: imageFrame.size))
            dragMode = pickDragMode(touch: startLocal, rectInLocal: r)
        }

        guard let mode = dragMode,
              let start = rectAtDragStart else { return }

        let frameSize = imageFrame.size
        let startRect = denormalize(start, in: CGRect(origin: .zero, size: frameSize))
        let dx = value.translation.width
        let dy = value.translation.height

        switch mode {
        case .translate:
            var moved = startRect
            moved.origin.x = max(0, min(frameSize.width - moved.width, startRect.minX + dx))
            moved.origin.y = max(0, min(frameSize.height - moved.height, startRect.minY + dy))
            rect = normalize(moved, in: frameSize)

        case .resizeCorner(let corner):
            var resized = resize(startRect, dx: dx, dy: dy, corner: corner)
            resized = clamp(resized, to: frameSize)
            rect = normalize(resized, in: frameSize)

        case .resizeEdge(let edge):
            var resized = resize(startRect, dx: dx, dy: dy, edge: edge)
            resized = clamp(resized, to: frameSize)
            rect = normalize(resized, in: frameSize)

        case .newRect(let startPoint):
            let minX = min(startPoint.x, local.x)
            let minY = min(startPoint.y, local.y)
            let w = abs(local.x - startPoint.x)
            let h = abs(local.y - startPoint.y)
            var newRect = CGRect(x: minX, y: minY, width: w, height: h)
            newRect = clamp(newRect, to: frameSize)
            rect = normalize(newRect, in: frameSize)
        }
    }

    private func pickDragMode(touch: CGPoint, rectInLocal r: CGRect) -> DragMode {
        let corners: [(Corner, CGPoint)] = [
            (.topLeft, CGPoint(x: r.minX, y: r.minY)),
            (.topRight, CGPoint(x: r.maxX, y: r.minY)),
            (.bottomLeft, CGPoint(x: r.minX, y: r.maxY)),
            (.bottomRight, CGPoint(x: r.maxX, y: r.maxY))
        ]
        for (corner, pt) in corners {
            if hypot(touch.x - pt.x, touch.y - pt.y) < Self.cornerHitSize {
                return .resizeCorner(corner)
            }
        }
        // Edges
        let edgeBand = Self.edgeHitSize
        if r.insetBy(dx: -edgeBand, dy: -edgeBand).contains(touch),
           !r.insetBy(dx: edgeBand, dy: edgeBand).contains(touch) {
            // Touch is on an edge band
            if abs(touch.y - r.minY) < edgeBand && touch.x > r.minX && touch.x < r.maxX { return .resizeEdge(.top) }
            if abs(touch.y - r.maxY) < edgeBand && touch.x > r.minX && touch.x < r.maxX { return .resizeEdge(.bottom) }
            if abs(touch.x - r.minX) < edgeBand && touch.y > r.minY && touch.y < r.maxY { return .resizeEdge(.leading) }
            if abs(touch.x - r.maxX) < edgeBand && touch.y > r.minY && touch.y < r.maxY { return .resizeEdge(.trailing) }
        }
        if r.contains(touch) {
            return .translate
        }
        return .newRect(start: touch)
    }

    private func resize(_ r: CGRect, dx: CGFloat, dy: CGFloat, corner: Corner) -> CGRect {
        var newRect = r
        switch corner {
        case .topLeft:
            newRect.origin.x += dx
            newRect.origin.y += dy
            newRect.size.width -= dx
            newRect.size.height -= dy
        case .topRight:
            newRect.origin.y += dy
            newRect.size.width += dx
            newRect.size.height -= dy
        case .bottomLeft:
            newRect.origin.x += dx
            newRect.size.width -= dx
            newRect.size.height += dy
        case .bottomRight:
            newRect.size.width += dx
            newRect.size.height += dy
        }
        return normalizingNegativeSize(newRect)
    }

    private func resize(_ r: CGRect, dx: CGFloat, dy: CGFloat, edge: Edge) -> CGRect {
        var newRect = r
        switch edge {
        case .top:
            newRect.origin.y += dy
            newRect.size.height -= dy
        case .bottom:
            newRect.size.height += dy
        case .leading:
            newRect.origin.x += dx
            newRect.size.width -= dx
        case .trailing:
            newRect.size.width += dx
        }
        return normalizingNegativeSize(newRect)
    }

    /// If a resize made width/height negative, flip the origin so size stays positive.
    private func normalizingNegativeSize(_ r: CGRect) -> CGRect {
        var result = r
        if result.width < 0 {
            result.origin.x += result.width
            result.size.width = -result.width
        }
        if result.height < 0 {
            result.origin.y += result.height
            result.size.height = -result.height
        }
        return result
    }

    private func clamp(_ r: CGRect, to size: CGSize) -> CGRect {
        var result = r
        result.size.width = max(20, min(size.width, result.width))
        result.size.height = max(20, min(size.height, result.height))
        result.origin.x = max(0, min(size.width - result.width, result.minX))
        result.origin.y = max(0, min(size.height - result.height, result.minY))
        return result
    }

    // MARK: - Coordinate conversion

    private func denormalize(_ r: Rectangle, in frame: CGRect) -> CGRect {
        CGRect(
            x: CGFloat(r.x) * frame.width,
            y: CGFloat(r.y) * frame.height,
            width: CGFloat(r.width) * frame.width,
            height: CGFloat(r.height) * frame.height
        )
    }

    private func normalize(_ r: CGRect, in size: CGSize) -> Rectangle {
        Rectangle(
            x: Float(r.minX / size.width),
            y: Float(r.minY / size.height),
            width: Float(r.width / size.width),
            height: Float(r.height / size.height)
        )
    }

    /// Returns the largest `CGRect` centered in `containerSize` that fits the
    /// image's aspect ratio. Equivalent to `.scaledToFit`'s effective frame.
    private func aspectFitFrame(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let scale = min(containerSize.width / imageSize.width,
                        containerSize.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(x: (containerSize.width - w) / 2,
                      y: (containerSize.height - h) / 2,
                      width: w, height: h)
    }
}
