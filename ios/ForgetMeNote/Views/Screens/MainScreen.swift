import SwiftUI
import SwiftData
import PhotosUI

/// Phase-1+2 MainScreen — dual-pane layout (carousel + tree) with camera and
/// gallery entry points for creating root-level items.
///
/// Maps to Compose `MainScreen.kt` (82 KB on the Android side, split here into
/// smaller component views). Multi-select, reorder mode, walkthrough overlay,
/// and detailed long-press menus are deferred to later phases.
struct MainScreen: View {
    @Binding var path: NavigationPath
    @Environment(\.modelContext) private var modelContext

    /// All items, used to build the recursive tree.
    @Query(sort: \ImageItem.createdAt) private var allItems: [ImageItem]
    /// Root-level items for the carousel.
    @Query(filter: #Predicate<ImageItem> { $0.parentId == nil },
           sort: \ImageItem.createdAt) private var rootItems: [ImageItem]
    @Query private var settingsRows: [AppSettings]
    private var settings: AppSettings? { settingsRows.first }

    @State private var carouselIndex: Int = 0
    @State private var searchText: String = ""
    @State private var expandedIds: Set<String> = []

    // Multi-select / reorder edit mode
    @State private var editMode: EditMode = .inactive
    @State private var selection: Set<String> = []
    @State private var showBatchDeleteConfirm: Bool = false
    @State private var pendingDelete: String? = nil
    @State private var pendingDeleteHasChildren: Bool = false

    // Camera + gallery state
    @State private var showCamera: Bool = false
    @State private var galleryPickerItem: PhotosPickerItem?
    @State private var pendingPhotoPath: String?

    // "New Room" naming sheet
    @State private var showNewRoomSheet: Bool = false
    @State private var newRoomName: String = ""

    /// Set of item IDs that should be visible in the tree given the current
    /// search text. Includes every matching item PLUS the full ancestor chain
    /// of each match so the tree path stays intact.
    private var visibleIds: Set<String> {
        guard !searchText.isEmpty else { return Set(allItems.map { $0.id }) }
        let needle = searchText.lowercased()
        let byId = Dictionary(uniqueKeysWithValues: allItems.map { ($0.id, $0) })
        var visible: Set<String> = []
        for item in allItems where matches(item, needle: needle) {
            visible.insert(item.id)
            var cur = item
            while let pid = cur.parentId, let parent = byId[pid] {
                visible.insert(parent.id)
                cur = parent
            }
        }
        return visible
    }

    private var hasAnyVisible: Bool { !visibleIds.isEmpty }
    private var isSearching: Bool { !searchText.isEmpty }

    private func matches(_ item: ImageItem, needle: String) -> Bool {
        item.name.lowercased().contains(needle) ||
        item.notes.lowercased().contains(needle) ||
        item.tags.contains(where: { $0.lowercased().contains(needle) })
    }

