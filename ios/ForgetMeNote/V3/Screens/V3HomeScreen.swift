import SwiftUI
import SwiftData

/// V3 Home — editorial-feel landing. Port of screens-home.jsx HomeScreen.
///
/// Layout (top to bottom):
///   - "GOOD EVENING" small caps + search bubble (top-right)
///   - "Hi {name}, *welcome back.*" big serif headline
///   - Stat row with flower mark: "17 places across 4 rooms"
///   - "Lately remembered" horizontal photo carousel
///   - "Your rooms" 2-col grid of colored RoomTiles + ghost "New room" tile
///   - Tip card
struct V3HomeScreen: View {
    let palette: V3Palette
    let name: String
    @Binding var path: NavigationPath
    /// Invoked by the header search button — the parent (V3RootView) switches
    /// to the Find tab. V3HomeScreen has no access to the tab binding itself.
    var onOpenSearch: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ImageItem.createdAt, order: .reverse) private var allItems: [ImageItem]
    @Query(filter: #Predicate<ImageItem> { $0.parentId == nil },
           sort: \ImageItem.createdAt) private var rootItems: [ImageItem]

    @State private var showNewRoom: Bool = false

    private var rooms: [ImageItem] { rootItems.filter { $0.isRoom } }
    private var recent: [ImageItem] {
        Array(allItems.filter { !$0.isRoom }.prefix(6))
    }
    private var totalPlaces: Int { allItems.count }

    /// id → item, built once so parent lookups are O(1) instead of an
    /// `allItems.first { … }` linear scan per recent card.
    private var byId: [String: ImageItem] {
        Dictionary(allItems.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }
    /// parentId → child file paths, built once so the room grid avoids an
    /// `allItems.filter { … }` linear scan per room tile.
    private var childPaths: [String: [String]] {
        var map: [String: [String]] = [:]
        for item in allItems {
            guard let pid = item.parentId, let path = item.filePath else { continue }
            map[pid, default: []].append(path)
        }
        return map
    }
    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 5 { return "still up?" }
        if h < 12 { return "morning" }
        if h < 18 { return "afternoon" }
        return "evening"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                if !recent.isEmpty {
                    sectionLabel("Lately remembered", action: nil)
                    recentCarousel
                        .padding(.bottom, 8)
                }
                sectionLabel("Your rooms", action: ("New room", { showNewRoom = true }))
                roomGrid
                tipCard
                Spacer(minLength: 110)  // tab bar clearance
            }
        }
        .background(paperBackground)
        .sheet(isPresented: $showNewRoom) {
            V3NewRoomSheet()
                .environment(\.v3Palette, palette)
        }
    }

    // MARK: - Header

    @ViewBuilder private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Good \(greeting)")
                    .v3SmallCaps(palette.ink3)
                Spacer()
                Button {
                    onOpenSearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.ink)
                        .frame(width: 38, height: 38)
                        .background(palette.surface, in: Circle())
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                        .frame(width: 44, height: 44)
                        .contentShape(SwiftUI.Rectangle())
                }
                .accessibilityLabel("Search")
                .accessibilityIdentifier("v3-home-search")
            }
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Hi \(name.split(separator: " ").first.map(String.init) ?? name),")
                        .font(V3Font.headline(34))
                        .foregroundStyle(palette.ink)
                        .tracking(-0.7)
                    Text("welcome back.")
                        .font(V3Font.headline(34, italic: true))
                        .italic()
                        .foregroundStyle(palette.accent)
                        .tracking(-0.7)
                }
                // Combine the two headline lines into one a11y node so Maestro
                // can assert the greeting by id (SwiftUI otherwise merges the
                // sibling Texts and substring `assertVisible` fails).
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("v3-home-greeting")
                Spacer()
            }
            .padding(.top, 4)

            HStack(spacing: 6) {
                FlowerMark(size: 13, color: palette.accent, pollen: palette.pollen)
                (Text("\(totalPlaces) places")
                    .foregroundStyle(palette.ink).fontWeight(.semibold) +
                 Text(" across ")
                    .foregroundStyle(palette.ink2) +
                 Text("\(rooms.count) \(rooms.count == 1 ? "room" : "rooms")")
                    .foregroundStyle(palette.ink).fontWeight(.semibold) +
                 Text("."))
                    .foregroundStyle(palette.ink2)
            }
            .font(.system(size: 13))
            .padding(.top, 12)
        }
        .padding(.horizontal, 22)
        .padding(.top, 64)
        .padding(.bottom, 28)
    }

    // MARK: - Recent carousel

    @ViewBuilder private var recentCarousel: some View {
        // Build the id lookup once for this render so each card resolves its
        // parent name in O(1) instead of scanning `allItems`.
        let lookup = byId
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(recent, id: \.id) { item in
                    Button {
                        if item.isRoom {
                            path.append(Route.v3Room(roomId: item.id))
                        } else {
                            path.append(Route.v3Space(spaceId: item.id))
                        }
                    } label: {
                        V3RecentCard(
                            item: item,
                            parentName: item.parentId.flatMap { lookup[$0]?.name },
                            palette: palette,
                            timeAgo: timeAgo(item.createdAt)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Room grid

    @ViewBuilder private var roomGrid: some View {
        // Build the parentId → child-paths map once; each room tile then reads
        // its previews in O(1) instead of filtering `allItems` per room.
        let paths = childPaths
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(rooms, id: \.id) { room in
                let previews = paths[room.id] ?? []
                V3RoomTile(
                    name: room.name,
                    hue: palette.hue(for: room),
                    previewImagePaths: Array(previews.prefix(3)),
                    onTap: { path.append(Route.v3Room(roomId: room.id)) }
                )
            }
            // Ghost "New room" tile
            Button { showNewRoom = true } label: {
                VStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .medium))
                    Text("New room")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(palette.ink3)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(palette.line, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("v3-home-new-room")
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Tip card

    @ViewBuilder private var tipCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 36, height: 36)
                .background(palette.accentBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("Tip · Quick capture")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.ink)
                Text("Tap the camera button anytime — we'll ask where it goes after.")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.ink2)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        .padding(.horizontal, 22)
        .padding(.top, 32)
    }

    // MARK: - Misc

    @ViewBuilder private var paperBackground: some View {
        ZStack {
            palette.paper
            LinearGradient(
                colors: [palette.surface.opacity(0.6), .clear],
                startPoint: .top, endPoint: .center
            )
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func sectionLabel(_ title: String, action: (String, () -> Void)?) -> some View {
        HStack {
            Text(title)
                .font(V3Font.headline(22))
                .foregroundStyle(palette.ink)
                .tracking(-0.3)
            Spacer()
            if let (label, handler) = action {
                Button(action: handler) {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
        .padding(.top, 8)
    }

    private func timeAgo(_ ms: Int64) -> String {
        let secs = (Date().timeIntervalSince1970 * 1000 - Double(ms)) / 1000
        if secs < 60 { return "just now" }
        let m = Int(secs / 60)
        if m < 60 { return "\(m)m ago" }
        let h = m / 60
        if h < 24 { return "\(h)h ago" }
        let d = h / 24
        return "\(d)d ago"
    }
}

// MARK: - Recent card

/// A single "Lately remembered" carousel card. Owns its own `@State` thumbnail
/// so the 168x210 image decodes ONCE off the main thread via `V3Thumbnail`
/// (was a synchronous full-resolution `UIImage(contentsOfFile:)` per render
/// pass). Keeps the serif-letter fallback when no thumbnail is available.
private struct V3RecentCard: View {
    let item: ImageItem
    let parentName: String?
    let palette: V3Palette
    let timeAgo: String

    @State private var thumb: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if let img = thumb {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 168, height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.paperEdge)
                        .frame(width: 168, height: 210)
                        .overlay(
                            Text(item.name.prefix(1).uppercased())
                                .font(V3Font.headline(64))
                                .foregroundStyle(palette.ink2)
                        )
                }
                if let parentName {
                    Text(parentName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(.ultraThinMaterial.opacity(0.85), in: Capsule())
                        .background(Color.black.opacity(0.4), in: Capsule())
                        .padding(10)
                }
                if item.isUpdated {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 11, weight: .bold))
                        Text("new")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: 0x3D2A0E))
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(palette.pollen, in: Capsule())
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                }
            }
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                Text(timeAgo)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.ink3)
            }
            .padding(.top, 10).padding(.horizontal, 4)
        }
        .frame(width: 168)
        .task(id: item.filePath) {
            // Seed synchronously from cache to avoid a flash, then load off-main.
            if let p = item.filePath, thumb == nil {
                thumb = V3Thumbnail.cached(path: p, maxPixelSize: 420)
            }
            thumb = await V3Thumbnail.load(path: item.filePath, maxPixelSize: 420)
        }
    }
}
