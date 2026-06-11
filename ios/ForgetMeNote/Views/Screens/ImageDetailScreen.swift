import SwiftUI
import SwiftData
import PhotosUI

/// Phase-4 implementation of the detail screen.
///
/// Shows the item's photo (with optional child / detection overlays), allows
/// edit-in-place of the name and tags, exposes a notes dialog, an Updated-flag
/// toggle, and a + button for creating sub-items. Object detection from Phase 3
/// is still wired here.
struct ImageDetailScreen: View {
    let imageId: String
    @Binding var path: NavigationPath

    @Environment(\.modelContext) private var modelContext
    @Query private var matches: [ImageItem]
    @Query private var allItems: [ImageItem]
    @Query private var settingsRows: [AppSettings]

    // Sub-space creation entry points
    @State private var showCamera: Bool = false
    @State private var galleryPickerActive: Bool = false
    @State private var galleryPickerItem: PhotosPickerItem?

    // ML Kit object detection state
    @State private var detections: [DetectedObjectInfo] = []
    @State private var selectedDetection: DetectedObjectInfo?
    @State private var isDetecting: Bool = false

    // Edit-in-place state
    @State private var isEditingName: Bool = false
    @State private var editedName: String = ""
    @State private var isEditingTags: Bool = false
    @State private var editedTagsText: String = ""

    // Notes dialog
    @State private var showNotesDialog: Bool = false

    // Pinch-to-zoom overlay
    @State private var showZoom: Bool = false

    // Image overlay mode: nothing, children, detections
    private enum OverlayMode { case none, children, detections }

