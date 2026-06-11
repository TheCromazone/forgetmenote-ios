import SwiftUI

/// V3 room tile — square colored card with a large serif initial, a faint
/// circular accent in the corner, room name + count footer.
struct V3RoomTile: View {
    let name: String
    let hue: V3Hue
    var size: TileSize = .md
    var previewImagePaths: [String] = []
    var onTap: () -> Void = {}

    /// Up-to-3 downsampled avatar thumbnails, filled off-main in `.task`.
    @State private var previewThumbs: [UIImage] = []

    enum TileSize { case sm, md, lg
        var padding: CGFloat { self == .sm ? 12 : self == .md ? 16 : 24 }
        var fontSize: CGFloat { self == .sm ? 28 : self == .md ? 44 : 64 }
        var corner: CGFloat { self == .sm ? 16 : self == .md ? 22 : 28 }
    }

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                hue.bg
                // Soft corner circle accent.
                GeometryReader { geo in
                    Circle()
                        .fill(hue.fg.opacity(0.08))
                        .frame(width: geo.size.width * 0.8, height: geo.size.width * 0.8)
                        .offset(x: geo.size.width * 0.5, y: -geo.size.width * 0.25)
                }
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Text(initial)
                            .font(V3Font.headline(size.fontSize))
                            .foregroundStyle(hue.fg)
                            .tracking(-0.02 * size.fontSize)
                        Spacer()
                        if !previewImagePaths.isEmpty {
                            previewStack
                        }
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(hue.fg)
                            .tracking(-0.15)
                            .lineLimit(1)
                    }
                }
                .padding(size.padding)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: size.corner, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(.v3Pressable)
        .task(id: previewImagePaths) {
            let paths = Array(previewImagePaths.prefix(3))
            // Seed synchronously from cache to avoid a flash, then load off-main.
            let seeded = paths.compactMap { V3Thumbnail.cached(path: $0, maxPixelSize: 120) }
            if previewThumbs.isEmpty && !seeded.isEmpty { previewThumbs = seeded }
            var loaded: [UIImage] = []
            for path in paths {
                if let img = await V3Thumbnail.load(path: path, maxPixelSize: 120) {
                    loaded.append(img)
                }
            }
            previewThumbs = loaded
        }
    }

    @ViewBuilder private var previewStack: some View {
        HStack(spacing: -10) {
            ForEach(Array(previewThumbs.enumerated()), id: \.offset) { _, img in
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(hue.bg, lineWidth: 2)
                    )
            }
        }
    }
}
