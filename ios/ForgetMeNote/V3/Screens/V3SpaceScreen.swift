import SwiftUI
import SwiftData

/// V3 Space screen — the photo for a single ImageItem with overlaid
/// rectangles for each positioned sub-space. Port of `SpaceScreen` from
/// screens-space.jsx.
struct V3SpaceScreen: View {
    let spaceId: String
    @Binding var path: NavigationPath

    @Environment(\.v3Palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var matches: [ImageItem]
    @Query private var allItems: [ImageItem]

    @State private var activeSubId: String? = nil
    @State private var viewMode: SubViewMode = .photo
    @State private var showDetail: Bool = false
    @State private var showGeminiSetup: Bool = false
    /// Mirrors the saved Gemini key so the "better scans" setup link
    /// disappears reactively the moment a key is verified.
    @AppStorage("v3_gemini_api_key") private var geminiKey: String = ""

    // In-image tools (Android-style): full-screen zoom + draw-a-spot.
    @State private var showZoom: Bool = false
    @State private var drawMode: Bool = false
    @State private var drawRect: Rectangle = Rectangle(x: 0.3, y: 0.3, width: 0.4, height: 0.35)
    /// Draw-a-spot offers BOTH shapes from the start: a corner-handle box or a
    /// freehand trace (same pair as CreateSub's mark modes).
    enum DrawTool { case box, trace }
    @State private var drawTool: DrawTool = .box
    @State private var drawTrace = TracePath(points: [])

    // Hero image decoded once, off-main, downsampled. Shared by the hero photo
    // AND every V3SubScanCard so sub-cards never decode the full-res JPEG (the
    // old computed `image` was an N+1 synchronous full-res decode per body pass).
    @State private var heroImage: UIImage? = nil

    // On-device object detection (V3VisionService).
    @State private var detections: [DetectedObjectInfo] = []
    @State private var isDetecting: Bool = false
    @State private var selectedDetectionId: UUID? = nil
    @State private var detectionMessage: String? = nil
    @State private var identifyLabel: String? = nil
    @State private var identifyPoint: CGPoint = .zero      // normalized 0..1
    @State private var identifyToken: Int = 0
    @State private var detectToken: Int = 0

    enum SubViewMode { case photo, grid }

    init(spaceId: String, path: Binding<NavigationPath>) {
        self.spaceId = spaceId
        self._path = path
        let id = spaceId
        self._matches = Query(filter: #Predicate<ImageItem> { $0.id == id })
        self._allItems = Query(sort: \ImageItem.createdAt)
    }

    private var item: ImageItem? { matches.first }

    /// O(1) id → item lookup built once per render (replaces per-hop
    /// `allItems.first(where:)` scans in `ancestry`).
    private var byId: [String: ImageItem] {
        Dictionary(allItems.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// The photo slice this item shows — own photo, or the cropped region of an
    /// ancestor photo (a traced shelf / object). Drives the hero + tracing.
    private var heroRegion: V3Region? {
        item.flatMap { V3RegionResolver.region(for: $0, byId: byId) }
    }

    /// O(1) parentId → child count built once per render (replaces per-card
    /// `allItems.filter { $0.parentId == … }` scans in the grid).
    private var childCounts: [String: Int] {
        Dictionary(grouping: allItems, by: \.parentId)
            .reduce(into: [String: Int]()) { acc, pair in
                if let key = pair.key { acc[key] = pair.value.count }
            }
    }

    /// All children that have a rectangle anchored on this image.
    private var subs: [ImageItem] {
        allItems.filter { $0.parentId == spaceId && $0.rectangleOnParent != nil }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Ancestors from root → self. The crumbs (everything except self) form
    /// the subtitle path.
    private var ancestry: [ImageItem] {
        guard let item else { return [] }
        let lookup = byId
        var chain: [ImageItem] = [item]
        var cur: ImageItem? = item
        while let c = cur, let pid = c.parentId,
              let parent = lookup[pid] {
            chain.insert(parent, at: 0)
            cur = parent
        }
        return chain
    }

    private var subtitle: String? {
        let crumbs = ancestry.dropLast()
        if crumbs.isEmpty { return nil }
        return crumbs.map(\.name).joined(separator: " › ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let item {
                    V3NavHeader(
                        palette: palette,
                        title: item.name,
                        subtitle: subtitle,
                        onBack: { if !path.isEmpty { path.removeLast() } else { dismiss() } }
                    ) {
                        Button {
                            showDetail = true
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(palette.ink)
                                .frame(width: 38, height: 38)
                                .background(palette.surface, in: Circle())
                                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                                .frame(width: 44, height: 44)
                                .contentShape(SwiftUI.Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("More options")
                        .accessibilityIdentifier("v3-space-menu")
                    }

                    heroPhoto(item: item)
                        .padding(.horizontal, 16)

                    inImageTools(item: item)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    if !drawMode {
                        detectionBar(item: item)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                    }

                    metaRow(item: item)

                    subsSection(item: item)

                    Spacer(minLength: 110)
                } else {
                    // Item was deleted out from under us (or the id is stale).
                    // Never a dead end: give a working back affordance.
                    V3NavHeader(
                        palette: palette,
                        title: "Not found",
                        onBack: { if !path.isEmpty { path.removeLast() } else { dismiss() } }
                    )
                    V3EmptyState(palette: palette, kind: .generic)
                        .padding(.horizontal, 22)
                        .padding(.top, 40)
                }
            }
        }
        .scrollDisabled(drawMode)   // let the crop box own the drags while drawing
        .background(palette.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showZoom) {
            if let img = heroImage {
                V3ZoomableImageOverlay(image: img, title: item?.name, onClose: { showZoom = false })
            }
        }
        .task(id: heroRegion) {
            // The hero is the item's RESOLVED region: its own photo, or the
            // cropped slice of the nearest ancestor photo (so a traced shelf or
            // object shows the right picture and can be traced into recursively).
            guard let region = heroRegion else { heroImage = nil; return }
            if heroImage == nil { heroImage = V3RegionImage.cached(region, maxPixelSize: 1600) }
            let img = await V3RegionImage.load(region, maxPixelSize: 1600)
            guard !Task.isCancelled else { return }
            heroImage = img
        }
        .onChange(of: matches.isEmpty) { _, isEmpty in
            // Self-heal: if this space's model row vanished (deleted) while its
            // detail screen is still on the stack, pop back to the parent.
            if isEmpty && !path.isEmpty { path.removeLast() }
        }
        .sheet(isPresented: $showDetail) {
            V3DetailSheet(itemId: spaceId, onDeleted: {
                if !path.isEmpty { path.removeLast() } else { dismiss() }
            })
            .environment(\.v3Palette, palette)
        }
    }

    // MARK: - Hero photo + rect overlays

    @ViewBuilder private func heroPhoto(item: ImageItem) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if let img = heroImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    palette.paperEdge
                    Text(item.name.trimmingCharacters(in: .whitespaces).prefix(1).uppercased())
                        .font(V3Font.headline(120))
                        .foregroundStyle(palette.ink2)
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                // Sub-space rectangles
                ForEach(Array(subs.enumerated()), id: \.element.id) { idx, sub in
                    if let rect = sub.rectangleOnParent {
                        let isActive = activeSubId == sub.id
                        let x = CGFloat(rect.x) * geo.size.width
                        let y = CGFloat(rect.y) * geo.size.height
                        let w = CGFloat(rect.width) * geo.size.width
                        let h = CGFloat(rect.height) * geo.size.height

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isActive
                                      ? palette.accent.opacity(0.2)
                                      : Color(hex: 0x5B7FE0).opacity(0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(isActive ? palette.accent : .white,
                                                lineWidth: 2)
                                )
                                .frame(width: w, height: h)
                                .shadow(color: isActive
                                        ? palette.accent.opacity(0.35)
                                        : .black.opacity(0.25),
                                        radius: isActive ? 12 : 4, y: isActive ? 6 : 2)

                            // Number badge
                            Text("\(idx + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(isActive ? .white : palette.ink)
                                .frame(width: 24, height: 24)
                                .background(isActive ? palette.accent : .white, in: Circle())
                                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                                .offset(x: -10, y: -10)

                            // Active label badge below
                            if isActive {
                                VStack(spacing: 0) {
                                    Spacer().frame(height: h + 6)
                                    HStack(spacing: 3) {
                                        Text(sub.name)
                                        Text("→")
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .tracking(-0.1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(palette.accent, in: Capsule())
                                    .shadow(color: palette.accent.opacity(0.4), radius: 6, y: 3)
                                }
                                .frame(width: max(w, 120), alignment: .center)
                            }
                        }
                        .offset(x: x, y: y)
                        .allowsHitTesting(!drawMode)   // crop box owns the photo while drawing
                        .onTapGesture {
                            if isActive {
                                openSub(sub)
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    activeSubId = sub.id
                                }
                            }
                        }
                        .accessibilityIdentifier("v3-space-rect-\(sub.id)")
                    }
                }

                // AI detection overlay (transient — not persisted).
                if !detections.isEmpty {
                    V3DetectionOverlay(
                        palette: palette,
                        detections: detections,
                        size: geo.size,
                        selectedId: selectedDetectionId,
                        onSelect: { id in
                            let willSelect = selectedDetectionId != id
                            if willSelect { V3Haptics.impact(.light) }
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedDetectionId = willSelect ? id : nil
                            }
                        }
                    )
                }

                // Scanning shimmer while detection runs.
                if isDetecting {
                    ZStack {
                        Color.black.opacity(0.28)
                        VStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)
                            Text("Finding objects…")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .allowsHitTesting(false)
                }

                // Tap hint when no active sub
                if !subs.isEmpty && activeSubId == nil {
                    VStack {
                        Spacer()
                        Text("Tap a spot to peek inside ✦")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .tracking(-0.1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(white: 0.08).opacity(0.55), in: Capsule())
                            .padding(.bottom, 12)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .allowsHitTesting(false)
                }

                // Updated badge
                if item.isUpdated {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 11, weight: .bold))
                        Text("refreshed")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: 0x3D2A0E))
                    .tracking(-0.1)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(palette.pollen, in: Capsule())
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    .padding(14)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topTrailing)
                    .allowsHitTesting(false)
                }

                // Draw-a-spot overlay — a corner-handle box OR a freehand
                // trace, picked by the toggle in the tools bar. Owns the
                // drags; the surrounding ScrollView is disabled while active.
                if drawMode {
                    if drawTool == .box {
                        V3CropBox(palette: palette, rect: $drawRect, size: geo.size)
                    } else {
                        V3TraceBox(palette: palette, trace: $drawTrace, size: geo.size)
                    }
                }

                // Tap-to-identify translucent label.
                if let label = identifyLabel {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(palette.accent.opacity(0.82), in: Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                        .position(x: identifyPoint.x * geo.size.width,
                                  y: max(18, identifyPoint.y * geo.size.height))
                        .transition(.opacity.combined(with: .scale))
                        .allowsHitTesting(false)
                }
            }
            .background(palette.paperEdge)
            .simultaneousGesture(
                SpatialTapGesture().onEnded { value in
                    let p = CGPoint(x: value.location.x / geo.size.width,
                                    y: value.location.y / geo.size.height)
                    identifyAt(point: p)
                }
            )
        }
        .aspectRatio(heroAspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 16, y: 6)
    }

    /// The hero frame matches the photo's REAL aspect ratio so the full
    /// picture (especially a traced/cropped sub-space slice) is visible
    /// without opening Zoom — and, since the image then fills the frame with
    /// no crop, the normalized sub-rect overlays align exactly. Clamped so a
    /// degenerate sliver can't collapse the layout.
    private var heroAspect: CGFloat {
        guard let img = heroImage, img.size.width > 0, img.size.height > 0 else {
            return 4.0 / 5.0
        }
        return min(max(img.size.width / img.size.height, 0.45), 2.4)
    }

    // MARK: - Tags + notes

    @ViewBuilder private func metaRow(item: ImageItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !item.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(item.tags, id: \.self) { tag in
                        V3Chip(palette: palette, text: tag)
                    }
                }
            }
            if !item.notes.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "note.text")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .frame(width: 28, height: 28)
                        .background(palette.accentBg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Text(item.notes)
                        .font(.system(size: 14))
                        .foregroundStyle(palette.ink)
                        .tracking(-0.1)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Subs section

    @ViewBuilder private func subsSection(item: ImageItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                (Text("What's inside ")
                    .font(V3Font.headline(22))
                    .foregroundStyle(palette.ink) +
                 Text("· ")
                    .font(V3Font.headline(22, italic: true))
                    .italic()
                    .foregroundStyle(palette.accent) +
                 Text("\(subs.count)")
                    .font(V3Font.headline(22))
                    .foregroundStyle(palette.ink))
                    .tracking(-0.2)

                Spacer()
                viewModeSwitcher
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 12)

            if subs.isEmpty {
                V3EmptyState(palette: palette, kind: .subs) {
                    addSubAction()
                }
                .padding(.horizontal, 22)
            } else if viewMode == .photo {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(subs.enumerated()), id: \.element.id) { idx, sub in
                            V3SubScanCard(
                                palette: palette,
                                sub: sub,
                                parentImage: heroImage,
                                index: idx + 1,
                                isActive: activeSubId == sub.id,
                                onTap: {
                                    if activeSubId == sub.id {
                                        openSub(sub)
                                    } else {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            activeSubId = sub.id
                                        }
                                    }
                                }
                            )
                            .accessibilityIdentifier("v3-space-sub-\(sub.id)")
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 8)
                }
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10),
                              GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    let counts = childCounts
                    ForEach(subs, id: \.id) { sub in
                        V3PlaceCard(
                            palette: palette,
                            item: sub,
                            childCount: counts[sub.id] ?? 0,
                            onTap: { openSub(sub) }
                        )
                        .accessibilityIdentifier("v3-space-sub-\(sub.id)")
                    }
                }
                .padding(.horizontal, 22)
            }

            if !subs.isEmpty {
                Button(action: addSubAction) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                        Text("Add another spot")
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(-0.1)
                    }
                    .foregroundStyle(palette.ink2)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(palette.line, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .accessibilityIdentifier("v3-space-add-sub")
            }
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var viewModeSwitcher: some View {
        HStack(spacing: 4) {
            switcherButton(systemName: "eye.fill", isOn: viewMode == .photo) {
                if viewMode != .photo { V3Haptics.selection() }
                viewMode = .photo
            }
            switcherButton(systemName: "square.grid.2x2.fill", isOn: viewMode == .grid) {
                if viewMode != .grid { V3Haptics.selection() }
                viewMode = .grid
            }
        }
        .padding(3)
        .background(palette.paperEdge, in: Capsule())
    }

    private func switcherButton(systemName: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn ? palette.ink : palette.ink3)
                .frame(width: 32, height: 28)
                .background(isOn ? palette.surface : Color.clear, in: Capsule())
                .shadow(color: isOn ? .black.opacity(0.08) : .clear, radius: 1, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    /// Android-style row of things you can do to the photo itself.
    @ViewBuilder private func inImageTools(item: ImageItem) -> some View {
        if drawMode {
            let traceTooShort = drawTool == .trace && drawTrace.points.count < 3
            VStack(spacing: 8) {
                // Shape picker — both tools available from the start.
                HStack(spacing: 4) {
                    drawToolButton(.box, icon: "rectangle.dashed", label: "Box")
                    drawToolButton(.trace, icon: "scribble.variable", label: "Trace")
                }
                .padding(3)
                .background(palette.paperEdge, in: Capsule())

                HStack(spacing: 10) {
                    Button(action: confirmDrawnSpot) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Add this spot ✦")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.v3Pressable)
                    .disabled(traceTooShort)
                    .opacity(traceTooShort ? 0.45 : 1)
                    .accessibilityIdentifier("v3-space-draw-confirm")

                    Button { withAnimation(.easeOut(duration: 0.2)) { drawMode = false } } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.ink2)
                            .frame(width: 46, height: 46)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("v3-space-draw-cancel")
                }

                Text(drawTool == .box
                     ? "Drag a corner to resize · drag inside to move"
                     : "Drag your finger around the object to trace its shape")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.ink3)
                    .multilineTextAlignment(.center)
            }
        } else if heroImage != nil {
            HStack(spacing: 8) {
                toolButton(icon: "plus.magnifyingglass", label: "Zoom",
                           id: "v3-space-zoom") {
                    if heroImage != nil { V3Haptics.impact(.light); showZoom = true }
                }
                toolButton(icon: "plus.viewfinder", label: "Draw a spot",
                           id: "v3-space-draw") {
                    V3Haptics.impact(.medium)
                    // A leftover AI scan would sit behind the crop/trace tool —
                    // clear it so drawing starts on a clean photo.
                    clearDetections()
                    drawRect = Rectangle(x: 0.3, y: 0.3, width: 0.4, height: 0.35)
                    drawTrace = TracePath(points: [])
                    withAnimation(.easeOut(duration: 0.2)) { drawMode = true }
                }
            }
        }
    }

    private func toolButton(icon: String, label: String, id: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.1)
            }
            .foregroundStyle(palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(.v3Pressable)
        .accessibilityIdentifier(id)
    }

    private func drawToolButton(_ tool: DrawTool, icon: String, label: String) -> some View {
        Button {
            if drawTool != tool { V3Haptics.selection() }
            withAnimation(.easeOut(duration: 0.15)) { drawTool = tool }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(drawTool == tool ? palette.ink : palette.ink3)
            .padding(.horizontal, 14).frame(height: 32)
            .background(drawTool == tool ? palette.surface : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("v3-space-draw-mode-\(label.lowercased())")
    }

    private func confirmDrawnSpot() {
        let box: Rectangle
        if drawTool == .trace, drawTrace.points.count >= 3 {
            // Hand the freehand outline to CreateSub (the route can't carry
            // it); its bounding box feeds the normal nesting pipeline.
            V3PendingTrace.stash(drawTrace)
            box = drawTrace.boundingBox
        } else {
            box = drawRect
        }
        V3Haptics.success()
        drawMode = false
        path.append(Route.v3CreateSub(parentId: spaceId, tempPhotoPath: nil,
                                      suggestedRect: box, suggestedTitle: nil))
    }

    @ViewBuilder private func detectionBar(item: ImageItem) -> some View {
        VStack(spacing: 10) {
            if let id = selectedDetectionId,
               let det = detections.first(where: { $0.id == id }) {
                // A detection is selected → offer to turn it into a sub-space.
                HStack(spacing: 10) {
                    Button(action: confirmSelectedDetection) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add “\(det.label)” ✦")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("v3-space-add-detection")

                    Button(action: clearDetections) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.ink2)
                            .frame(width: 46, height: 46)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("v3-space-clear-detection")
                }
            } else {
                // No selection → the detect trigger (or a re-run while results
                // show), plus a dismiss so a bad scan can simply be cleared
                // instead of re-scanning in hopes of a better result.
                HStack(spacing: 10) {
                    Button(action: runDetection) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                            Text(detections.isEmpty ? "Find objects" : "Scan again")
                                .font(.system(size: 14, weight: .semibold))
                                .tracking(-0.1)
                        }
                        .foregroundStyle(palette.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(palette.accentBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDetecting || item.filePath == nil)
                    .opacity(item.filePath == nil ? 0.4 : 1)
                    .accessibilityIdentifier("v3-space-detect")

                    if !detections.isEmpty {
                        Button(action: clearDetections) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(palette.ink2)
                                .frame(width: 46, height: 46)
                                .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Hide scan results")
                        .accessibilityIdentifier("v3-space-clear-scan")
                    }
                }
            }

            if let msg = detectionMessage {
                Text(msg)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.ink3)
            }

            // No key yet → offer the guided free-AI setup (the on-device scan
            // above keeps working either way).
            if geminiKey.trimmingCharacters(in: .whitespaces).isEmpty,
               !isDetecting, item.filePath != nil {
                Button {
                    V3Haptics.impact(.light)
                    showGeminiSetup = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11, weight: .bold))
                        Text("Want better scans? Set up free AI ✦")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(palette.accent)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("v3-space-enhance-setup")
            }
        }
        .sheet(isPresented: $showGeminiSetup) {
            V3GeminiKeySheet().environment(\.v3Palette, palette)
        }
    }

    private func runDetection() {
        guard let path = item?.filePath else { return }
        detectToken += 1
        let token = detectToken
        isDetecting = true
        detectionMessage = nil
        selectedDetectionId = nil
        Task {
            // Prefer the Gemini enhanced scan when a key is configured; fall
            // back to the on-device pipeline when it's missing, offline, or
            // errors — and SAY why, so a cloud failure is never mistaken for
            // "Gemini doesn't help".
            var results: [DetectedObjectInfo] = []
            var usedGemini = false
            var cloudProblem: String? = nil
            if V3GeminiVision.isConfigured {
                do {
                    let cloud = try await V3GeminiVision.detect(imagePath: path)
                    if cloud.isEmpty {
                        cloudProblem = "Gemini found nothing — used on-device scan"
                    } else {
                        results = cloud
                        usedGemini = true
                    }
                } catch {
                    let reason = (error as? V3GeminiVision.GeminiError)?
                        .errorDescription ?? "error"
                    cloudProblem = "Enhanced scan unavailable (\(reason)) — used on-device scan"
                }
            }
            if results.isEmpty {
                results = await V3VisionService.detect(imagePath: path)
            }
            await MainActor.run {
                // Bail if a newer detection run superseded this one.
                guard token == detectToken else { return }
                withAnimation(.easeOut(duration: 0.35)) {
                    detections = results
                    isDetecting = false
                    if results.isEmpty {
                        detectionMessage = "No objects found — add one by hand."
                    } else if usedGemini {
                        detectionMessage = "Enhanced scan ✦ Gemini"
                    } else {
                        detectionMessage = cloudProblem
                    }
                }
            }
        }
    }

    private func confirmSelectedDetection() {
        guard let id = selectedDetectionId,
              let det = detections.first(where: { $0.id == id }) else { return }
        let box = det.boundingBox
        let label = det.label
        clearDetections()
        path.append(Route.v3CreateSub(parentId: spaceId, tempPhotoPath: nil,
                                      suggestedRect: box, suggestedTitle: label))
    }

    private func clearDetections() {
        withAnimation(.easeOut(duration: 0.2)) {
            detections = []
            selectedDetectionId = nil
            detectionMessage = nil
        }
    }

    private func identifyAt(point: CGPoint) {
        // While drawing a spot the photo belongs to the crop box, not identify.
        guard !drawMode else { return }
        // Prefer an existing detection box under the tap.
        if let hit = detections.first(where: {
            let b = $0.boundingBox
            return point.x >= CGFloat(b.x) && point.x <= CGFloat(b.x + b.width)
                && point.y >= CGFloat(b.y) && point.y <= CGFloat(b.y + b.height)
        }) {
            showIdentify(hit.label, at: point); return
        }
        guard let path = item?.filePath else { return }
        identifyToken += 1
        let token = identifyToken
        Task {
            let label = await V3VisionService.classifyRegion(imagePath: path, around: point)
            await MainActor.run {
                guard token == identifyToken else { return }
                showIdentify(label ?? "Not sure", at: point)
            }
        }
    }

    private func showIdentify(_ label: String, at point: CGPoint) {
        identifyToken += 1
        let token = identifyToken
        withAnimation(.easeOut(duration: 0.2)) {
            identifyLabel = label
            identifyPoint = point
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                guard token == identifyToken else { return }
                withAnimation(.easeOut(duration: 0.3)) { identifyLabel = nil }
            }
        }
    }

    private func openSub(_ sub: ImageItem) {
        if sub.v3HasRegion {
            // A traced/cropped/photo sub → open its detail so you can trace deeper.
            path.append(Route.v3Space(spaceId: sub.id))
        } else {
            path.append(Route.v3Room(roomId: sub.id))
        }
    }

    private func addSubAction() {
        path.append(Route.v3CreateSub(parentId: spaceId, tempPhotoPath: nil,
                                      suggestedRect: nil, suggestedTitle: nil))
    }
}

// MARK: - Simple FlowLayout for tag chips

/// Minimal wrap-around layout used for chip clouds. SwiftUI's `Layout`
/// protocol (iOS 16+) makes this straightforward.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth && rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowHeight = 0
                rowWidth = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
