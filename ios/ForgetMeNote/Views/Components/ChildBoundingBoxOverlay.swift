import SwiftUI

/// Renders blue translucent rectangles over a parent Space's image showing
/// where each child sub-space is located (FR-IS-002/003). Tap a rectangle to
/// navigate to that child's detail screen.
///
/// Visual style is configurable via the global Settings:
/// - `childRectangleTransparency`: fill opacity
/// - `childRectangleBorderWidth`: stroke width
/// - `childRectangleBorderTransparency`: stroke opacity
struct ChildBoundingBoxOverlay: View {
    let image: UIImage
    let children: [(id: String, name: String, rect: Rectangle)]
    var settings: AppSettings?
    var onChildTap: (String) -> Void = { _ in }

    private var fillOpacity: Double {
        Double(settings?.childRectangleTransparency ?? 0.25)
    }
    private var borderWidth: Double {
        Double(settings?.childRectangleBorderWidth ?? 3.0)
    }
    private var borderOpacity: Double {
        Double(settings?.childRectangleBorderTransparency ?? 0.4)
    }

    var body: some View {
        GeometryReader { geo in
            let frame = aspectFitFrame(imageSize: image.size, in: geo.size)
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)

                Canvas { ctx, _ in
                    for child in children {
                        let r = denormalize(child.rect, in: frame)
                        let path = Path(roundedRect: r, cornerSize: .zero)
                        ctx.fill(path, with: .color(.blue.opacity(fillOpacity)))
                        ctx.stroke(path,
                                   with: .color(.blue.opacity(borderOpacity)),
                                   lineWidth: borderWidth)
                        // Name badge at top-left of the rectangle
                        ctx.draw(Text(child.name)
                            .font(.caption.bold())
                            .foregroundStyle(.white),
                                 at: CGPoint(x: r.minX + 4, y: r.minY + 4),
                                 anchor: .topLeading)
                    }
                }
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .allowsHitTesting(false)

                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    let r = denormalize(child.rect, in: frame)
                    Color.clear
                        .contentShape(SwiftUI.Rectangle())
                        .frame(width: r.width, height: r.height)
                        .position(x: r.midX, y: r.midY)
                        .onTapGesture { onChildTap(child.id) }
                }
            }
        }
    }

    private func denormalize(_ r: Rectangle, in frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX + CGFloat(r.x) * frame.width,
            y: frame.minY + CGFloat(r.y) * frame.height,
            width: CGFloat(r.width) * frame.width,
            height: CGFloat(r.height) * frame.height
        )
    }

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
