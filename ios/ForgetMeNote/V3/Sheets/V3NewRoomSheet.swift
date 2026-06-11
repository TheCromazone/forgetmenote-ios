import SwiftUI
import SwiftData

/// V3 New Room sheet — half-modal that creates a brand new top-level room.
///
/// Layout:
///   - drag handle
///   - header: "Cancel" / "New room" / "Create"
///   - serif headline "Name your room."
///   - 2-column hue picker (6 palette hues; selected gets accent border + check)
///   - "ROOM NAME" text field card with .words autocapitalization
///
/// On Create, persists via `ImageRepository.createRoom(name:tags:parentId:backgroundColor:textColor:)`
/// with the selected hue packed into Int64 ARGB so the home grid renders the
/// user's chosen color rather than the deterministic-from-id fallback.
struct V3NewRoomSheet: View {
    @Environment(\.v3Palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedIndex: Int = 0
    @State private var creating = false
    @State private var detent: PresentationDetent = .medium
    @FocusState private var nameFocused: Bool

    private var hues: [V3Hue] { palette.hues }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    handle
                    header
                    title
                    huePicker
                    nameField
                        .id("v3-newroom-name-anchor")
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 18)
            }
            .onChange(of: nameFocused) { _, focused in
                // Keyboard can occlude the name field — grow the sheet to .large
                // and scroll the field into view when it gains focus.
                guard focused else { return }
                detent = .large
                withAnimation {
                    proxy.scrollTo("v3-newroom-name-anchor", anchor: .center)
                }
            }
        }
        .background(palette.paper.ignoresSafeArea())
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.hidden)
        .presentationBackground(palette.paper)
        .presentationCornerRadius(24)
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
                .accessibilityIdentifier("v3-newroom-cancel")
            Spacer()
            Text("New room")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(palette.ink)
            Spacer()
            Button("Create", action: create)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(canCreate ? palette.accent : palette.ink3)
                .disabled(!canCreate || creating)
                .accessibilityIdentifier("v3-newroom-create")
        }
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    @ViewBuilder private var title: some View {
        (Text("Name your ")
            .font(V3Font.headline(30))
            .foregroundStyle(palette.ink) +
         Text("room.")
            .font(V3Font.headline(30, italic: true))
            .italic()
            .foregroundStyle(palette.accent))
            .tracking(-0.5)
            .padding(.bottom, 18)
    }

    @ViewBuilder private var huePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PICK A COLOR")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(palette.ink3)
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10),
                          GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(Array(hues.enumerated()), id: \.offset) { idx, hue in
                    hueTile(idx: idx, hue: hue)
                }
            }
        }
        .padding(.bottom, 18)
    }

    @ViewBuilder private func hueTile(idx: Int, hue: V3Hue) -> some View {
        let isSelected = idx == selectedIndex
        Button {
            selectedIndex = idx
        } label: {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    hue.bg
                    GeometryReader { geo in
                        Circle()
                            .fill(hue.fg.opacity(0.10))
                            .frame(width: geo.size.width * 0.7,
                                   height: geo.size.width * 0.7)
                            .offset(x: geo.size.width * 0.5,
                                    y: -geo.size.width * 0.25)
                    }
                    Text(hue.name.capitalized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(hue.fg)
                        .padding(12)
                }
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(hue.bg)
                        .frame(width: 22, height: 22)
                        .background(Color.white, in: Circle())
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                        .padding(8)
                }
            }
            .frame(height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? palette.accent : Color.clear, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("v3-newroom-hue-\(idx)")
    }

    @ViewBuilder private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ROOM NAME")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(palette.ink3)
            TextField("Living room", text: $name)
                .font(V3Font.headline(28))
                .foregroundStyle(palette.ink)
                .tracking(-0.5)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($nameFocused)
                .onSubmit(create)
                .accessibilityIdentifier("v3-newroom-name")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
    }

    // MARK: - Derived

    private var canCreate: Bool { !trimmedName.isEmpty }

    // MARK: - Action

    private func create() {
        guard canCreate, !creating else { return }
        creating = true
        let chosenHue = hues[selectedIndex]
        // Pack the selected hue's bg/fg into ARGB Int64 and persist them on the
        // model. The chosen color IS applied on the home grid — V3Theme.hue(for:)
        // reads these stored colors back when rendering the room tile.
        let bgInt64 = chosenHue.bg.argbInt64
        let fgInt64 = chosenHue.fg.argbInt64
        let finalName = trimmedName
        let container = modelContext.container

        Task {
            let repo = ImageRepository(modelContainer: container)
            _ = try? await repo.createRoom(
                name: finalName,
                tags: [],
                parentId: nil,
                backgroundColor: bgInt64,
                textColor: fgInt64
            )
            await MainActor.run {
                creating = false
                V3Haptics.success()
                dismiss()
            }
        }
    }
}
