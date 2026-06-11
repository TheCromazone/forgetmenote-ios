import SwiftUI
import SwiftData

/// V3 Detail edit sheet — half-modal port of `DetailSheet` from
/// `screens-secondary.jsx`. Edits name / tags / notes / isUpdated for a
/// single `ImageItem` in place, with a danger-styled delete action at the
/// bottom. Bound to the model item via `@Query` filter on the item id;
/// commits via `ImageRepository`'s per-field update methods.
struct V3DetailSheet: View {
    let itemId: String
    /// Invoked on the main actor after a successful delete, so the presenting
    /// screen can pop the now-dangling detail entry off its NavigationStack.
    /// Without this, `dismiss()` only closes the sheet and the parent screen
    /// collapses to its "not found" fallback, stranding the user.
    var onDeleted: (() -> Void)? = nil

    @Environment(\.v3Palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var items: [ImageItem]
    private var item: ImageItem? { items.first }

    @State private var name = ""
    @State private var tagsText = ""
    @State private var notes = ""
    @State private var updated = false
    @State private var loaded = false
    @State private var saving = false
    @State private var confirmDelete = false

    init(itemId: String, onDeleted: (() -> Void)? = nil) {
        self.itemId = itemId
        self.onDeleted = onDeleted
        let id = itemId
        self._items = Query(filter: #Predicate<ImageItem> { $0.id == id })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                handle
                header
                nameCard
                tagsCard
                notesCard
                updatedToggleRow
                deleteButton
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 18)
        }
        .background(palette.paper.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(palette.paper)
        .presentationCornerRadius(24)
        .onAppear(perform: load)
    }

    // MARK: - Load

    private func load() {
        guard !loaded, let i = item else { return }
        loaded = true
        name = i.name
        tagsText = i.tags.joined(separator: ", ")
        notes = i.notes
        updated = i.isUpdated
    }

    // MARK: - Pieces

    @ViewBuilder private var handle: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(palette.line)
                .frame(width: 44, height: 5)
            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    @ViewBuilder private var header: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.ink2)
                .accessibilityIdentifier("v3-detail-cancel")
            Spacer()
            Text("Edit")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(palette.ink)
            Spacer()
            Button(action: save) {
                HStack(spacing: 6) {
                    if saving {
                        ProgressView()
                            .controlSize(.small)
                            .tint(palette.accent)
                    }
                    Text("Save")
                }
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(palette.accent)
            .accessibilityIdentifier("v3-detail-save")
            .disabled(saving)
        }
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    @ViewBuilder private var nameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NAME")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(palette.ink3)
            TextField("Name", text: $name)
                .font(V3Font.headline(32))
                .foregroundStyle(palette.ink)
                .tracking(-0.6)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .accessibilityIdentifier("v3-detail-name")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        .padding(.bottom, 14)
    }

    @ViewBuilder private var tagsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TAGS")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(palette.ink3)
            TextField("comma, separated, tags", text: $tagsText)
                .font(.system(size: 15))
                .foregroundStyle(palette.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("v3-detail-tags")
            if !parsedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(parsedTags, id: \.self) { tag in
                            V3Chip(palette: palette, text: tag)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        .padding(.bottom, 14)
    }

    @ViewBuilder private var notesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOTES")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(palette.ink3)
            TextEditor(text: $notes)
                .font(.system(size: 15))
                .foregroundStyle(palette.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .overlay(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("Add a note…")
                            .font(.system(size: 15))
                            .foregroundStyle(palette.ink3)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityIdentifier("v3-detail-notes")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        .padding(.bottom, 14)
    }

    @ViewBuilder private var updatedToggleRow: some View {
        Button {
            V3Haptics.selection()
            updated.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(updated ? Color(hex: 0x3D2A0E) : palette.accent)
                    .frame(width: 32, height: 32)
                    .background(updated ? palette.pollen : palette.accentBg,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(updated ? "Recently refreshed" : "Mark as refreshed")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.ink)
                    Text("Highlights this place so you can find what changed.")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.ink3)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                V3Switch(palette: palette, isOn: updated)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(SwiftUI.Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("v3-detail-updated-toggle")
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        .padding(.bottom, 14)
    }

    @ViewBuilder private var deleteButton: some View {
        Button {
            confirmDelete = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                Text("Delete this place")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(palette.danger)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.danger.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("v3-detail-delete")
        .alert("Delete \(item?.name ?? "this place")?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: confirmDeleteAction)
        } message: {
            Text("This removes the place and everything inside it. Cannot be undone.")
        }
    }

    // MARK: - Derived

    private var parsedTags: [String] {
        tagsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Actions

    private func save() {
        guard !saving else { return }
        saving = true
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let finalName = trimmedName.isEmpty ? "Untitled" : trimmedName
        let tagList = parsedTags
        let nextNotes = notes
        let nextUpdated = updated
        let id = itemId
        let container = modelContext.container
        Task {
            let repo = ImageRepository(modelContainer: container)
            try? await repo.updateName(itemId: id, name: finalName)
            try? await repo.updateTags(itemId: id, tags: tagList)
            try? await repo.updateNotes(itemId: id, notes: nextNotes)
            try? await repo.setUpdated(itemId: id, value: nextUpdated)
            await MainActor.run {
                saving = false
                V3Haptics.success()
                dismiss()
            }
        }
    }

    private func confirmDeleteAction() {
        let id = itemId
        let container = modelContext.container
        Task {
            let repo = ImageRepository(modelContainer: container)
            try? await repo.delete(itemId: id, strategy: .deleteAllChildren)
            await MainActor.run {
                V3Haptics.warning()
                dismiss()
                // Pop the underlying detail screen one runloop AFTER the sheet
                // dismissal — dismissing + popping in the same runloop races in
                // SwiftUI and can leave the dead detail entry on the stack.
                if let onDeleted {
                    DispatchQueue.main.async { onDeleted() }
                }
            }
        }
    }
}
