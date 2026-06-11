import SwiftUI
import SwiftData

/// V3 create-sub-space screen. Shows the parent photo with an OPTIONAL crop box
/// (off by default, revealed by a button) whose four corners drag to fit the
/// spot. Save commits a new ImageItem under `parentId`: with a photo when one
/// was captured, otherwise a rectangle-anchored sub-space (or a plain sub-room
/// when cropping is off).
struct V3CreateSubScreen: View {
    let parentId: String
    let tempPhotoPath: String?
    let suggestedRect: Rectangle?
    let suggestedTitle: String?
    @Binding var path: NavigationPath

    @Environment(\.v3Palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var parents: [ImageItem]
    @Query private var allItems: [ImageItem]
    private var parent: ImageItem? { parents.first }

    private var byId: [String: ImageItem] {
        Dictionary(allItems.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }
    /// The parent's photo slice (own photo OR cropped ancestor region) — the
    /// backdrop we mark on. Lets you trace/crop objects on a traced shelf.
    private var parentRegion: V3Region? {
        parent.flatMap { V3RegionResolver.region(for: $0, byId: byId) }
    }

    enum MarkMode { case crop, trace }

    @State private var rect: Rectangle
    @State private var cropEnabled: Bool
    @State private var markMode: MarkMode = .crop
    @State private var trace = TracePath(points: [])
    @State private var name: String
    @State private var tagsText: String = ""
    @State private var saving = false
    @State private var autoLabeling = false
    @State private var errorMessage: String?
    @State private var displayImage: UIImage?

    init(parentId: String, tempPhotoPath: String?,
         suggestedRect: Rectangle? = nil, suggestedTitle: String? = nil,
         path: Binding<NavigationPath>) {
        self.parentId = parentId
        self.tempPhotoPath = tempPhotoPath
        self.suggestedRect = suggestedRect
        self.suggestedTitle = suggestedTitle
        self._path = path
        let id = parentId
        self._parents = Query(filter: #Predicate<ImageItem> { $0.id == id })
        self._allItems = Query(sort: \ImageItem.createdAt)
        _rect = State(initialValue: suggestedRect ?? Rectangle(x: 0.25, y: 0.30, width: 0.50, height: 0.40))
        _cropEnabled = State(initialValue: suggestedRect != nil)
        _name = State(initialValue: suggestedTitle ?? "")
    }

    private var parentName: String { parent?.name ?? "" }
    private var hasCroppablePhoto: Bool { tempPhotoPath != nil || parentRegion != nil }

    var body: some View {
        VStack(spacing: 0) {
            V3NavHeader(
                palette: palette,
                title: "Mark a spot",
                subtitle: parentName.isEmpty ? nil : "in \(parentName)",
                onBack: { dismiss() }
            ) {
                Button(action: save) {
                    if saving {
                        ProgressView()
                            .controlSize(.small)
                            .tint(palette.ink3)
                    } else {
                        Text("Save")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(palette.accent)
                    }
                }
                .buttonStyle(.plain)
                .disabled(saving)
                .accessibilityIdentifier("v3-create-sub-save")
            }

            // The photo + crop overlay is PINNED (outside the ScrollView) so the
            // scroll never steals the corner/resize/pinch drags. Only the form
            // below scrolls.
            photoArea
                .padding(.horizontal, 16)
                .padding(.top, 6)

            if hasCroppablePhoto {
                cropToggleButton
                    .padding(.top, 10)
                if cropEnabled {
                    markModeToggle
                        .padding(.top, 10)
                    Text(markMode == .crop
                         ? "Drag a corner to resize · drag inside to move · pinch to zoom"
                         : "Drag your finger around the object to trace its shape")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.ink3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            ScrollView {
                VStack(spacing: 0) {
                    fieldsCard
                        .padding(.horizontal, 16)
                        .padding(.top, 18)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(palette.danger)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 80)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(palette.paper.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // A freehand outline drawn on the space screen arrives via the
            // one-shot stash (the shared Route enum can't carry it). Open
            // straight in trace mode with the drawn shape so nothing is lost.
            if suggestedRect != nil, let pending = V3PendingTrace.consume() {
                markMode = .trace
                trace = pending
            }
        }
        .task(id: parent?.id) {
            await loadDisplayImage()
            await autoLabelIfNeeded()
        }
    }

    /// After a fresh capture with no name yet, ask on-device ML for a name
    /// (mirrors v4). Only fills the field if the user still hasn't typed.
    private func autoLabelIfNeeded() async {
        guard let tempPath = tempPhotoPath,
              suggestedTitle == nil,
              name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        await MainActor.run { autoLabeling = true }
        let suggestion = await V3VisionService.suggestName(imagePath: tempPath)
        await MainActor.run {
            autoLabeling = false
            if let suggestion, !suggestion.isEmpty,
               name.trimmingCharacters(in: .whitespaces).isEmpty {
                name = suggestion
            }
        }
    }

    private func loadDisplayImage() async {
        let img: UIImage?
        if let tempPhotoPath {
            img = V3ImageDownsampler.downsample(path: tempPhotoPath)
        } else if let region = parentRegion {
            // Marking a spot on a region parent (e.g. objects on a traced shelf):
            // backdrop is the cropped slice of the ancestor photo.
            img = await V3RegionImage.load(region, maxPixelSize: 1600)
        } else {
            img = nil
        }
        await MainActor.run { displayImage = img }
    }

    @ViewBuilder private var photoArea: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let rx = CGFloat(rect.x) * w, ry = CGFloat(rect.y) * h
            let rw = CGFloat(rect.width) * w, rh = CGFloat(rect.height) * h

            ZStack(alignment: .topLeading) {
                Group {
                    if let img = displayImage {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        palette.paperEdge.overlay(
                            Text(parentName.trimmingCharacters(in: .whitespaces).prefix(1).uppercased())
                                .font(V3Font.display(120)).foregroundStyle(palette.ink3))
                    }
                }
                .frame(width: w, height: h)
                .clipped()

                if cropEnabled && hasCroppablePhoto {
                    if markMode == .crop {
                        Group {
                            SwiftUI.Rectangle().fill(.black.opacity(0.45)).frame(width: w, height: ry)
                            SwiftUI.Rectangle().fill(.black.opacity(0.45))
                                .frame(width: w, height: max(0, h - (ry + rh))).offset(y: ry + rh)
                            SwiftUI.Rectangle().fill(.black.opacity(0.45))
                                .frame(width: rx, height: rh).offset(y: ry)
                            SwiftUI.Rectangle().fill(.black.opacity(0.45))
                                .frame(width: max(0, w - (rx + rw)), height: rh).offset(x: rx + rw, y: ry)
                        }
                        .allowsHitTesting(false)

                        V3CropBox(palette: palette, rect: $rect, size: geo.size)
                    } else {
                        V3TraceBox(palette: palette, trace: $trace, size: geo.size)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
    }

    @ViewBuilder private var cropToggleButton: some View {
        Button {
            if !cropEnabled { V3Haptics.impact(.medium) }
            withAnimation(.easeOut(duration: 0.2)) { cropEnabled.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: cropEnabled ? "xmark.circle" : "viewfinder")
                    .font(.system(size: 14, weight: .bold))
                Text(cropEnabled ? "Don't mark a spot" : "Mark the exact spot ✦")
                    .font(.system(size: 14, weight: .semibold)).tracking(-0.1)
            }
            .foregroundStyle(palette.accent)
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(palette.accentBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("v3-create-sub-crop-toggle")
    }

    @ViewBuilder private var markModeToggle: some View {
        HStack {
            Spacer()
            HStack(spacing: 4) {
                modeButton(.crop, icon: "rectangle.dashed", label: "Box")
                modeButton(.trace, icon: "scribble.variable", label: "Trace")
            }
            .padding(3)
            .background(palette.paperEdge, in: Capsule())
            Spacer()
        }
    }

    private func modeButton(_ mode: MarkMode, icon: String, label: String) -> some View {
        Button {
            if markMode != mode { V3Haptics.selection() }
            withAnimation(.easeOut(duration: 0.15)) { markMode = mode }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(markMode == mode ? palette.ink : palette.ink3)
            .padding(.horizontal, 14).frame(height: 32)
            .background(markMode == mode ? palette.surface : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("v3-create-sub-mode-\(label.lowercased())")
    }

    @ViewBuilder private var fieldsCard: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text("NAME").font(.system(size: 11, weight: .bold)).tracking(0.6)
                        .foregroundStyle(palette.ink3)
                    if autoLabeling {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .bold))
                            Text("Naming…").font(.system(size: 11, weight: .semibold)).tracking(0.2)
                        }
                        .foregroundStyle(palette.accent)
                        .accessibilityIdentifier("v3-create-sub-naming")
                    }
                }
                TextField("e.g. Bay leaf tin", text: $name)
                    .font(V3Font.headline(24)).foregroundStyle(palette.ink)
                    .textInputAutocapitalization(.words).submitLabel(.done)
                    .accessibilityIdentifier("v3-create-sub-name")
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)

            SwiftUI.Rectangle().fill(palette.line).frame(height: 1).padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 4) {
                Text("TAGS").font(.system(size: 11, weight: .bold)).tracking(0.6)
                    .foregroundStyle(palette.ink3)
                TextField("optional · comma, separated", text: $tagsText)
                    .font(.system(size: 15)).foregroundStyle(palette.ink).submitLabel(.done)
                    .accessibilityIdentifier("v3-create-sub-tags")
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }

    private func save() {
        guard !saving else { return }
        saving = true
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let finalName = trimmedName.isEmpty ? "Untitled" : trimmedName
        let tagList = tagsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        // Resolve the marked region: a freehand trace (its bounding box feeds the
        // nesting pipeline) or a rectangle, or nothing when marking is off.
        let savedRect: Rectangle?
        let savedTrace: TracePath?
        if cropEnabled {
            if markMode == .trace, trace.points.count >= 3 {
                savedTrace = trace
                savedRect = trace.boundingBox
            } else {
                savedTrace = nil
                savedRect = rect
            }
        } else {
            savedRect = nil
            savedTrace = nil
        }

        Task {
            let repo = ImageRepository(modelContainer: modelContext.container)
            do {
                if let tempPath = tempPhotoPath,
                   let data = try? Data(contentsOf: URL(fileURLWithPath: tempPath)) {
                    _ = try await repo.saveImage(
                        jpegData: data, name: finalName, tags: tagList,
                        parentId: parentId, rectangleOnParent: savedRect,
                        traceOnParent: savedTrace)
                    TempPhotoStore.remove(tempPath)
                } else if savedRect != nil {
                    _ = try await repo.createSubSpace(
                        name: finalName, tags: tagList,
                        parentId: parentId, rectangleOnParent: savedRect,
                        traceOnParent: savedTrace)
                } else {
                    _ = try await repo.createRoom(
                        name: finalName, tags: tagList, parentId: parentId,
                        backgroundColor: nil, textColor: nil)
                }
                await MainActor.run {
                    saving = false
                    V3Haptics.success()
                    if !path.isEmpty { path.removeLast() } else { dismiss() }
                }
            } catch {
                await MainActor.run {
                    saving = false
                    errorMessage = "Save failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
