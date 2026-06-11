import SwiftUI

/// Horizontal, swipe-between-rooms carousel — the v3 take on the Android
/// `HorizontalPager`. Each page is the shared flattened node: a colored room
/// cover, or a space photo with its sub-space rectangles drawn on top. Adjacent
/// pages "peek" at the edges (symmetric content inset) and snap into place;
/// `scrollPosition(id:)` two-way-binds to `selectedId` so swiping updates the
/// selection and selecting elsewhere (the tree) scrolls the carousel here.
struct V3SpaceCarousel: View {
    let palette: V3Palette
    let nodes: [V3TreeNode]
    @Binding var selectedId: String?
    /// parentId → normalized rects of its positioned sub-spaces (drawn on the
    /// photo card so you can see "what's inside" before opening).
    let rectsByParent: [String: [Rectangle]]
    let childCounts: [String: Int]
    /// id → the photo slice this item displays (own photo or cropped region).
    let regions: [String: V3Region]
    var onOpen: (ImageItem) -> Void
    var onToggleExpand: (String) -> Void
    /// Quick delete straight from the card — long-press any card, or tap the
    /// trash button shown on the selected card. The parent screen owns the
    /// confirmation + actual repository delete. nil hides both affordances.
    var onDelete: ((ImageItem) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let dotsH: CGFloat = 26
            let cardH = max(140, geo.size.height - dotsH)
            // Portrait-ish card, but never wider than ~80% so neighbors peek.
            let cardW = min(geo.size.width * 0.8, cardH * 0.82)
            let sidePad = max(12, (geo.size.width - cardW) / 2)

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(nodes) { node in
                            V3CarouselCard(
                                palette: palette,
                                node: node,
                                region: regions[node.item.id],
                                rects: rectsByParent[node.item.id] ?? [],
                                childCount: childCounts[node.item.id] ?? 0,
                                isSelected: node.item.id == selectedId,
                                onTap: {
                                    if node.item.v3HasRegion {
                                        onOpen(node.item)
                                    } else {
                                        // Plain room/box — reveal its contents.
                                        V3Haptics.selection()
                                        onToggleExpand(node.item.id)
                                    }
                                },
                                onDelete: onDelete
                            )
                            .frame(width: cardW, height: cardH)
                            .id(node.item.id)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                    .opacity(phase.isIdentity ? 1 : 0.6)
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, sidePad)
                    .frame(height: cardH)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $selectedId, anchor: .center)
                .scrollIndicators(.hidden)
                .onAppear {
                    // The initial `scrollPosition` value is applied before the
                    // GeometryReader-derived card width settles, so opening on
                    // a non-first node (e.g. arriving from search) can leave
                    // the first card centered. Re-apply one runloop later.
                    guard let target = selectedId else { return }
                    DispatchQueue.main.async {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
                }

                dots
                    .frame(height: dotsH)
            }
        }
    }

    @ViewBuilder private var dots: some View {
        let count = nodes.count
        let index = nodes.firstIndex { $0.item.id == selectedId } ?? 0
        if count > 1 {
            if count <= 12 {
                HStack(spacing: 6) {
                    ForEach(0..<count, id: \.self) { i in
                        Circle()
                            .fill(i == index ? palette.accent : palette.ink3.opacity(0.3))
                            .frame(width: i == index ? 8 : 6, height: i == index ? 8 : 6)
                    }
                }
            } else {
                Text("\(index + 1) / \(count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.ink3)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(palette.paperEdge, in: Capsule())
            }
        }
    }
}

/// A single carousel page. Owns its own off-main thumbnail so swiping never
/// decodes a full-res JPEG on the main thread.
private struct V3CarouselCard: View {
    let palette: V3Palette
    let node: V3TreeNode
    let region: V3Region?
    let rects: [Rectangle]
    let childCount: Int
    let isSelected: Bool
    var onTap: () -> Void
    var onDelete: ((ImageItem) -> Void)? = nil