    init(imageId: String, path: Binding<NavigationPath>) {
        self.imageId = imageId
        self._path = path
        let id = imageId
        self._matches = Query(filter: #Predicate<ImageItem> { $0.id == id })
        self._allItems = Query(sort: \ImageItem.createdAt)
    }

    private var item: ImageItem? { matches.first }
    private var image: UIImage? {
        guard let p = item?.filePath else { return nil }
        return UIImage(contentsOfFile: p)
    }
    private var settings: AppSettings? { settingsRows.first }
    private var childItems: [ImageItem] {
        guard let item else { return [] }
        return allItems.filter { $0.parentId == item.id }
            .sorted { $0.createdAt < $1.createdAt }
    }
    private var overlayMode: OverlayMode {
        if !detections.isEmpty { return .detections }
        if !childItems.isEmpty { return .children }
        return .none
    }

    var body: some View {
        Form {
            if let image {
                Section { imageSection(image: image) }
                if let item, !item.isRoom { detectionSection }
            }
            metadataSection
            notesSection
            childrenSection
        }
        .navigationTitle(item?.name ?? "Item")
        .navigationBarTitleDisplayMode(.inline)
        .customBackButton()
        .toolbar { trailingToolbar }
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
        .onChange(of: galleryPickerItem) { _, picked in
            guard let picked else { return }
            Task { await handleGalleryItem(picked) }
        }
        .sheet(isPresented: $showNotesDialog) {
            NotesDialog(
                initialNotes: item?.notes ?? "",
                onSave: { newNotes in
                    Task { await saveNotes(newNotes) }
                },
                onCancel: {}
            )
        }
        .fullScreenCover(isPresented: $showZoom) {
            if let image {
                ZoomableImageOverlay(image: image, onDismiss: { showZoom = false })
            }
        }
    }

    // MARK: - Image section (with overlays)

    @ViewBuilder
    private func imageSection(image: UIImage) -> some View {
        ZStack {
            switch overlayMode {
            case .none:
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            case .children:
                ChildBoundingBoxOverlay(
                    image: image,
                    children: childItems.compactMap { c in
                        guard let r = c.rectangleOnParent else { return nil }
                        return (id: c.id, name: c.name, rect: r)
                    },
                    settings: settings,
                    onChildTap: { childId in
                        path.append(Route.imageDetail(imageId: childId))
                    }
                )
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            case .detections:
                DetectedObjectOverlay(
                    image: image,
                    detections: detections,
                    selectedDetection: selectedDetection,
                    onSelect: { selectedDetection = $0 },
                    onCreate: handleDetectedObjectTap
                )
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            // Updated-flag highlight overlay
            if let item, item.isUpdated {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(highlightColor, lineWidth: 6)
                    .allowsHitTesting(false)
            }
            // Magnifier button — opens full-screen zoom
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showZoom = true
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white, Color.black.opacity(0.55))
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .accessibilityIdentifier("zoom-open")
                }
                Spacer()
            }
        }
        .listRowInsets(EdgeInsets())
    }

    private var highlightColor: Color {
        guard let argb = settings?.updatedHighlightColor else {
            return AppColors.defaultUpdatedHighlight
        }
        return Color(argb: argb)
    }

    // MARK: - Detection section

    @ViewBuilder private var detectionSection: some View {
        Section {
            HStack {
                Button {
                    Task { await runDetection() }
                } label: {
                    HStack {
                        Image(systemName: "viewfinder.circle")
                        Text(isDetecting ? "Detecting…"
                             : detections.isEmpty ? "Detect Objects"
                                                  : "Detect Again")
                    }
                }
                .disabled(isDetecting)
                .accessibilityIdentifier("Detect Objects")
                Spacer()
                if !detections.isEmpty {
                    Button("Clear", role: .destructive) {
                        detections = []
                        selectedDetection = nil
                    }
                }
            }
            if let selectedDetection {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "scope")
                            .foregroundStyle(.secondary)
                        Text("Selected object")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(selectedDetection.label)
                        .font(.headline)
                    if !selectedDetection.alternates.isEmpty {
                        Text("Also looks like " + selectedDetection.alternates.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        handleDetectedObjectTap(selectedDetection)
                    } label: {
                        Label("Save as sub-space", systemImage: "plus.rectangle.on.rectangle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            } else if !detections.isEmpty {
                Text("Tap an outlined object to inspect it. Double-tap to save it as a sub-space.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Metadata section (edit-in-place)

    @ViewBuilder private var metadataSection: some View {
        Section("Item") {
            // Name row
            HStack {
                Text("Name").foregroundStyle(.secondary)
                Spacer()
                if isEditingName {
                    TextField("Name", text: $editedName)
                        .multilineTextAlignment(.trailing)
                        .submitLabel(.done)
                        .onSubmit { commitNameEdit() }
                    Button("Save") { commitNameEdit() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button("Cancel") {
                        isEditingName = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Text(item?.name ?? "—")
                    Button {
                        editedName = item?.name ?? ""
                        isEditingName = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .contentShape(SwiftUI.Rectangle())
                    .accessibilityIdentifier("edit-name-button")
                }
            }

            // Tags row
            HStack(alignment: .top) {
                Text("Tags").foregroundStyle(.secondary)
                Spacer()
                if isEditingTags {
                    VStack(alignment: .trailing, spacing: 4) {
                        TextField("comma-separated", text: $editedTagsText)
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.done)
                            .onSubmit { commitTagsEdit() }
                        HStack {
                            Button("Save") { commitTagsEdit() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            Button("Cancel") { isEditingTags = false }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                } else {
                    Text(item?.tags.isEmpty == false
                         ? item!.tags.joined(separator: ", ")
                         : "—")
                    .foregroundStyle(item?.tags.isEmpty == false ? .primary : .secondary)
                    Button {
                        editedTagsText = item?.tags.joined(separator: ", ") ?? ""
                        isEditingTags = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .contentShape(SwiftUI.Rectangle())
                    .accessibilityIdentifier("edit-tags-button")
                }
            }

            // Type and Updated rows
            LabeledContent("Type", value: (item?.isRoom ?? true) ? "Room" : "Space")
            if let item {
                UpdatedToggleRow(item: item, modelContext: modelContext)
            }
        }
    }

    // MARK: - Notes section

    @ViewBuilder private var notesSection: some View {
        Section("Notes") {
            Button {
                showNotesDialog = true
            } label: {
                HStack {
                    Text(item?.notes.isEmpty == false
                         ? notesPreview(item!.notes)
                         : "Tap to add…")
                        .foregroundStyle(item?.notes.isEmpty == false ? .primary : .secondary)
                    Spacer()
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("notes-row")
        }
    }

    private func notesPreview(_ notes: String) -> String {
        if notes.count <= 50 { return notes }
        return String(notes.prefix(50)) + "…"
    }

    // MARK: - Children section

    @ViewBuilder private var childrenSection: some View {
        Section("Children (\(childItems.count))") {
            if childItems.isEmpty {
                Text("No children. Tap + above to add one.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(childItems, id: \.id) { child in
                    Button {
                        path.append(Route.imageDetail(imageId: child.id))
                    } label: {
                        HStack {
                            childThumbnail(for: child)
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading) {
                                Text(child.name)
                                if !child.tags.isEmpty {
                                    Text(child.tags.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if child.isUpdated {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func childThumbnail(for child: ImageItem) -> some View {
        if let path = child.filePath, let img = UIImage(contentsOfFile: path) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            ZStack {
                Color(argb: child.roomBackgroundColor ?? 0xFF6750A4)
                Image(systemName: "house")
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var trailingToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
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
            .accessibilityLabel("Add Sub-Space")
            .accessibilityIdentifier("Add Sub-Space")
        }
        #if DEBUG
        ToolbarItem(placement: .topBarLeading) {
            Button("Demo Sub", systemImage: "testtube.2") {
                insertDemoSubSpace()
            }
            .accessibilityIdentifier("Insert demo Sub-Space")
        }
        #endif
    }

    // MARK: - Actions

    private func commitNameEdit() {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            isEditingName = false
            return
        }
        Task { @MainActor in
            let repo = ImageRepository(modelContainer: modelContext.container)
            try? await repo.updateName(itemId: imageId, name: trimmed)
            isEditingName = false
        }
    }

    private func commitTagsEdit() {
        let tags = editedTagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        Task { @MainActor in
            let repo = ImageRepository(modelContainer: modelContext.container)
            try? await repo.updateTags(itemId: imageId, tags: tags)
            isEditingTags = false
        }
    }

    private func saveNotes(_ newNotes: String) async {
        let repo = ImageRepository(modelContainer: modelContext.container)
        try? await repo.updateNotes(itemId: imageId, notes: newNotes)
    }

    private func setUpdated(_ value: Bool) async {
        let repo = ImageRepository(modelContainer: modelContext.container)
        try? await repo.setUpdated(itemId: imageId, value: value)
    }

    private func handleCapturedPhoto(_ data: Data) {
        showCamera = false
        guard let tempPath = try? TempPhotoStore.write(data) else { return }
        path.append(Route.createChild(
            parentId: imageId,
            suggestedTitle: nil,
            rectangleOnParent: nil,
            tempPhotoPath: tempPath
        ))
    }

    private func handleGalleryItem(_ picked: PhotosPickerItem) async {
        defer { galleryPickerItem = nil }
        guard let data = try? await picked.loadTransferable(type: Data.self),
              let tempPath = try? TempPhotoStore.write(data) else { return }
        await MainActor.run {
            path.append(Route.createChild(
                parentId: imageId,
                suggestedTitle: nil,
                rectangleOnParent: nil,
                tempPhotoPath: tempPath
            ))
        }
    }

    #if DEBUG
    private func insertDemoSubSpace() {
        let data = DemoImage.make(label: "Sub")
        guard let tempPath = try? TempPhotoStore.write(data) else { return }
        path.append(Route.createChild(
            parentId: imageId,
            suggestedTitle: "Demo Sub",
            rectangleOnParent: nil,
            tempPhotoPath: tempPath
        ))
    }
    #endif

    // MARK: - ML Kit detection

    private func runDetection() async {
        guard let path = item?.filePath else { return }
        isDetecting = true
        defer { isDetecting = false }
        selectedDetection = nil
        detections = await ObjectDetectionService.detectAndLabel(imagePath: path)
    }

    private func handleDetectedObjectTap(_ detection: DetectedObjectInfo) {
        guard let parentPath = item?.filePath,
              let parentImage = UIImage(contentsOfFile: parentPath) else { return }
        let cropped = cropToBoundingBox(parentImage, box: detection.boundingBox) ?? parentImage
        guard let data = cropped.jpegData(compressionQuality: 0.9),
              let tempPath = try? TempPhotoStore.write(data) else { return }
        self.path.append(Route.createChild(
            parentId: imageId,
            suggestedTitle: detection.label,
            rectangleOnParent: detection.boundingBox,
            tempPhotoPath: tempPath
        ))
    }

    private func cropToBoundingBox(_ image: UIImage, box: Rectangle) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let cropRect = CGRect(
            x: max(0, CGFloat(box.x) * w),
            y: max(0, CGFloat(box.y) * h),
            width: min(w, CGFloat(box.width) * w),
            height: min(h, CGFloat(box.height) * h)
        )
        guard let cropped = cg.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - UpdatedToggleRow

/// Bulletproof toggle pattern after three reported regressions:
///
/// The Toggle is bound to a pure `@State Bool` (`localValue`). User taps
/// flip `localValue` immediately — there is no Binding round-trip through
/// SwiftData that could snap back mid-frame. An `.onChange(of: localValue)`
/// writes the new value to the @Model, saves, and defers the badge refresh
/// to the next runloop tick.
///
/// External mutations (e.g. via swipe action on the main screen) sync the
/// local mirror via `.onChange(of: item.isUpdated)`.
private struct UpdatedToggleRow: View {
    let item: ImageItem
    let modelContext: ModelContext
    @State private var localValue: Bool

    init(item: ImageItem, modelContext: ModelContext) {
        self.item = item
        self.modelContext = modelContext
        self._localValue = State(initialValue: item.isUpdated)
    }

    var body: some View {
        Toggle(isOn: $localValue) {
            Label("Mark as Updated", systemImage: "exclamationmark.circle")
        }
        .tint(.orange)
        .accessibilityIdentifier("updated-toggle")
        .onChange(of: localValue) { _, newValue in
            // Sync local → model.
            guard item.isUpdated != newValue else { return }
            item.isUpdated = newValue
            try? modelContext.save()
            // Defer badge refresh so the toggle animation finishes cleanly.
            DispatchQueue.main.async {
                AppIconBadge.refreshFromCurrentSettings(modelContext: modelContext)
            }
        }
        .onChange(of: item.isUpdated) { _, newValue in
            // Sync model → local (e.g. swipe action on Main screen flipped it).
            if localValue != newValue { localValue = newValue }
        }
    }
}
