import SwiftUI
import SwiftData

/// V3 Home — the Android `MainScreen` model: the home screen IS the synced
/// two-pane browser. A horizontal carousel you swipe left/right across the whole
/// forest (rooms + their photo spaces) over a top-to-bottom indented hierarchy
/// tree. One shared flattened list + one `selectedId` keep the panes in lock-step.
///
/// Adding is hierarchical: whatever node is selected is the parent for the next
/// thing you add (photo OR empty box), so you can build
/// Living Room → Bookshelf → Top Shelf → Book right from here. New top-level
/// rooms are added via the menu.
struct V3BrowseHome: View {
    let palette: V3Palette
    let name: String
    /// Selection is owned by the root so the capture FAB can add into it too.
    @Binding var selectedId: String?
    @Binding var path: NavigationPath
    var onOpenSearch: () -> Void = {}
    /// Add a photo child under `parentId` (routes through the capture flow).
    var onCapturePhoto: (String) -> Void = { _ in }
    /// Add an empty container (sub-room) under `parentId`.
    var onAddEmpty: (String) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ImageItem.createdAt) private var allItems: [ImageItem]

    @State private var expandedIds: Set<String> = []
    @State private var showNewRoom = false
    @State private var knownIds: Set<String> = []
    @State private var didInit = false
    /// Item awaiting delete confirmation (set by card trash / long-press).
    @State private var pendingDelete: ImageItem? = nil

    // MARK: - Derived data

    private var byId: [String: ImageItem] {
        Dictionary(allItems.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }
    private var childCounts: [String: Int] {
        var map: [String: Int] = [:]
        for item in allItems { if let pid = item.parentId { map[pid, default: 0] += 1 } }
        return map
    }
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

    private var effectiveSelected: String? {
        if let id = selectedId, nodeIds.contains(id) { return id }
        return nodes.first?.item.id
    }
    private var selectedItem: ImageItem? { effectiveSelected.flatMap { byId[$0] } }

    private var roomCount: Int { allItems.filter { $0.parentId == nil }.count }
    private var placeCount: Int { allItems.filter { $0.parentId != nil }.count }

    private var selectionBinding: Binding<String?> {
        Binding(get: { effectiveSelected }, set: { selectedId = $0 })
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            addContextBar
            if nodes.isEmpty {
                firstRunState
            } else {
                browse
            }
        }
        .background(palette.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showNewRoom) {
            V3NewRoomSheet().environment(\.v3Palette, palette)
        }
        .alert("Delete \(pendingDelete?.name ?? "this")?",
               isPresented: Binding(get: { pendingDelete != nil },
                                    set: { if !$0 { pendingDelete = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { confirmPendingDelete() }
        } message: {
            Text("This removes it and everything inside. Cannot be undone.")
        }
        .onAppear {
            if !didInit {
                didInit = true
                knownIds = Set(allItems.map(\.id))
                if selectedId == nil { selectedId = nodes.first?.item.id }
                // Expand the first root so there's something to see immediately.
                if let firstRoot = allItems.first(where: { $0.parentId == nil }) {
                    expandedIds.insert(firstRoot.id)
                }
            }
        }
        .onChange(of: allItems.map(\.id)) { _, ids in
            // A new item was just created (hierarchical add) — reveal & select it.
            let current = Set(ids)
            let fresh = current.subtracting(knownIds)
            if !knownIds.isEmpty, !fresh.isEmpty {
                let newest = allItems
                    .filter { fresh.contains($0.id) }
                    .max(by: { $0.createdAt < $1.createdAt })
                if let newest {
                    expandAncestors(of: newest.id)
                    selectedId = newest.id
                }
            }
            knownIds = current
        }
    }

    // MARK: - Header

    @ViewBuilder private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Hi \(name.split(separator: " ").first.map(String.init) ?? name)")
                    .font(V3Font.headline(26))
                    .foregroundStyle(palette.ink)
                    .tracking(-0.4)
                HStack(spacing: 5) {
                    FlowerMark(size: 11, color: palette.accent, pollen: palette.pollen)
                    Text("\(placeCount) places · \(roomCount) \(roomCount == 1 ? "room" : "rooms")")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.ink2)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("v3-home-greeting")

            Spacer()

            Button(action: onOpenSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.ink)
                    .frame(width: 40, height: 40)
                    .background(palette.surface, in: Circle())
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
            }
            .accessibilityLabel("Search")
            .accessibilityIdentifier("v3-home-search")

            addMenu
        }
        .padding(.horizontal, 18)
        .padding(.top, 60)
        .padding(.bottom, 10)
    }

    @ViewBuilder private var addMenu: some View {
        Menu {
            Button {
                V3Haptics.impact(.light)
                showNewRoom = true
            } label: { Label("New room", systemImage: "square.grid.2x2") }

            if let sel = selectedItem {
                Section("Inside \(sel.name.isEmpty ? "selected" : sel.name)") {
                    Button {
                        V3Haptics.impact(.light)
                        onCapturePhoto(sel.id)
                    } label: { Label("Add a photo", systemImage: "camera") }
                    Button {
                        V3Haptics.impact(.light)
                        onAddEmpty(sel.id)
                    } label: { Label("Add an empty box", systemImage: "shippingbox") }
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(palette.paper)
                .frame(width: 40, height: 40)
                .background(palette.ink, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
        .accessibilityLabel("Add")
        .accessibilityIdentifier("v3-home-add")
    }

    // MARK: - Add-context bar (shows WHERE the next add lands)

    @ViewBuilder private var addContextBar: some View {
        if let sel = selectedItem {
            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.ink3)
                (Text("Adding goes inside ")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.ink3)
                 + Text(sel.name.isEmpty ? "this" : sel.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.accent))
                    .lineLimit(1)
                Spacer()
                Button {
                    V3Haptics.impact(.light)
                    onCapturePhoto(sel.id)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "camera.fill").font(.system(size: 12, weight: .bold))
                        Text("Add here").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(palette.paper)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(palette.ink, in: Capsule())
                }
                .buttonStyle(.v3Pressable)
                .accessibilityIdentifier("v3-home-add-here")
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Two-pane browse

    @ViewBuilder private var browse: some View {
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
                .frame(height: geo.size.height * 0.52)
                .padding(.top, 2)

                Divider()
                    .background(palette.line)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

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
                    onAdd: { id in selectedId = id; onCapturePhoto(id) },
                    onDelete: { item in pendingDelete = item }
                )
            }
        }
    }

    // MARK: - First-run

    @ViewBuilder private var firstRunState: some View {
        VStack(spacing: 16) {
            Spacer()
            FlowerMark(size: 44, color: palette.accent, pollen: palette.pollen)
            Text("Make your first room")
                .font(V3Font.headline(24))
                .foregroundStyle(palette.ink)
            Text("Rooms hold the places and things you want to remember.")
                .font(.system(size: 14))
                .foregroundStyle(palette.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                V3Haptics.impact(.medium)
                showNewRoom = true
            } label: {
                Text("New room")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.paper)
                    .padding(.horizontal, 24).frame(height: 48)
                    .background(palette.ink, in: Capsule())
            }
            .buttonStyle(.v3Pressable)
            .accessibilityIdentifier("v3-home-first-room")
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    /// Delete the confirmed item (and its whole subtree) via the repository —
    /// same path as the detail sheet's delete. Selection self-heals through
    /// `effectiveSelected` once the row vanishes from the query.
    private func confirmPendingDelete() {
        guard let target = pendingDelete else { return }
        pendingDelete = nil
        let id = target.id
        if selectedId == id { selectedId = nil }
        let container = modelContext.container
        Task {
            let repo = ImageRepository(modelContainer: container)
            try? await repo.delete(itemId: id, strategy: .deleteAllChildren)
            await MainActor.run { V3Haptics.warning() }
        }
    }

    private func openItem(_ item: ImageItem) {
        selectedId = item.id
        if item.v3HasRegion {
            // Photo OR a traced/cropped region → open it (you can trace deeper).
            path.append(Route.v3Space(spaceId: item.id))
        } else {
            // Plain room/box → reveal its contents.
            toggleExpand(item.id, forceExpand: true)
        }
    }

    private func toggleExpand(_ id: String, forceExpand: Bool = false) {
        if expandedIds.contains(id) && !forceExpand {
            expandedIds.remove(id)
            if let sel = effectiveSelected, sel != id, isDescendant(sel, of: id) {
                selectedId = id
            }
        } else {
            expandedIds.insert(id)
            selectedId = id
        }
    }

    private func expandAncestors(of id: String) {
        var cur = byId[id]
        var hops = 0
        while let c = cur, let pid = c.parentId, hops < 64 {
            expandedIds.insert(pid)
            cur = byId[pid]
            hops += 1
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
