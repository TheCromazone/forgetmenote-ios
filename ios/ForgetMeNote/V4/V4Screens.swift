import SwiftUI
import SwiftData

struct V4HomeScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var path: NavigationPath
    var onCapture: () -> Void
    var onNewRoom: () -> Void

    @State private var appeared = false
    @State private var heroBreath = false
    @State private var pendingDelete: V4DeleteRequest?
    @State private var deleteError: String?

    @Query(sort: \ImageItem.createdAt, order: .reverse) private var allItems: [ImageItem]
    @Query(filter: #Predicate<ImageItem> { $0.parentId == nil },
           sort: \ImageItem.createdAt) private var rootItems: [ImageItem]

    private var rooms: [ImageItem] { rootItems.filter(\.isRoom) }
    private var recentPlaces: [ImageItem] { Array(allItems.filter { !$0.isRoom }.prefix(6)) }
    private var updatedCount: Int { allItems.filter(\.isUpdated).count }
    private var firstRoomId: String? { rooms.first?.id }
    private var newestRoomId: String? { rooms.max { $0.createdAt < $1.createdAt }?.id }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)
                sectionHeader("Rooms", actionTitle: "New", action: onNewRoom)
                    .padding(.top, 18)
                    .opacity(appeared ? 1 : 0)
                roomGrid
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                memoryStrip
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 18)
                if !recentPlaces.isEmpty {
                    sectionHeader("Recent places")
                        .padding(.top, 30)
                    recentGrid
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
        .onAppear {
            guard !appeared else { return }
            withAnimation(.spring(response: 0.72, dampingFraction: 0.86).delay(0.12)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 6.5).repeatForever(autoreverses: true)) {
                heroBreath = true
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                Image("V4HeroDrawer")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 258)
                    .scaleEffect(heroBreath ? 1.035 : 1.0)
                    .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.16), .black.opacity(0.18), .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("ForgetMeNote v4")
                        .v4SmallCaps(V4.paper)
                    Text("Every place, quietly remembered.")
                        .font(V4.title(38))
                        .foregroundStyle(V4.ink)
                        .lineSpacing(-1)
                        .frame(maxWidth: 285, alignment: .leading)
                    Text("Photograph a shelf, drawer, box, or room, then make its contents searchable by where they actually live.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(V4.ink2)
                        .lineSpacing(3)
                        .frame(maxWidth: 310, alignment: .leading)
                }
                .padding(20)

            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.34), radius: 28, y: 18)

            HStack(spacing: 10) {
                metric("\(allItems.count)", "memories", V4.blue)
                metric("\(rooms.count)", "rooms", V4.leaf)
                metric("\(updatedCount)", "updated", V4.pollen)
            }

            Button(action: onNewRoom) {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                    Text("Create a room")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: 0x171814))
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    V4.paper,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("v4-create-room-primary")
        }
        .padding(.horizontal, 22)
        .padding(.top, 34)
    }

    private var memoryStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live memory map")
                .v4SmallCaps()
            HStack(spacing: 12) {
                ForEach(rooms.prefix(4), id: \.id) { room in
                    let hue = V4.hue(for: room.id)
                    VStack(spacing: 8) {
                        Text(room.name.prefix(1).uppercased())
                            .font(V4.title(26))
                            .foregroundStyle(hue.fg)
                            .frame(width: 52, height: 52)
                            .background(hue.bg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        Text(room.name)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(V4.ink2)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(V4.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(V4.line, lineWidth: 1)
        )
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .animation(.spring(response: 0.52, dampingFraction: 0.84).delay(0.22), value: appeared)
    }

    private var roomGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 13),
                            GridItem(.flexible(), spacing: 13)], spacing: 13) {
            ForEach(rooms, id: \.id) { room in
                let children = allItems.filter { $0.parentId == room.id }
                V4RoomCard(
                    room: room,
                    childCount: children.count,
                    previewPaths: children.compactMap(\.filePath),
                    accessibilityIdentifier: room.id == firstRoomId ? "v4-first-room" : (room.id == newestRoomId ? "v4-latest-room" : nil),
                    deleteAccessibilityIdentifier: room.id == firstRoomId ? "v4-delete-first-room-card" : (room.id == newestRoomId ? "v4-delete-latest-room-card" : nil)
                ) {
                    path.append(V4Route(kind: .room(room.id)))
                } onDelete: {
                    pendingDelete = deleteRequest(for: room)
                }
            }

            Button(action: onNewRoom) {
                ZStack(alignment: .bottomLeading) {
                    Image("V4NewRoomTile")
                        .resizable()
                        .scaledToFill()

                    LinearGradient(
                        colors: [
                            .black.opacity(0.02),
                            .black.opacity(0.08),
                            .black.opacity(0.54)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 7) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(hex: 0x1B1812))
                            .frame(width: 38, height: 38)
                            .background(V4.paper.opacity(0.94), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.62), lineWidth: 1))
                            .shadow(color: .black.opacity(0.22), radius: 12, y: 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add room")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(V4.ink)
                            Text("Name a place")
                                .font(.system(size: 11, weight: .heavy))
                                .textCase(.uppercase)
                                .tracking(1)
                                .foregroundStyle(V4.ink2)
                        }
                    }
                    .padding(14)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("v4-new-room-tile")
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    private var recentGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(recentPlaces, id: \.id) { item in
                let childCount = allItems.filter { $0.parentId == item.id }.count
                V4PlaceCard(
                    item: item,
                    childCount: childCount,
                    accessibilityIdentifier: item.id == recentPlaces.first?.id ? "v4-first-recent-place" : nil,
                    deleteAccessibilityIdentifier: item.id == recentPlaces.first?.id ? "v4-delete-first-recent-place" : nil
                ) {
                    path.append(V4Route(kind: .imageDetail(item.id)))
                } onDelete: {
                    pendingDelete = deleteRequest(for: item)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    private func metric(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(V4.title(25))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(V4.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
                .background(V4.panel2.opacity(0.78), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func sectionHeader(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack {
            Text(title)
                .font(V4.title(25))
                .foregroundStyle(V4.ink)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(V4.cyan)
            }
        }
        .padding(.horizontal, 22)
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

struct V4RoomScreen: View {
    @Environment(\.modelContext) private var modelContext
    let roomId: String
    @Binding var path: NavigationPath
    var onCapture: (String) -> Void

    @State private var pendingDelete: V4DeleteRequest?
    @State private var deleteError: String?

    @Query private var roomMatches: [ImageItem]
    @Query(sort: \ImageItem.createdAt, order: .reverse) private var allItems: [ImageItem]

    init(roomId: String, path: Binding<NavigationPath>, onCapture: @escaping (String) -> Void) {
        self.roomId = roomId
        self._path = path
        self.onCapture = onCapture
        let id = roomId
        self._roomMatches = Query(filter: #Predicate<ImageItem> { $0.id == id })
    }

    private var room: ImageItem? { roomMatches.first }
    private var children: [ImageItem] { allItems.filter { $0.parentId == roomId } }
    private var hue: (bg: Color, fg: Color, name: String) {
        if let room, let bg = room.roomBackgroundColor {
            return (Color(argb: bg), Color(argb: room.roomTextColor ?? 0xFFFFFFFF), "custom")
        }
        return V4.hue(for: roomId)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                HStack(spacing: 10) {
                    Button {
                        onCapture(roomId)
                    } label: {
                        Label("Add a place", systemImage: "camera.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(hex: 0x07101E))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(V4.pollen, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("v4-room-add-place")

                    Button {
                        path.append(V4Route(kind: .imageDetail(roomId)))
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(V4.ink)
                            .frame(width: 52, height: 52)
                            .background(V4.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(V4.line, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)

                Text("Places")
                    .font(V4.title(25))
                    .foregroundStyle(V4.ink)
                    .padding(.horizontal, 22)
                    .padding(.top, 28)

                if children.isEmpty {
                    V4EmptyState(
                        title: "This room is ready",
                        message: "Capture a shelf, drawer, box, or corner to start making it searchable."
                    )
                    .padding(.horizontal, 22)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(children, id: \.id) { item in
                            let count = allItems.filter { $0.parentId == item.id }.count
                            V4PlaceCard(
                                item: item,
                                childCount: count,
                                accessibilityIdentifier: item.id == children.first?.id ? "v4-first-room-place" : nil,
                                deleteAccessibilityIdentifier: item.id == children.first?.id ? "v4-delete-first-room-place" : nil
                            ) {
                                path.append(V4Route(kind: .imageDetail(item.id)))
                            } onDelete: {
                                pendingDelete = deleteRequest(for: item)
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                }

                Spacer(minLength: 110)
            }
        }
        .scrollIndicators(.hidden)
        .background(V4.background)
        .navigationBarBackButtonHidden(true)
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

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            hue.bg
            LinearGradient(colors: [.white.opacity(0.18), .clear, .black.opacity(0.20)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
            Circle()
                .fill(hue.fg.opacity(0.11))
                .frame(width: 220, height: 220)
                .offset(x: 190, y: -30)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    V4GlassButton(systemName: "chevron.left", tint: hue.fg) {
                        if !path.isEmpty {
                            path.removeLast()
                        }
                    }
                    .accessibilityLabel("Back")
                    .accessibilityIdentifier("Back")
                    Spacer()
                    HStack(spacing: 10) {
                        V4GlassButton(systemName: "pencil", tint: hue.fg) {
                            path.append(V4Route(kind: .imageDetail(roomId)))
                        }
                        V4GlassButton(systemName: "trash.fill", tint: hue.fg) {
                            if let room {
                                pendingDelete = deleteRequest(for: room)
                            }
                        }
                        .accessibilityLabel("Delete room")
                        .accessibilityIdentifier("v4-delete-room")
                    }
                }
                .padding(.bottom, 32)

                Text("Room")
                    .v4SmallCaps(hue.fg.opacity(0.72))
                Text(room?.name ?? "Room")
                    .font(V4.title(54))
                    .foregroundStyle(hue.fg)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .padding(.top, 5)
                Text("\(children.count) \(children.count == 1 ? "place" : "places") inside")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(hue.fg.opacity(0.76))
                    .padding(.top, 8)
            }
            .padding(.horizontal, 22)
            .padding(.top, 56)
            .padding(.bottom, 28)
        }
        .clipShape(.rect(
            topLeadingRadius: 0,
            bottomLeadingRadius: 32,
            bottomTrailingRadius: 32,
            topTrailingRadius: 0,
            style: .continuous
        ))
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
                await MainActor.run {
                    pendingDelete = nil
                    if request.itemId == roomId, !path.isEmpty {
                        path.removeLast()
                    }
                }
            } catch {
                await MainActor.run { deleteError = error.localizedDescription }
            }
        }
    }
}