    var body: some View {
        VStack(spacing: 0) {
            carouselPane
                .frame(maxWidth: .infinity, minHeight: 240, maxHeight: 320)
                .background(Color(.systemGroupedBackground))

            Divider()

            treePane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
        }
        .searchable(text: $searchText, prompt: "Search names, tags, notes")
        .navigationTitle("Forget Me Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { mainToolbar }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(
                onPick: handleCapturedPhoto,
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $galleryPickerActive,
                      selection: $galleryPickerItem,
                      matching: .images)
        .onChange(of: galleryPickerItem) { _, item in
            guard let item else { return }
            Task { await handleGalleryItem(item) }
        }
        .sheet(isPresented: $showNewRoomSheet) {
            NewRoomSheet(name: $newRoomName) { confirmed in
                if confirmed,
                   !newRoomName.trimmingCharacters(in: .whitespaces).isEmpty {
                    let nameSnapshot = newRoomName.trimmingCharacters(in: .whitespaces)
                    Task { @MainActor in
                        let repo = ImageRepository(modelContainer: modelContext.container)
                        _ = try? await repo.createRoom(name: nameSnapshot)
                    }
                }
                newRoomName = ""
            }
        }
        .confirmationDialog(
            "Delete this item?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = pendingDelete {
                    Task { @MainActor in
                        let repo = ImageRepository(modelContainer: modelContext.container)
                        try? await repo.delete(itemId: id, strategy: .deleteAllChildren)
                        AppIconBadge.refreshFromCurrentSettings(modelContext: modelContext)
                    }
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(pendingDeleteHasChildren
                 ? "This will also delete every descendant. This can't be undone."
                 : "This can't be undone.")
        }
        .confirmationDialog(
            "Delete \(selection.count) selected item(s)?",
            isPresented: $showBatchDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete \(selection.count)", role: .destructive) {
                deleteSelected()
                showBatchDeleteConfirm = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All descendants will be deleted as well.")
        }
        .safeAreaInset(edge: .bottom) {
            if editMode == .active && !selection.isEmpty {
                HStack {
                    Text("\(selection.count) selected")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(role: .destructive) {
                        showBatchDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .accessibilityIdentifier("batch-delete")
                }
                .padding()
                .background(.bar)
            }
        }
    }

    // MARK: - Carousel pane

    @ViewBuilder private var carouselPane: some View {
        if rootItems.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("No root items yet")
                    .foregroundStyle(.secondary)
                Text("Use + to add a Space, or the ☰ menu for a Room")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            TabView(selection: $carouselIndex) {
                ForEach(rootItems.indices, id: \.self) { idx in
                    CarouselCard(item: rootItems[idx], settings: settings) {
                        path.append(Route.imageDetail(imageId: rootItems[idx].id))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .modifier(FirstCardTargetModifier(isFirst: idx == 0))
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    // MARK: - Tree pane

    @ViewBuilder private var treePane: some View {
        if !hasAnyVisible {
            ContentUnavailableView(
                isSearching ? "No matches" : "No items",
                systemImage: isSearching ? "magnifyingglass" : "tray",
                description: Text(isSearching
                                  ? "Try a different search term."
                                  : "Add a Space with the + button or a Room from the menu.")
            )
        } else {
            List(selection: $selection) {
                // In reorder mode we only show top-level rows so .onMove makes
                // sense; nested rows would be ambiguous to move.
                if editMode == .active {
                    ForEach(rootsOfVisible(), id: \.id) { root in
                        flatTreeRow(item: root, depth: 0)
                            .tag(root.id)
                    }
                    .onMove(perform: handleReorder)
                    .onDelete(perform: handleListDelete)
                } else {
                    ForEach(flattenedRows(), id: \.id) { row in
                        flatTreeRow(item: row.item, depth: row.depth)
                            .id(row.item.id)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    requestDelete(row.item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task { @MainActor in
                                        let repo = ImageRepository(modelContainer: modelContext.container)
                                        _ = try? await repo.toggleUpdated(itemId: row.item.id)
                                        AppIconBadge.refreshFromCurrentSettings(modelContext: modelContext)
                                    }
                                } label: {
                                    Label(row.item.isUpdated ? "Not Updated" : "Updated",
                                          systemImage: "exclamationmark.circle")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, $editMode)
        }
    }

    /// Linear list of (item, depth) in the order they should render. Honors
    /// expandedIds and visibleIds. Children of a not-expanded parent are
    /// omitted unless we're searching (in which case everything visible is
    /// shown — same behavior as before).
    private struct FlatRow: Identifiable {
        let item: ImageItem
        let depth: Int
        var id: String { item.id }
    }

    private func flattenedRows() -> [FlatRow] {
        var rows: [FlatRow] = []
        for root in rootsOfVisible() {
            appendRow(root, depth: 0, into: &rows)
        }
        return rows
    }

    private func appendRow(_ item: ImageItem, depth: Int, into rows: inout [FlatRow]) {
        rows.append(FlatRow(item: item, depth: depth))
        let isExpanded = isSearching || expandedIds.contains(item.id)
        guard isExpanded else { return }
        let kids = allItems
            .filter { $0.parentId == item.id && visibleIds.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
        for kid in kids {
            appendRow(kid, depth: depth + 1, into: &rows)
        }
    }

    private func rootsOfVisible() -> [ImageItem] {
        let vis = visibleIds
        return allItems.filter { $0.parentId == nil && vis.contains($0.id) }
    }

    @ViewBuilder
    private func flatTreeRow(item: ImageItem, depth: Int) -> some View {
        FlatTreeRow(
            item: item,
            depth: depth,
            expandedIds: $expandedIds,
            allItems: allItems,
            settings: settings,
            onTap: { tappedId in
                if let idx = rootItems.firstIndex(where: { $0.id == tappedId }) {
                    carouselIndex = idx
                }
            },
            onDoubleTap: { tappedId in
                path.append(Route.imageDetail(imageId: tappedId))
            },
            onToggleUpdated: { tappedId in
                Task { @MainActor in
                    let repo = ImageRepository(modelContainer: modelContext.container)
                    _ = try? await repo.toggleUpdated(itemId: tappedId)
                    AppIconBadge.refreshFromCurrentSettings(modelContext: modelContext)
                }
            },
            onDelete: { _ in requestDelete(item) }
        )
    }

    // MARK: - Delete + reorder handlers

    private func requestDelete(_ item: ImageItem) {
        pendingDelete = item.id
        pendingDeleteHasChildren = allItems.contains { $0.parentId == item.id }
    }

    private func handleListDelete(at offsets: IndexSet) {
        let roots = rootsOfVisible()
        let ids = offsets.compactMap { roots.indices.contains($0) ? roots[$0].id : nil }
        guard let first = ids.first else { return }
        pendingDelete = first
        pendingDeleteHasChildren = allItems.contains { $0.parentId == first }
    }

    private func handleReorder(from source: IndexSet, to destination: Int) {
        var roots = rootsOfVisible()
        roots.move(fromOffsets: source, toOffset: destination)
        // Rewrite createdAt timestamps spaced by 1000ms so the new order persists.
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        for (idx, root) in roots.enumerated() {
            root.createdAt = now + Int64(idx) * 1000
        }
        try? modelContext.save()
    }

    private func deleteSelected() {
        let ids = Array(selection)
        guard !ids.isEmpty else { return }
        Task { @MainActor in
            let repo = ImageRepository(modelContainer: modelContext.container)
            for id in ids {
                try? await repo.delete(itemId: id, strategy: .deleteAllChildren)
            }
            selection.removeAll()
            AppIconBadge.refreshFromCurrentSettings(modelContext: modelContext)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button("New Room (no photo)", systemImage: "square.dashed") {
                    newRoomName = ""
                    showNewRoomSheet = true
                }
                Button("Pick from Gallery", systemImage: "photo.on.rectangle") {
                    galleryPickerActive = true
                }
                #if DEBUG
                Button("Insert demo Space (test)", systemImage: "testtube.2") {
                    insertDemoSpace()
                }
                .accessibilityIdentifier("Insert demo Space")
                Button("Insert demo Sub-Space combo (test)", systemImage: "testtube.2") {
                    insertDemoSubSpaceCombo()
                }
                .accessibilityIdentifier("Insert demo Sub-Space combo")
                #endif
                Divider()
                Button("Settings", systemImage: "gear") { path.append(Route.settings) }
                Button("Help", systemImage: "questionmark.circle") { path.append(Route.help) }
            } label: {
                Image(systemName: "line.3.horizontal")
            }
            .accessibilityLabel("Menu")
            .accessibilityIdentifier("Menu")
            .walkthroughTarget(.menuButton)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                withAnimation {
                    if editMode == .active {
                        editMode = .inactive
                        selection.removeAll()
                    } else {
                        editMode = .active
                    }
                }
            } label: {
                Text(editMode == .active ? "Done" : "Select")
            }
            .accessibilityIdentifier("edit-mode-toggle")
        }
        ToolbarItem(placement: .topBarTrailing) {
            // Plus button: tap = camera (or gallery fallback on Simulator),
            // long press = gallery on any device.
            Button {
                if CameraImagePicker.isAvailable {
                    showCamera = true
                } else {
                    galleryPickerActive = true
                }
            } label: {
                Image(systemName: "plus")
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    galleryPickerActive = true
                }
            )
            .accessibilityLabel("Add Space")
            .accessibilityIdentifier("Add Space")
            .walkthroughTarget(.addButton)
        }
    }

    /// `PhotosPicker`'s `isPresented` overlay (used by the menu Gallery item
    /// and long-press on the + button).
    @State private var galleryPickerActive: Bool = false

    // MARK: - Photo handlers

    private func handleCapturedPhoto(_ data: Data) {
        showCamera = false
        do {
            let tempPath = try TempPhotoStore.write(data)
            pendingPhotoPath = tempPath
            path.append(Route.createChild(
                parentId: ROOT_PARENT_SENTINEL,
                suggestedTitle: nil,
                rectangleOnParent: nil,
                tempPhotoPath: tempPath
            ))
        } catch {
            print("Failed to stage captured photo: \(error)")
        }
    }

    private func handleGalleryItem(_ item: PhotosPickerItem) async {
        defer { galleryPickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        do {
            let tempPath = try TempPhotoStore.write(data)
            pendingPhotoPath = tempPath
            path.append(Route.createChild(
                parentId: ROOT_PARENT_SENTINEL,
                suggestedTitle: nil,
                rectangleOnParent: nil,
                tempPhotoPath: tempPath
            ))
        } catch {
            print("Failed to stage gallery photo: \(error)")
        }
    }

    #if DEBUG
    /// Debug-only path that bypasses the system PhotosPicker so Maestro can
    /// exercise the CreateChildScreen flow. Generates a labeled gradient image
    /// at runtime and stages it as if it had come from the picker.
    private func insertDemoSpace() {
        let data = DemoImage.make(label: "Demo Photo")
        guard let tempPath = try? TempPhotoStore.write(data) else { return }
        path.append(Route.createChild(
            parentId: ROOT_PARENT_SENTINEL,
            suggestedTitle: "Demo Photo",
            rectangleOnParent: nil,
            tempPhotoPath: tempPath
        ))
    }

    /// Bypasses both PhotosPicker AND tree-row navigation. Uses the most
    /// recently created root Space as the parent (creating one if none exists),
    /// then jumps straight to CreateChildScreen so Maestro can exercise the
    /// InteractiveRectangleSelector deterministically.
    private func insertDemoSubSpaceCombo() {
        // Find the latest root Space (filePath != nil).
        let parentSpace = rootItems.last(where: { !$0.isRoom })
        let parentId = parentSpace?.id

        Task { @MainActor in
            let repo = ImageRepository(modelContainer: modelContext.container)
            let effectiveParent: String
            if let parentId {
                effectiveParent = parentId
            } else {
                // No Space exists — seed one first.
                let seedData = DemoImage.make(label: "Auto Parent")
                guard let seeded = try? await repo.saveImage(
                    jpegData: seedData, name: "Auto Parent",
                    tags: [], parentId: nil, rectangleOnParent: nil
                ) else { return }
                effectiveParent = seeded
            }

            let subData = DemoImage.make(label: "Sub")
            guard let tempPath = try? TempPhotoStore.write(subData) else { return }
            path.append(Route.createChild(
                parentId: effectiveParent,
                suggestedTitle: "Demo Sub",
                rectangleOnParent: nil,
                tempPhotoPath: tempPath
            ))
        }
    }
    #endif
}

/// Sentinel used as `parentId` when the new item should be a ROOT item rather
/// than a child of another item. CreateChildScreen detects this and creates a
/// root-level Space.
let ROOT_PARENT_SENTINEL = "__root__"

/// Only attaches the walkthrough's `.firstCard` bounds reporter when this is
/// actually the first card in the carousel.
private struct FirstCardTargetModifier: ViewModifier {
    let isFirst: Bool
    func body(content: Content) -> some View {
        if isFirst {
            content.walkthroughTarget(.firstCard)
        } else {
            content
        }
    }
}

// MARK: - Carousel card

private struct CarouselCard: View {
    let item: ImageItem
    var settings: AppSettings?
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(backgroundColor.gradient)
                    .overlay(
                        VStack(spacing: 10) {
                            if item.isRoom {
                                Image(systemName: "house.fill")
                                    .font(.system(size: 56, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                            } else {
                                if let path = item.filePath,
                                   let image = UIImage(contentsOfFile: path) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .padding(10)
                                } else {
                                    Image(systemName: "photo")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                            }
                            Text(item.name)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
                                .padding(.horizontal, 12)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 12)
                        }
                    )
                if item.isUpdated {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(highlightColor.opacity(highlightOpacity))
                        .allowsHitTesting(false)
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(highlightColor, lineWidth: 4)
                        .allowsHitTesting(false)
                }
            }
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if let argb = item.roomBackgroundColor {
            return Color(argb: argb)
        }
        return AppColors.defaultRoomBackground
    }

    private var highlightColor: Color {
        guard let argb = settings?.updatedHighlightColor else {
            return AppColors.defaultUpdatedHighlight
        }
        return Color(argb: argb)
    }

    private var highlightOpacity: Double {
        Double(settings?.updatedHighlightPercentage ?? 0.2)
    }
}

// MARK: - Recursive tree row

private struct FlatTreeRow: View {
    let item: ImageItem
    let depth: Int
    @Binding var expandedIds: Set<String>
    let allItems: [ImageItem]
    var settings: AppSettings?
    let onTap: (String) -> Void
    let onDoubleTap: (String) -> Void
    let onToggleUpdated: (String) -> Void
    let onDelete: (String) -> Void

    @State private var showDeleteConfirm: Bool = false

    private var children: [ImageItem] {
        allItems
            .filter { $0.parentId == item.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var isExpanded: Bool {
        expandedIds.contains(item.id)
    }

    private var highlightColor: Color {
        guard let argb = settings?.updatedHighlightColor else {
            return AppColors.defaultUpdatedHighlight
        }
        return Color(argb: argb)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if !children.isEmpty {
                    Button {
                        if isExpanded { expandedIds.remove(item.id) }
                        else { expandedIds.insert(item.id) }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 16, height: 1)
                }

                Image(systemName: item.isRoom ? "house" : "photo")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                    if !item.tags.isEmpty {
                        Text(item.tags.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if item.isUpdated {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(highlightColor)
                }
            }
            .padding(.leading, CGFloat(depth) * 16)
            .padding(.vertical, 4)
            .background(item.isUpdated
                        ? highlightColor.opacity(Double(settings?.updatedHighlightPercentage ?? 0.2))
                        : Color.clear)
            .contentShape(SwiftUI.Rectangle())
            .onTapGesture(count: 2) { onDoubleTap(item.id) }
            .onTapGesture(count: 1) { onTap(item.id) }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("tree-row-\(item.name)")
            .contextMenu {
                Button {
                    onToggleUpdated(item.id)
                } label: {
                    Label(item.isUpdated ? "Mark as Not Updated" : "Mark as Updated",
                          systemImage: item.isUpdated ? "checkmark.circle" : "exclamationmark.circle")
                }
                Button {
                    onDoubleTap(item.id)
                } label: {
                    Label("Open detail", systemImage: "arrow.forward.circle")
                }
                Divider()
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .confirmationDialog(
                "Delete \"\(item.name)\"?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { onDelete(item.id) }
                Button("Cancel", role: .cancel) {}
            } message: {
                if !children.isEmpty {
                    Text("This will also delete \(children.count) child item\(children.count == 1 ? "" : "s") and all descendants.")
                }
            }

        }
    }
}

// MARK: - "New Room" naming sheet

private struct NewRoomSheet: View {
    @Binding var name: String
    let onDismiss: (_ confirmed: Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Room name") {
                    TextField("e.g. Living Room", text: $name)
                        .accessibilityIdentifier("new-room-name-field")
                }
            }
            .navigationTitle("New Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss(false)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onDismiss(true)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("create-room-confirm")
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    @Previewable @State var path = NavigationPath()
    return NavigationStack(path: $path) {
        MainScreen(path: $path)
    }
    .modelContainer(for: [ImageItem.self, AppSettings.self], inMemory: true)
}
