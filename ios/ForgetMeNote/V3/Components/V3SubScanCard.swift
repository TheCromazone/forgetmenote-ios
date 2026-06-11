import SwiftUI

/// V3 sub-scan card — narrower (168 x 224) tile showing the parent's photo
/// cropped to a sub-rect, with a number badge top-left and optional updated
/// badge top-right. Port of `SubScanCard` from screens-space.jsx.
///
/// To "crop" using only the parent image, we render the parent image scaled
/// up so the rect fills the tile, then clip. The image's resizable+frame is
/// laid out at the inverse scale of the rect and offset so the rect lands at
/// the origin.
struct V3SubScanCard: View {
    let palette: V3Palette
    let sub: ImageItem
    let parentImage: UIImage?
    let index: Int
    let isActive: Bool
    var onTap: () -> Void = {}

    private let tileHeight: CGFloat = 224
    /// Tile width follows the sub-region's TRUE aspect ratio (rect size in
    /// parent-image pixels) so the card shows the whole spot undistorted —
    /// a wide shelf gets a wide card, a tall lamp a narrow one. Clamped so
    /// extreme slivers stay tappable and the row stays tidy.
    private var tileWidth: CGFloat { min(max(tileHeight * regionAspect, 112), 280) }

    private var regionAspect: CGFloat {
        if let img = parentImage, let rect = sub.rectangleOnParent,
           rect.width > 0, rect.height > 0,
           img.size.width > 0, img.size.height > 0 {
            return (CGFloat(rect.width) * img.size.width)
                 / (CGFloat(rect.height) * img.size.height)
        }
        if let t = fallbackThumb, t.size.width > 0, t.size.height > 0 {
            return t.size.width / t.size.height
        }
        return 0.75
    }

    /// Disk-loaded fallback thumbnail used only when `parentImage` is nil; the
    /// preferred path crops from the in-memory `parentImage`.
    @State private var fallbackThumb: UIImage?

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    cropView
                        .frame(width: tileWidth, height: tileHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(isActive ? palette.accent : palette.line,
                                              lineWidth: isActive ? 2 : 1)
                        )

                    // Number badge top-left
                    Text("\(index)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(
                            (isActive ? palette.accent : Color(white: 0.08).opacity(0.6)),
                            in: Circle()
                        )
                        .padding(8)

                    if sub.isUpdated {
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle().fill(palette.pollen)
                                    Image(systemName: "sparkle")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color(hex: 0x3D2A0E))
                                }
                                .frame(width: 22, height: 22)
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                }
                .shadow(color: isActive ? palette.accent.opacity(0.4) : .black.opacity(0.06),
                        radius: isActive ? 12 : 6, y: isActive ? 6 : 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sub.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.ink)
                        .tracking(-0.1)
                        .lineLimit(1)
                    if !sub.tags.isEmpty {
                        Text(sub.tags.prefix(2).joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundStyle(palette.ink3)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 4)
                .frame(width: tileWidth, alignment: .leading)
            }
        }
        .buttonStyle(.v3Pressable)
        .task(id: parentImage == nil ? sub.filePath : nil) {
            // Only hit disk when there's no in-memory parent image to crop from.
            guard parentImage == nil, let path = sub.filePath, !path.isEmpty else {
                fallbackThumb = nil
                return
            }
            if fallbackThumb == nil { fallbackThumb = V3Thumbnail.cached(path: path, maxPixelSize: 320) }
            fallbackThumb = await V3Thumbnail.load(path: path, maxPixelSize: 320)
        }
    }

    @ViewBuilder private var cropView: some View {
        if let img = parentImage, let rect = sub.rectangleOnParent,
           rect.width > 0, rect.height > 0 {
            GeometryReader { geo in
                let scaleX = CGFloat(1.0 / rect.width)
                let scaleY = CGFloat(1.0 / rect.height)
                // Use the larger scale so we cover the whole tile; the rect is
                // anchored at top-left and scaled up to fill.
                let fullWidth = geo.size.width * scaleX
                let fullHeight = geo.size.height * scaleY
                let offsetX = -CGFloat(rect.x) * fullWidth
                let offsetY = -CGFloat(rect.y) * fullHeight
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: fullWidth, height: fullHeight)
                    .offset(x: offsetX, y: offsetY)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                    .clipped()
            }
        } else if let img = fallbackThumb {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            palette.paperEdge
        }
    }
}
