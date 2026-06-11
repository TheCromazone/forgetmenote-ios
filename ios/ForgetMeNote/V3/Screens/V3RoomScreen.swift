import SwiftUI
import SwiftData

/// V3 browse screen — the Android-style two-pane experience: a horizontal
/// carousel you swipe left/right between rooms (and their photo spaces) on top,
/// and a top-to-bottom indented hierarchy of everything below. The two panes
/// share one flattened node list and one `selectedId`, so swiping the photo
/// highlights the tree row and tapping a tree row scrolls the photo — exactly
/// like the Android `MainScreen` pager + `ImageTreeView`.
///
/// Mounted by `Route.v3Room(roomId:)`; opens centered on the tapped room but
/// lets you swipe straight on into the neighboring rooms.
struct V3RoomScreen: View {
    let roomId: String
    @Binding var path: NavigationPath

    @Environment(\.v3Palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var allItems: [ImageItem]

    @State private var selectedId: String
    @State private var expandedIds: Set<String>
    @State private var showDetail: Bool = false
    @State private var detailTargetId: String?
    /// Item awaiting delete confirmation (set by card trash / long-press).
    @State private var pendingDelete: ImageItem? = nil
    @State private var didExpandAncestors = false

    init(roomId: String, path: Binding<NavigationPath>) {
        self.roomId = roomId
        self._path = path
        self._selectedId = State(initialValue: roomId)
        // Open with the tapped room expanded so its contents are visible.
        self._expandedIds = State(initialValue: [roomId])
        self._allItems = Query(sort: \ImageItem.createdAt)
    }

    // MARK: - Derived data (built once per render)

    private var byId: [String: ImageItem] {
        Dictionary(allItems.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }
    private var childCounts: [String: Int] {
        var map: [String: Int] = [:]
        for item in allItems { if let pid = item.parentId { map[pid, default: 0] += 1 } }
        return map
    }
    /// parentId → normalized rects of its positioned sub-spaces.
    private var rectsByParent: [String: [Rectangle]] {
        var map: [String: [Rectangle]] = [:]
        for item in allItems {
            guard let pid = item.parentId, let rect = item.rectangleOnParent else { continue }
            map[pid, default: []].append(rect)
        }
        return map
    }
    private var regions: [String: V3Region] { V3RegionResolver.map(items: allItems) }
    private var nodes: [V3TreeNode] { V3Tree.flatten(items: allItems, expanded: expandedIds) }
    private var nodeIds: Set<String> { Set(nodes.map(\.item.id)) }

    /// The selection clamped to a currently-visible node (collapsing an
    /// ancestor can hide the previously-selected row).
    private var effectiveSelected: String? {
        if nodeIds.contains(selectedId) { return selectedId }
        return nodes.first?.item.id
    }
    private var selectedItem: ImageItem? { effectiveSelected.flatMap { byId[$0] } }

    private var roomCount: Int { allItems.filter { $0.parentId == nil }.count }
    private var placeCount: Int { allItems.filter { $0.parentId != nil }.count }

    private var headerTitle: String { selectedItem?.name ?? "Browse" }
    private var headerSubtitle: String? {
        guard let id = effectiveSelected else { return nil }
        let chain = V3Tree.ancestry(of: id, byId: byId).dropLast()
        if chain.isEmpty {
            return "\(roomCount) \(roomCount == 1 ? "room" : "rooms") · \(placeCount) places"
        }
        return chain.map(\.name).joined(separator: " › ")
    }

    /// Two-way binding the carousel uses: reads the clamped selection, writes
    /// straight through to `selectedId`.
    private var selectionBinding: Binding<String?> {
        Binding(get: { effectiveSelected }, set: { selectedId = $0 ?? roomId })
    }

    // MARK: - Body

    var body: some View {
        Group {
            if nodes.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .background(palette.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: .top)
        .onAppear {
            // Reveal the target when it's nested (e.g. arriving from search):
            // flatten() only shows nodes whose ancestors are all expanded, so
            // without this a deep target is invisible and the selection clamps
            // back to the first room.
            guard !didExpandAncestors else { return }
            didExpandAncestors = true
            var cur = byId[roomId]
            var hops = 0
            while let c = cur, let pid = c.parentId, hops < 64 {
                expandedIds.insert(pid)
                cur = byId[pid]
                hops += 1
            }
        }
        .alert("Delete \(pendingDelete?.name ?? "this")?",
               isPresented: Binding(get: { pendingDelete != nil },
                                    set: { if !$0 { pendingDelete = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { confirmPendingDelete() }
        } message: {
            Text("This removes it and everything inside. Cannot be undone.")
        }
        .sheet(isPresented: $showDetail) {
            V3DetailSheet(itemId: detailTargetId ?? effectiveSelected ?? roomId, onDeleted: {
                // After a delete the row vanishes; clamp selection and only
                // leave the screen if nothing is left to browse.
                if allItems.count <= 1, !path.isEmpty { path.removeLast() }
                selectedId = effectiveSelected ?? roomId
            })
            .environment(\.v3Palette, palette)
        }
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 0) {
            header
            addBand
            GeometryReader { geo in
                VStack(spacing: 0) {
                    V3SpaceCarousel(
                        palette: palette,
                        nodes: nodes,
                        selectedId: selectionBinding,
                        rectsByParent: rectsByParent,
                        childCounts: childCounts,
                        regions: regions,
                        onOpen: openItem,
                        onToggleExpand: { id in toggleExpand(id) },
                        onDelete: { item in pendingDelete = item }
                    )
                    .frame(height: geo.size.height * 0.5)
                    .padding(.top, 4)

                    Divider()
                        .background(palette.line)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)

                    treeSectionLabel

                    V3HierarchyTree(
                        palette: palette,
                        nodes: nodes,
                        selectedId: effectiveSelected,
                        expanded: expandedIds,
                        childCounts: childCounts,
                        regions: regions,
                        onSelect: { selectedId = $0 },
                        onToggleExpand: { id in toggleExpand(id) },
                        onOpen: openItem,
                        onAdd: { id in
                            selectedId = id
                            path.append(Route.v3CreateSub(parentId: id, tempPhotoPath: nil,
                                                          suggestedRect: nil, suggestedTitle: nil))
                        },
                        onDelete: { item in pendingDelete = item }
                    )
                }
            }
        }
    }

    // MARK: - Header + bands

    @ViewBuilder private var header: some View {
        V3NavHeader(
            palette: palette,
            title: headerTitle,
            subtitle: headerSubtitle,
            onBack: { if !path.isEmpty { path.removeLast() } else { dismiss() } }
        ) {
            Button {
                detailTargetId = effectiveSelected
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
            .accessibilityIdentifier("v3-room-menu")
        }
        // `.contain` keeps this a container so the back/ellipsis children stay
        // individually reachable — a bare identifier on the header collapses
        // the subtree into one element and hides `v3-room-menu` from XCUITest.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("v3-room-header")
    }

    @ViewBuilder private var addBand: some View {
        let target = selectedItem
        let isRoom = target?.isRoom ?? true
        let label = isRoom ? "Add a place here" : "Add a spot inside"
        HStack(spacing: 10) {
            Button {
                V3Haptics.impact(.light)
                path.append(Route.v3CreateSub(
                    parentId: effectiveSelected ?? roomId,
                    tempPhotoPath: nil, suggestedRect: nil, suggestedTitle: nil
                ))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .tracking(-0.1)
                }
                .foregroundStyle(palette.paper)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(palette.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.v3Pressable)
            .accessibilityIdentifier("v3-room-add-place")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    @ViewBuilder private var treeSectionLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(palette.ink3)
            Text("Everything, nested")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.3)
                .foregroundStyle(palette.ink3)
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 2)
        .accessibilityIdentifier("v3-browse-tree")
    }

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 0) {
            V3NavHeader(
                palette: palette,
                title: "Browse",
                onBack: { if !path.isEmpty { path.removeLast() } else { dismiss() } }
            )
            V3EmptyState(palette: palette, kind: .room) {
                path.append(Route.v3CreateSub(parentId: roomId, tempPhotoPath: nil,
                                              suggestedRect: nil, suggestedTitle: nil))
            }
            .padding(.horizontal, 22)
            .padding(.top, 40)
            Spacer()
        }
    }

    // MARK: - Actions

    /// Delete the confirmed item (and its whole subtree) via the repository —
    /// same path as the detail sheet's delete, with the same leave-if-empty
    /// behavior as `V3DetailSheet.onDeleted`.
    private func confirmPendingDelete() {
        guard let target = pendingDelete else { return }
        pendingDelete = nil
        let id = target.id
        let container = modelContext.container
        Task {
            let repo = ImageRepository(modelContainer: container)
            try? await repo.delete(itemId: id, strategy: .deleteAllChildren)
            await MainActor.run {
                V3Haptics.warning()
                if allItems.isEmpty, !path.isEmpty { path.removeLast() }
                selectedId = effectiveSelected ?? roomId
            }
        }
    }

    private func openItem(_ item: ImageItem) {
        selectedId = item.id
        if item.v3HasRegion {
            path.append(Route.v3Space(spaceId: item.id))
        } else {
            toggleExpand(item.id, forceExpand: true)
        }
    }

    private func toggleExpand(_ id: String, forceExpand: Bool = false) {
        if expandedIds.contains(id) && !forceExpand {
            expandedIds.remove(id)
            // If the collapsed node hid the current selection, select the node.
            if let sel = effectiveSelected,
               sel != id,
               isDescendant(sel, of: id) {
                selectedId = id
            }
        } else {
            expandedIds.insert(id)
            selectedId = id
        }
    }

    private func isDescendant(_ id: String, of ancestorId: String) -> Bool {
        var cur = byId[id]
        var hops = 0
        while let c = cur, let pid = c.parentId, hops < 64 {
            if pid == ancestorId { return true }
            cur = byId[pid]
            hops += 1
        }
        return false
    }
}
