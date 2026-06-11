import SwiftUI
import SwiftData

struct V4FindScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var path: NavigationPath
    @Query(sort: \ImageItem.createdAt, order: .reverse) private var allItems: [ImageItem]
    @State private var query = ""
    @State private var pendingDelete: V4DeleteRequest?
    @State private var deleteError: String?

    private var results: [ImageItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }
        return allItems.filter { item in
            item.name.lowercased().contains(trimmed) ||
            item.notes.lowercased().contains(trimmed) ||
            item.tags.contains { $0.lowercased().contains(trimmed) }
        }
    }

    private var tags: [String] {
        Array(Set(allItems.flatMap(\.tags))).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Search the map")
                    .v4SmallCaps(V4.cyan)
                    .padding(.horizontal, 22)
                    .padding(.top, 64)
                Text("Find anything\nby memory trail.")
                    .font(V4.title(40))
                    .foregroundStyle(V4.ink)
                    .lineSpacing(-2)
                    .padding(.horizontal, 22)
                    .padding(.top, 8)

                searchBar
                    .padding(.top, 22)

                if query.isEmpty {
                    tagCloud
                        .padding(.top, 28)
                    suggestions
                        .padding(.top, 24)
                } else {
                    Text("\(results.count) \(results.count == 1 ? "match" : "matches")")
                        .v4SmallCaps()
                        .padding(.horizontal, 22)
                        .padding(.top, 24)
                    VStack(spacing: 10) {
                        ForEach(results, id: \.id) { item in
                            resultRow(item, isFirstResult: item.id == results.first?.id)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                }
                Spacer(minLength: 112)
            }
        }
        .scrollIndicators(.hidden)
        .background(V4.background)
        .confirmationDialog(
            pendingDelete?.title ?? "Delete?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(pendingDelete?.actionTitle ?? "Delete", role: .destructive) {
                deletePendingItem()
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(pendingDelete?.message ?? "")
        }
        .alert("Could not delete", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(V4.blue)
            TextField("blue bin, passport, charger", text: $query)
                .foregroundStyle(V4.ink)
                .font(.system(size: 16, weight: .semibold))
                .submitLabel(.search)
                .accessibilityIdentifier("v4-search-input")
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(V4.ink3)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(V4.panel, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(V4.blue.opacity(0.28), lineWidth: 1)
        )
        .padding(.horizontal, 22)
    }

    private var tagCloud: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(V4.title(24))
                .foregroundStyle(V4.ink)
                .padding(.horizontal, 22)
            if tags.isEmpty {
                V4EmptyState(title: "No tags yet", message: "Tags will appear here once you add them to places.")
                    .padding(.horizontal, 22)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(tags.prefix(18), id: \.self) { tag in
                            Button { query = tag } label: {
                                Text("#\(tag)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(V4.ink)
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 9)
                                    .background(V4.panel2, in: Capsule())
                                    .overlay(Capsule().stroke(V4.line, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 22)
                }
            }
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try")
                .font(V4.title(24))
                .foregroundStyle(V4.ink)
            ForEach(["keys", "medicine", "cables"], id: \.self) { term in
                Button { query = term } label: {
                    HStack {
                        Image(systemName: "scope")
                            .foregroundStyle(V4.cyan)
                        Text(term)
                            .foregroundStyle(V4.ink)
                            .font(.system(size: 15, weight: .bold))
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .foregroundStyle(V4.ink3)
                    }
                    .padding(14)
                    .background(V4.panel.opacity(0.82), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(V4.line, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
    }

    private func resultRow(_ item: ImageItem, isFirstResult: Bool) -> some View {
        HStack(spacing: 10) {
            Button {
                if item.isRoom {
                    path.append(V4Route(kind: .room(item.id)))
                } else {
                    path.append(V4Route(kind: .imageDetail(item.id)))
                }
            } label: {
                HStack(spacing: 12) {
                    if let p = item.filePath, let image = UIImage(contentsOfFile: p) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    } else {
                        let hue = V4.hue(for: item.id)
                        Text(item.name.prefix(1).uppercased())
                            .font(V4.title(25))
                            .foregroundStyle(hue.fg)
                            .frame(width: 54, height: 54)
                            .background(hue.bg, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(V4.ink)
                            .lineLimit(1)
                        Text(item.isRoom ? "Room" : item.tags.prefix(2).map { "#\($0)" }.joined(separator: " "))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(V4.ink3)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(V4.ink3)
                }
                .padding(12)
                .background(V4.panel, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(V4.line, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(isFirstResult ? "v4-search-first-result" : "v4-search-result-\(item.id)")

            V4DeleteBadgeButton(
                accessibilityIdentifier: isFirstResult ? "v4-delete-search-first-result" : "v4-delete-search-result-\(item.id)"
            ) {
                    pendingDelete = deleteRequest(for: item)
                }
        }
    }

    private func deleteRequest(for item: ImageItem) -> V4DeleteRequest {
        V4DeleteRequest(
            itemId: item.id,
            name: item.name,
            isRoom: item.isRoom,
            descendantCount: descendantCount(for: item.id)
        )
    }

    private func descendantCount(for itemId: String) -> Int {
        let direct = allItems.filter { $0.parentId == itemId }
        return direct.reduce(direct.count) { $0 + descendantCount(for: $1.id) }
    }

    private func deletePendingItem() {
        guard let request = pendingDelete else { return }
        let container = modelContext.container
        Task {
            do {
                let repo = ImageRepository(modelContainer: container)
                try await repo.delete(itemId: request.itemId, strategy: .deleteAllChildren)
                await MainActor.run { pendingDelete = nil }
            } catch {
                await MainActor.run { deleteError = error.localizedDescription }
            }
        }
    }
}

struct V4YouScreen: View {
    @Binding var path: NavigationPath
    var onNewRoom: () -> Void
    var onShowWalkthrough: () -> Void
    var onSignOut: () -> Void

    @Query(sort: \ImageItem.createdAt, order: .reverse) private var allItems: [ImageItem]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Operator")
                    .v4SmallCaps(V4.cyan)
                    .padding(.horizontal, 22)
                    .padding(.top, 64)
                Text("Your memory\nsystem.")
                    .font(V4.title(42))
                    .foregroundStyle(V4.ink)
                    .lineSpacing(-2)
                    .padding(.horizontal, 22)
                    .padding(.top, 8)

                HStack(spacing: 10) {
                    stat("\(allItems.count)", "items", V4.blue)
                    stat("\(allItems.filter(\.isRoom).count)", "rooms", V4.leaf)
                    stat("\(Set(allItems.flatMap(\.tags)).count)", "tags", V4.pollen)
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)

                VStack(spacing: 10) {
                    action("New room", "plus.square.fill", accessibilityID: "v4-you-new-room", onNewRoom)
                    action("Settings", "gearshape.fill", accessibilityID: "v4-you-settings") { path.append(V4Route(kind: .settings)) }
                    action("Help", "questionmark.circle.fill", accessibilityID: "v4-you-help") { path.append(V4Route(kind: .help)) }
                    action("Show walkthrough", "info.bubble.fill", accessibilityID: "v4-you-walkthrough", onShowWalkthrough)
                    action("Sign out", "rectangle.portrait.and.arrow.right", accessibilityID: "v4-you-signout", onSignOut)
                }
                .padding(.horizontal, 22)
                .padding(.top, 28)

                Spacer(minLength: 112)
            }
        }
        .scrollIndicators(.hidden)
        .background(V4.background)
    }

    private func stat(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(V4.title(28))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(V4.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(V4.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(V4.line, lineWidth: 1)
        )
    }

    private func action(_ title: String, _ icon: String, accessibilityID: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(V4.cyan)
                    .frame(width: 34, height: 34)
                    .background(V4.panel2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(V4.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(V4.ink3)
            }
            .padding(14)
            .background(V4.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(V4.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }
}

struct V4CaptureSheet: View {
    var onClose: () -> Void
    var onNewRoom: () -> Void
    var onCaptureIn: (String) -> Void
    var onDemoIn: (String) -> Void

    @Query(filter: #Predicate<ImageItem> { $0.parentId == nil },
           sort: \ImageItem.createdAt) private var rootItems: [ImageItem]

    private var rooms: [ImageItem] { rootItems.filter(\.isRoom) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Capture")
                    .v4SmallCaps(V4.cyan)
                Text("Where should\nthis live?")
                    .font(V4.title(34))
                    .foregroundStyle(V4.ink)
                    .lineSpacing(-1)
                    .padding(.top, 6)

                Button(action: onNewRoom) {
                    Label("Make a new room", systemImage: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(hex: 0x07101E))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(V4.pollen, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 20)

                Text("Add to a room")
                    .v4SmallCaps()
                    .padding(.top, 24)

                VStack(spacing: 10) {
                    ForEach(rooms, id: \.id) { room in
                        roomRow(room, isFirstRoom: room.id == rooms.first?.id)
                    }
                }
                .padding(.top, 10)
            }
            .padding(22)
        }
        .scrollIndicators(.hidden)
        .background(V4.background)
    }

    private func roomRow(_ room: ImageItem, isFirstRoom: Bool) -> some View {
        let hue = V4.hue(for: room.id)
        return HStack(spacing: 12) {
            Text(room.name.prefix(1).uppercased())
                .font(V4.title(24))
                .foregroundStyle(hue.fg)
                .frame(width: 46, height: 46)
                .background(hue.bg, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            Text(room.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(V4.ink)
            Spacer()
            Button {
                onDemoIn(room.id)
            } label: {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(V4.pollen)
                    .frame(width: 38, height: 38)
                    .background(V4.panel2, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(isFirstRoom ? "v4-capture-demo-first-room" : "v4-capture-demo-room-\(room.id)")
            Button {
                onCaptureIn(room.id)
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: 0x07101E))
                    .frame(width: 38, height: 38)
                    .background(V4.cyan, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(isFirstRoom ? "v4-capture-camera-first-room" : "v4-capture-camera-room-\(room.id)")
        }
        .padding(12)
        .background(V4.panel, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(V4.line, lineWidth: 1)
        )
        .accessibilityIdentifier(isFirstRoom ? "v4-capture-first-room" : "v4-capture-room-\(room.id)")
    }
}

struct V4NewRoomSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedHue = 0
    @State private var error: String?
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New room")
                .v4SmallCaps(V4.cyan)
            Text("What place should\nwe remember?")
                .font(V4.title(34))
                .foregroundStyle(V4.ink)
                .lineSpacing(-1)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 10) {
                Text("Place name")
                    .font(.system(size: 12, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.1)
                    .foregroundStyle(Color(hex: 0x655F52))

                TextField(
                    text: $name,
                    prompt: Text("Hall closet, desk drawer, top shelf")
                        .foregroundStyle(Color(hex: 0x7F7666).opacity(0.78))
                ) {
                    Text("Place name")
                }
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: 0x171814))
                .tint(Color(hex: 0x2F6C76))
                .submitLabel(.done)
                .focused($nameFocused)
                .accessibilityIdentifier("v4-new-room-name")
            }
            .padding(15)
            .background(V4.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(nameFocused ? V4.cyan.opacity(0.82) : .white.opacity(0.22), lineWidth: nameFocused ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
            .padding(.top, 22)

            Text("Start broad, then add photos inside it later.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(V4.ink3)
                .padding(.top, 20)

            HStack(spacing: 10) {
                ForEach(Array(V4.roomHues.enumerated()), id: \.offset) { idx, hue in
                    Circle()
                        .fill(hue.bg)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(idx == selectedHue ? V4.ink : .white.opacity(0.2), lineWidth: idx == selectedHue ? 3 : 1))
                        .onTapGesture { selectedHue = idx }
                }
            }
            .padding(.top, 18)

            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(V4.coral)
                    .padding(.top, 12)
            }

            Spacer()

            Button {
                Task { await save() }
            } label: {
                Text("Create room")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: 0x07101E))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(V4.cyan, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            .accessibilityIdentifier("v4-create-room")
        }
        .padding(22)
        .background(V4.background)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                nameFocused = true
            }
        }
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let hue = V4.roomHues[selectedHue]
        let repo = ImageRepository(modelContainer: modelContext.container)
        do {
            _ = try await repo.createRoom(
                name: trimmed,
                tags: [],
                backgroundColor: hue.bg.argbInt64,
                textColor: hue.fg.argbInt64
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
