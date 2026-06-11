import SwiftUI
import SwiftData

/// Real Phase-2 implementation of the create-child workflow.
///
/// Two layouts:
/// - Parent is a **Room** (no photo): simple form with photo preview, name, tags.
/// - Parent is a **Space** (has photo): photo preview + parent image with interactive
///   rectangle selector + name/tags fields.
struct CreateChildScreen: View {
    let parentId: String
    let suggestedTitle: String?
    let initialRectangleOnParent: Rectangle?
    let tempPhotoPath: String?
    @Binding var path: NavigationPath

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var parentMatches: [ImageItem]

    @State private var name: String
    @State private var tagsText: String = ""
    @State private var rectangle: Rectangle
    @State private var photoData: Data?
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    /// True if the name field came from ML Kit auto-labeling and the user
    /// hasn't touched it yet — display dimmed per FR-CA-003.
    @State private var nameIsAutoFilled: Bool = false
    @State private var autoLabelTask: Task<Void, Never>?

    init(
        parentId: String,
        suggestedTitle: String?,
        rectangleOnParent: Rectangle?,
        tempPhotoPath: String?,
        path: Binding<NavigationPath>
    ) {
        self.parentId = parentId
        self.suggestedTitle = suggestedTitle
        self.initialRectangleOnParent = rectangleOnParent
        self.tempPhotoPath = tempPhotoPath
        self._path = path
        let pid = parentId
        self._parentMatches = Query(filter: #Predicate<ImageItem> { $0.id == pid })
        self._name = State(initialValue: suggestedTitle ?? "")
        // Default to a centered 30% × 30% rectangle when not provided.
        self._rectangle = State(initialValue: rectangleOnParent
            ?? Rectangle(x: 0.35, y: 0.35, width: 0.30, height: 0.30))
    }

    private var parent: ImageItem? { parentMatches.first }
    private var parentIsRoom: Bool { parent?.isRoom ?? true }
    private var parentImage: UIImage? {
        guard let path = parent?.filePath else { return nil }
        return UIImage(contentsOfFile: path)
    }
    private var capturedImage: UIImage? {
        guard let data = photoData else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                photoPreview
                if !parentIsRoom, let parentImage {
                    parentImageWithSelector(parentImage)
                }
                formFields
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                actionButtons
            }
            .padding()
        }
        .navigationTitle("New \(parentIsRoom ? "Sub-Item" : "Sub-Space")")
        .navigationBarTitleDisplayMode(.inline)
        .customBackButton()
        .onAppear(perform: loadPhoto)
        .onDisappear {
            autoLabelTask?.cancel()
            // Caller paths that bypass OK/Cancel — purge the temp photo.
            if !isSaving { TempPhotoStore.remove(tempPhotoPath) }
        }
    }

    // MARK: - Sections

    @ViewBuilder private var photoPreview: some View {
        if let capturedImage {
            VStack(alignment: .leading, spacing: 6) {
                Text("New photo").font(.caption).foregroundStyle(.secondary)
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("New photo").font(.caption).foregroundStyle(.secondary)
                ContentUnavailableView("No photo",
                                       systemImage: "photo",
                                       description: Text("Photo data missing. Go back and re-capture."))
                    .frame(maxHeight: 140)
            }
        }
    }

    @ViewBuilder
    private func parentImageWithSelector(_ parentImage: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Where on \"\(parent?.name ?? "parent")\"?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            InteractiveRectangleSelector(
                image: parentImage,
                rect: $rectangle,
                existingChildren: parent?.childIds.compactMap { childId in
                    let descriptor = FetchDescriptor<ImageItem>(predicate: #Predicate<ImageItem> { $0.id == childId })
                    return try? modelContext.fetch(descriptor).first?.rectangleOnParent
                } ?? []
            )
            .frame(height: 300)
            .background(Color(.systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder private var formFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Name").font(.caption).foregroundStyle(.secondary)
                    if nameIsAutoFilled {
                        Text("(auto-detected)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                TextField("Required", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(nameIsAutoFilled ? .secondary : .primary)
                    .onChange(of: name) { _, _ in
                        // Once the user types, the value is no longer auto-filled.
                        if nameIsAutoFilled { nameIsAutoFilled = false }
                    }
                    .accessibilityIdentifier("name-field")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Tags (comma-separated)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. tools, electronics", text: $tagsText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("tags-field")
            }
        }
    }

    @ViewBuilder private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(role: .cancel) {
                TempPhotoStore.remove(tempPhotoPath)
                dismiss()
            } label: {
                Text("Cancel").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("cancel-button")

            Button {
                Task { await save() }
            } label: {
                if isSaving {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("OK").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || photoData == nil || isSaving)
            .accessibilityIdentifier("ok-button")
        }
    }

    // MARK: - Actions

    private func loadPhoto() {
        guard let tempPhotoPath else { return }
        photoData = TempPhotoStore.read(tempPhotoPath)
        kickOffAutoLabeling()
    }

    /// Run ML Kit Image Labeling in the background. If the name field is still
    /// empty (or the user hasn't typed) when the result arrives, pre-fill it
    /// with the top label. Matches Android FR-CA-001/002/003.
    private func kickOffAutoLabeling() {
        // Skip if a suggested title was already provided by the caller (e.g.
        // the debug "Demo Sub" button) — that takes precedence.
        guard name.isEmpty, let tempPhotoPath else { return }
        autoLabelTask?.cancel()
        autoLabelTask = Task { @MainActor in
            let suggested = await ImageLabelingService.generateTitle(imagePath: tempPhotoPath)
            // Bail out if the user has started typing in the meantime.
            guard !Task.isCancelled, name.isEmpty, let suggested else { return }
            name = suggested
            nameIsAutoFilled = true
        }
    }

    private func save() async {
        guard let photoData else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let parsedTags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let repo = ImageRepository(modelContainer: modelContext.container)
        do {
            _ = try await repo.saveImage(
                jpegData: photoData,
                name: name.trimmingCharacters(in: .whitespaces),
                tags: parsedTags,
                parentId: parentId,
                rectangleOnParent: parentIsRoom ? nil : rectangle
            )
            TempPhotoStore.remove(tempPhotoPath)
            isSaving = false
            dismiss()
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}