    @State private var thumb: UIImage?

    private var item: ImageItem { node.item }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                cardSurface
                caption
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(isSelected ? palette.accent.opacity(0.9) : Color.black.opacity(0.06),
                            lineWidth: isSelected ? 2.5 : 1)
            )
            .shadow(color: .black.opacity(isSelected ? 0.16 : 0.08),
                    radius: isSelected ? 16 : 8, y: isSelected ? 8 : 4)
        }
        .buttonStyle(.v3Pressable)
        .accessibilityIdentifier("v3-carousel-card-\(item.id)")
        .contextMenu {
            Button {
                onTap()
            } label: { Label("Open", systemImage: "arrow.up.right") }
            if let onDelete {
                Button(role: .destructive) {
                    onDelete(item)
                } label: { Label("Delete", systemImage: "trash") }
            }
        }
        .overlay(alignment: .topTrailing) {
            // One-tap delete on the selected card — the "tap the icon to
            // delete" affordance. Long-press still works on every card.
            if isSelected, let onDelete {
                Button {
                    V3Haptics.impact(.light)
                    onDelete(item)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.danger)
                        .frame(width: 32, height: 32)
                        .background(.regularMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                        .frame(width: 44, height: 44)
                        .contentShape(SwiftUI.Rectangle())
                }
                .buttonStyle(.plain)
                .padding(6)
                .accessibilityLabel("Delete \(item.name)")
                .accessibilityIdentifier("v3-card-delete-\(item.id)")
            }
        }
        .task(id: region) {
            guard let region else { thumb = nil; return }
            if thumb == nil { thumb = V3RegionImage.cached(region, maxPixelSize: 700) }
            thumb = await V3RegionImage.load(region, maxPixelSize: 700)
        }
    }

    @ViewBuilder private var cardSurface: some View {
        if region == nil {
            roomCover
        } else if let img = thumb {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                    rectOverlay(in: geo.size)
                }
            }
        } else {
            placeholderCover
        }
    }

    private var roomCover: some View {
        let hue = palette.hue(for: item)
        return ZStack {
            hue.bg
            GeometryReader { geo in
                Circle()
                    .fill(hue.fg.opacity(0.08))
                    .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                    .offset(x: geo.size.width * 0.45, y: -geo.size.width * 0.2)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Room")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(hue.fg.opacity(0.75))
                Text(String(item.name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                    .font(V3Font.headline(96))
                    .foregroundStyle(hue.fg)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(childCount == 0 ? "Tap to add places"
                         : "Tap to reveal \(childCount) \(childCount == 1 ? "place" : "places")")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(hue.fg.opacity(0.85))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(22)
        }
    }

    private var placeholderCover: some View {
        ZStack {
            palette.paperEdge
            Text(String(item.name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                .font(V3Font.headline(96))
                .foregroundStyle(palette.ink2)
        }
    }

    @ViewBuilder private func rectOverlay(in size: CGSize) -> some View {
        ForEach(Array(rects.enumerated()), id: \.offset) { idx, r in
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: 0x5B7FE0).opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.white, lineWidth: 1.5)
                )
                .frame(width: CGFloat(r.width) * size.width,
                       height: CGFloat(r.height) * size.height)
                .overlay(alignment: .topLeading) {
                    Text("\(idx + 1)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(palette.ink)
                        .frame(width: 18, height: 18)
                        .background(.white, in: Circle())
                        .offset(x: -7, y: -7)
                }
                .offset(x: CGFloat(r.x) * size.width, y: CGFloat(r.y) * size.height)
        }
        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
    }

    @ViewBuilder private var caption: some View {
        if region != nil {
            HStack(spacing: 6) {
                Text(item.name.isEmpty ? "Untitled" : item.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if childCount > 0 {
                    Text("· \(childCount)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom)
            )
        }
    }
}
