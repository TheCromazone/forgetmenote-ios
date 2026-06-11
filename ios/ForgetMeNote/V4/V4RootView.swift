import SwiftUI
import SwiftData

struct V4RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthStore.self) private var auth

    @State private var tab: Tab = .home
    @State private var homePath = NavigationPath()
    @State private var findPath = NavigationPath()
    @State private var youPath = NavigationPath()
    @State private var showCapture = false
    @State private var showNewRoom = false
    @State private var showCamera = false
    @State private var pendingParentId: String?
    @State private var pendingError: String?
    @State private var didSeed = false
    @State private var legacyWalkthrough = WalkthroughViewModel()
    @State private var showTour = !UserDefaults.standard.bool(forKey: "v4_walkthrough_shown")

    enum Tab: Hashable { case home, find, you }

    var body: some View {
        ZStack {
            Group {
                if auth.currentUser == nil {
                    V4AuthGate()
                } else {
                    appContent
                }
            }
        }
    }

    private var appContent: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .home:
                    NavigationStack(path: $homePath) {
                        V4HomeScreen(
                            path: $homePath,
                            onCapture: { showCapture = true },
                            onNewRoom: { showNewRoom = true }
                        )
                        .navigationDestination(for: V4Route.self) { destination($0) }
                        .navigationDestination(for: Route.self) { legacyDestination($0) }
                    }
                case .find:
                    NavigationStack(path: $findPath) {
                        V4FindScreen(path: $findPath)
                            .navigationDestination(for: V4Route.self) { destination($0) }
                            .navigationDestination(for: Route.self) { legacyDestination($0) }
                    }
                case .you:
                    NavigationStack(path: $youPath) {
                        V4YouScreen(
                            path: $youPath,
                            onNewRoom: { showNewRoom = true },
                            onShowWalkthrough: {
                                withAnimation(.easeInOut(duration: 0.22)) { showTour = true }
                            },
                            onSignOut: {
                                auth.signOut()
                                tab = .home
                                homePath = NavigationPath()
                                findPath = NavigationPath()
                                youPath = NavigationPath()
                            }
                        )
                        .navigationDestination(for: V4Route.self) { destination($0) }
                        .navigationDestination(for: Route.self) { legacyDestination($0) }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.spring(response: 0.38, dampingFraction: 0.88), value: tab)

            V4LiquidDock(tab: $tab, onSelect: selectTab) {
                showCapture = true
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(
                LinearGradient(
                    colors: [
                        V4.void.opacity(0),
                        V4.void.opacity(0.78),
                        V4.void.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            )
        }
        .overlay {
            if showTour {
                V4Walkthrough {
                    UserDefaults.standard.set(true, forKey: "v4_walkthrough_shown")
                    withAnimation(.easeOut(duration: 0.22)) { showTour = false }
                }
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .background(V4.void.ignoresSafeArea())
        .environment(legacyWalkthrough)
        .sheet(isPresented: $showCapture) {
            V4CaptureSheet(
                onClose: { showCapture = false },
                onNewRoom: {
                    showCapture = false
                    showNewRoom = true
                },
                onCaptureIn: beginCapture(parentId:),
                onDemoIn: beginDemo(parentId:)
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNewRoom) {
            V4NewRoomSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(
                onPick: { data in finishCapture(data: data) },
                onCancel: { pendingParentId = nil; showCamera = false }
            )
            .ignoresSafeArea()
        }
        .alert("Could not start capture", isPresented: Binding(
            get: { pendingError != nil },
            set: { if !$0 { pendingError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pendingError ?? "")
        }
        .task {
            guard !didSeed else { return }
            didSeed = true
            let repo = ImageRepository(modelContainer: modelContext.container)
            try? await repo.initializeDefaultRoomsIfNeeded()
            _ = await repo.settings()
        }
    }

    @ViewBuilder
    private func destination(_ route: V4Route) -> some View {
        switch route.kind {
        case .room(let id):
            V4RoomScreen(roomId: id, path: currentPathBinding, onCapture: beginCapture(parentId:))
        case .imageDetail(let id):
            ImageDetailScreen(imageId: id, path: currentPathBinding)
        case .createChild(let parentId, let suggestedTitle, let rect, let tempPhotoPath):
            CreateChildScreen(
                parentId: parentId,
                suggestedTitle: suggestedTitle,
                rectangleOnParent: rect,
                tempPhotoPath: tempPhotoPath,
                path: currentPathBinding
            )
        case .settings:
            SettingsScreen()
        case .help:
            HelpScreen()
        }
    }

    @ViewBuilder
    private func legacyDestination(_ route: Route) -> some View {
        switch route {
        case .imageDetail(let id):
            ImageDetailScreen(imageId: id, path: currentPathBinding)
        case .createChild(let parentId, let suggestedTitle, let rect, let tempPhotoPath):
            CreateChildScreen(
                parentId: parentId,
                suggestedTitle: suggestedTitle,
                rectangleOnParent: rect,
                tempPhotoPath: tempPhotoPath,
                path: currentPathBinding
            )
        case .settings:
            SettingsScreen()
        case .help:
            HelpScreen()
        case .v3Room(let roomId):
            V3RoomScreen(roomId: roomId, path: currentPathBinding)
        case .v3Space(let spaceId):
            V3SpaceScreen(spaceId: spaceId, path: currentPathBinding)
        case .v3CreateSub(let parentId, let tempPhotoPath, _, _):
            // v4 never constructs this route with prefilled values; ignore the
            // v3-only associated values to keep v4 behavior unchanged.
            V3CreateSubScreen(parentId: parentId, tempPhotoPath: tempPhotoPath,
                              path: currentPathBinding)
        }
    }

    private var currentPathBinding: Binding<NavigationPath> {
        switch tab {
        case .home: return $homePath
        case .find: return $findPath
        case .you: return $youPath
        }
    }

    private func selectTab(_ nextTab: Tab) {
        if nextTab == .home {
            resetToHome()
            return
        }

        if nextTab == tab {
            resetPath(for: nextTab)
        }
        tab = nextTab
    }

    private func resetToHome() {
        showCapture = false
        showNewRoom = false
        showCamera = false
        pendingParentId = nil
        pendingError = nil
        homePath = NavigationPath()
        findPath = NavigationPath()
        youPath = NavigationPath()
        tab = .home
    }

    private func resetPath(for tab: Tab) {
        switch tab {
        case .home:
            homePath = NavigationPath()
        case .find:
            findPath = NavigationPath()
        case .you:
            youPath = NavigationPath()
        }
    }

    private func beginCapture(parentId: String) {
        showCapture = false
        pendingParentId = parentId
        guard CameraImagePicker.isAvailable else {
            beginDemo(parentId: parentId)
            return
        }
        showCamera = true
    }

    private func beginDemo(parentId: String) {
        showCapture = false
        let data = DemoImage.make(label: "New")
        finishCapture(data: data, forcedParentId: parentId, suggestedTitle: "Demo item")
    }

    private func finishCapture(data: Data, forcedParentId: String? = nil, suggestedTitle: String? = nil) {
        let parentId = forcedParentId ?? pendingParentId
        pendingParentId = nil
        showCamera = false
        guard let parentId else { return }
        do {
            let tempPath = try TempPhotoStore.write(data)
            currentPathBinding.wrappedValue.append(
                V4Route(kind: .createChild(parentId, suggestedTitle, nil, tempPath))
            )
        } catch {
            pendingError = error.localizedDescription
        }
    }
}

private struct V4LiquidDock: View {
    @Binding var tab: V4RootView.Tab
    var onSelect: (V4RootView.Tab) -> Void
    var onCapture: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                dockButton(.home, "house.fill", "Home")
                dockButton(.find, "magnifyingglass", "Find")
                dockButton(.you, "person.fill", "You")
            }
            .padding(6)
            .background(.regularMaterial, in: Capsule())
            .background(Color(hex: 0x1F211C).opacity(0.86), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.24), lineWidth: 1))
            .shadow(color: .black.opacity(0.46), radius: 28, y: 14)

            Button(action: onCapture) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Color(hex: 0x10110E))
                    .frame(width: 60, height: 60)
                    .background(
                        LinearGradient(
                            colors: [V4.paper, V4.pollen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .overlay(Circle().stroke(.white.opacity(0.62), lineWidth: 1))
                    .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("v4-capture-fab")
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func dockButton(_ value: V4RootView.Tab, _ systemName: String, _ title: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                onSelect(value)
            }
        } label: {
            HStack(spacing: tab == value ? 7 : 0) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .bold))
                if tab == value {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .foregroundStyle(tab == value ? Color(hex: 0x10110E) : V4.ink2)
            .frame(width: tab == value ? 86 : 46, height: 48)
            .background(
                Group {
                    if tab == value {
                        Capsule().fill(V4.paper.opacity(0.92))
                    } else {
                        Capsule().fill(Color(hex: 0x11110E).opacity(0.34))
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("v4-tab-\(title.lowercased())")
    }
}
