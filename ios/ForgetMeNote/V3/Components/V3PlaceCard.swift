import SwiftUI

/// Format a millisecond epoch timestamp as a short relative string.
/// "just now", "5m ago", "3h ago", "2d ago", "1w ago", "4mo ago", "2y ago".
func v3TimeAgo(_ ms: Int64) -> String {
    let seconds = (Int64(Date().timeIntervalSince1970 * 1000) - ms) / 1000
    if seconds < 60 { return "just now" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m ago" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h ago" }
    let days = hours / 24
    if days < 7 { return "\(days)d ago" }
    let weeks = days / 7
    if weeks < 4 { return "\(weeks)w ago" }
    let months = days / 30
    if months < 12 { return "\(months)mo ago" }
    return "\(days / 365)y ago"
}

/// Load a UIImage from the absolute path stored on `ImageItem.filePath`.
/// Returns nil for rooms or when the file is missing.
func v3LoadImage(filePath: String?) -> UIImage? {
    guard let filePath, !filePath.isEmpty else { return nil }
    return UIImage(contentsOfFile: filePath)
}

/// V3 place card — square image card with name + time ago footer.
/// Renders updated-badge top-right and child-count bottom-left when relevant.
/// Port of `PlaceCard` from screens-space.jsx.
struct V3PlaceCard: View {
    let palette: V3Palette
    let item: ImageItem
    let childCount: Int
    var onTap: () -> Void = {}

    /// Downsampled thumbnail filled off-main in `.task`; nil shows the fallback.
    @State private var thumb: UIImage?

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    imageOrFallback
                    if item.isUpdated {
                        updatedBadge
                            .padding(8)
                    }
                    if childCount > 0 {
                        VStack {
                            Spacer()
                            HStack {
                                childCountBadge
                                Spacer()
                            }
                        }
                        .padding(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.ink)
                        .tracking(-0.15)
                        .lineLimit(1)
                    Text(v3TimeAgo(item.createdAt))
                        .font(.system(size: 11))
                        .foregroundStyle(palette.ink3)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
        .buttonStyle(.v3Pressable)
        .task(id: item.filePath) {
            // Seed synchronously from cache to avoid a flash, then load off-main.
            if let path = item.filePath, !path.isEmpty {
                if thumb == nil { thumb = V3Thumbnail.cached(path: path, maxPixelSize: 320) }
                thumb = await V3Thumbnail.load(path: path, maxPixelSize: 320)
            } else {
                thumb = nil
            }
        }
    }

    @ViewBuilder private var imageOrFallback: some View {
        if let img = thumb {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                palette.paperEdge
                Text(item.name.trimmingCharacters(in: .whitespaces).prefix(1).uppercased())
                    .font(V3Font.headline(56))
                    .foregroundStyle(palette.ink2)
            }
        }
    }

    @ViewBuilder private var updatedBadge: some View {
        ZStack {
            Circle().fill(palette.pollen)
            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: 0x3D2A0E))
        }
        .frame(width: 24, height: 24)
        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }

    @ViewBuilder private var childCountBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 9, weight: .bold))
            Text("\(childCount)")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color(white: 0.08).opacity(0.55), in: Capsule())
    }
}
