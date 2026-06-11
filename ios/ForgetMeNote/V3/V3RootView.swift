import SwiftUI
import SwiftData

/// V3 root — owns the tab state and welcome-first-launch logic.
///
/// Tabs: Home / Find / You. A central "+" capture button overlays the tab
/// bar for quick photo entry. Each tab keeps its own NavigationStack.
struct V3RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthStore.self) private var auth
    @State private var palette: V3Palette = .forget
    @State private var tab: V3Tab = .home
    @State private var homePath = NavigationPath()
    @State private var findPath = NavigationPath()
    @State private var youPath = NavigationPath()
    @State private var showWelcome: Bool = !UserDefaults.standard.bool(forKey: "v3_welcome_shown")
    @State private var authScreen: AuthScreen = .signIn
    @State private var didSeed = false
    @State private var legacyWalkthrough = WalkthroughViewModel()

    // Capture flow state
    @State private var showCaptureSheet: Bool = false
    @State private var showCamera: Bool = false
    @State private var showLibrary: Bool = false
    /// Set when the user picked "Snap a photo" / "From library" without first
    /// choosing a destination room — the resulting capture should be routed
    /// to V3CreateSubScreen with the first root room as its parent.
    @State private var pendingParentId: String? = nil
    @State private var showTour: Bool = false
    /// The node currently selected in the Home browse — the default parent for
    /// the capture FAB so a photo nests where you're looking, not at the root.
    @State private var homeSelectedId: String? = nil

    enum V3Tab: Hashable { case home, find, you }
    enum AuthScreen { case signIn, signUp }

    var body: some View {
        ZStack {
            if auth.currentUser == nil {
                authBody
            } else {
                signedInBody
            }
        }
        .environment(\.v3Palette, palette)
        .environment(legacyWalkthrough)
        .task {
            guard !didSeed else { return }
            didSeed = true
            #if targetEnvironment(simulator)
            // Dev-only: `simctl launch … -fmnAutoDemo` boots straight to Home
            // (demo account + welcome dismissed) so the UI can be screenshotted
            // without driving the sign-in form. Inert without the flag; excluded
            // from device builds entirely.
            let launchArgs = ProcessInfo.processInfo.arguments
            if (launchArgs.contains("-fmnAutoDemo") || launchArgs.contains("fmnAutoDemo")),
               auth.currentUser == nil {
                _ = auth.useDemoAccount()
                UserDefaults.standard.set(true, forKey: "v3_welcome_shown")
                showWelcome = false
            }
            #endif
            let repo = ImageRepository(modelContainer: modelContext.container)
            try? await repo.initializeDefaultRoomsIfNeeded()
            _ = await repo.settings()
            // One-shot on-disk orphan sweep: drop DB rows whose photo file is
            // gone (e.g. wiped by the OS). Repository method, just call it.
            try? await repo.removeOrphanedImages()
            #if targetEnvironment(simulator)
            // Dev-only: `-fmnSeedPhoto` inserts one generated demo PHOTO space
            // so Maestro can exercise photo-only flows (Find objects, draw a
            // spot) — the Simulator has no camera and PHPicker is hard to
            // drive. Inert without the flag; excluded from device builds.
            let seedArgs = ProcessInfo.processInfo.arguments
            if seedArgs.contains("-fmnSeedPhoto") || seedArgs.contains("fmnSeedPhoto") {
                let name = "Demo shelf"
                let existing = try? modelContext.fetch(
                    FetchDescriptor<ImageItem>(predicate: #Predicate { $0.name == name }))
                if (existing ?? []).isEmpty {
                    _ = try? await repo.saveImage(
                        jpegData: DemoImage.make(label: "Demo"),
                        name: name, parentId: firstRootRoomId())
                }
            }
            #endif
        }
    }

    @ViewBuilder private var authBody: some View {
        switch authScreen {
        case .signIn:
            V3SignInScreen(
                palette: palette,
                onSignedIn: { /* state-driven re-render handles it */ },
                onGoSignUp: { authScreen = .signUp }
            )
        case .signUp:
            V3SignUpScreen(
                palette: palette,
                onSignedUp: {
                    // brand-new users see the welcome screen once
                    showWelcome = true
                    UserDefaults.standard.set(false, forKey: "v3_welcome_shown")
                },
                onGoSignIn: { authScreen = .signIn }
            )
        }
    }

    @ViewBuilder private var signedInBody: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: tabSelection) {
                NavigationStack(path: $homePath) {
                    V3BrowseHome(palette: palette,
                                 name: auth.currentUser?.name ?? "Friend",
                                 selectedId: $homeSelectedId,
                                 path: $homePath,
                                 onOpenSearch: { tab = .find },
                                 onCapturePhoto: { parentId in
                                     pendingParentId = parentId
                                     showCaptureSheet = true
                                 },
                                 onAddEmpty: { parentId in
                                     routeToCreateSub(parentId: parentId, tempPhotoPath: nil)
                                 })
                        .navigationDestination(for: Route.self) { destination(for: $0) }
                }
                .tag(V3Tab.home)
                .tabItem { Label("Home", systemImage: "house.fill") }

                NavigationStack(path: $findPath) {
                    V3FindScreen(palette: palette, path: $findPath)
                        .navigationDestination(for: Route.self) { destination(for: $0) }
                }
                .tag(V3Tab.find)
                .tabItem { Label("Find", systemImage: "magnifyingglass") }

                NavigationStack(path: $youPath) {
                    V3YouScreen(palette: palette, path: $youPath,
                                onShowWelcome: {
                                    withAnimation(.easeIn(duration: 0.25)) { showTour = true }
                                })
                        .navigationDestination(for: Route.self) { destination(for: $0) }
                }
                .tag(V3Tab.you)
                .tabItem { Label("You", systemImage: "person.circle") }
            }
            .tint(palette.accent)

            // Capture FAB as a separate glass circle to the RIGHT of the
            // tab-bar pill, vertically centered at the same level (iOS 26
            // accessory look).
            if !showWelcome {
                // Sit the FAB at the SAME level as the floating tab-bar pill
                // (the bottom liquid-glass pane), just above the home indicator,
                // as a separate glass circle to its right — not above it.
                // `bottomBarLevel` is tuned on-device; nudge it up/down to align.
                GeometryReader { proxy in
                    V3CaptureFAB(palette: palette) {
                        V3Haptics.impact(.medium)
                        // Default the new photo's parent to whatever is selected
                        // in the Home browse so captures nest in context. The
                        // capture sheet still lets you pick a different room.
                        pendingParentId = homeSelectedId
                        showCaptureSheet = true
                    }
                    .padding(.trailing, 16)
                    // Tuned to center the FAB on the floating tab-bar pill
                    // (measured: pill center sits ~9pt below the safe-area
                    // boundary on iPhone 15PM/17).
                    .padding(.bottom, proxy.safeAreaInsets.bottom - 43)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
                .ignoresSafeArea(.keyboard)
                .allowsHitTesting(true)
                .zIndex(5)
            }

            if showWelcome {
                V3WelcomeScreen(
                    palette: palette,
                    onStart: dismissWelcome,
                    onSkip: dismissWelcome
                )
                .transition(.opacity)
                .zIndex(10)
            }

            if showTour {
                V3Walkthrough(palette: palette) {
                    withAnimation(.easeOut(duration: 0.25)) { showTour = false }
                }
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .sheet(isPresented: $showCaptureSheet) {
            V3CaptureSheet(
                palette: palette,
                onSnap: {
                    showCaptureSheet = false
                    // Defer presenting the camera by one runloop so the sheet
                    // has time to dismiss cleanly before fullScreenCover.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        if CameraImagePicker.isAvailable {
                            showCamera = true
                        } else {
                            // Simulator / no-camera fallback: skip straight to
                            // CreateSub with no photo against the chosen parent
                            // (the selected node), falling back to the first root.
                            routeToCreateSub(parentId: pendingParentId ?? firstRootRoomId(),
                                             tempPhotoPath: nil)
                            pendingParentId = nil
                        }
                    }
                },
                onLibrary: {
                    showCaptureSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showLibrary = true
                    }
                },
                onPickRoom: { roomId in
                    showCaptureSheet = false
                    routeToCreateSub(parentId: roomId, tempPhotoPath: nil)
                }
            )
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(
                onPick: { data in
                    showCamera = false
                    handleCapturedImage(jpegData: data)
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            V3LibraryPicker { data in
                showLibrary = false
                if let data { handleCapturedImage(jpegData: data) }
            }
        }
    }

    /// Pick the first available root room as the default parent for a freshly
    /// captured photo when the user hasn't already chosen one. Returns the
    /// special `__root__` sentinel if no rooms exist yet (rare — defaults
    /// seeding runs in `task`).
    private func firstRootRoomId() -> String {
        let descriptor = FetchDescriptor<ImageItem>(
            predicate: #Predicate { $0.parentId == nil && $0.filePath == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        if let first = try? modelContext.fetch(descriptor).first { return first.id }
        return "__root__"
    }

    /// Write JPEG to TempPhotoStore and navigate the current tab to
    /// `v3CreateSub` with the resolved parent.
    private func handleCapturedImage(jpegData: Data) {
        let parentId = pendingParentId ?? firstRootRoomId()
        pendingParentId = nil
        do {
            let tempPath = try TempPhotoStore.write(jpegData)
            routeToCreateSub(parentId: parentId, tempPhotoPath: tempPath)
        } catch {
            // Silently swallow — better than a crash. The user can try again.
        }
    }

    private func routeToCreateSub(parentId: String, tempPhotoPath: String?) {
        // Switch to Home so the navigation is visible regardless of which
        // tab the user opened the capture sheet from. Reset the stack first so
        // we don't push CreateSub onto a possibly-stale Home navigation path.
        tab = .home
        homePath = NavigationPath()
        homePath.append(Route.v3CreateSub(parentId: parentId, tempPhotoPath: tempPhotoPath))
    }

    private func dismissWelcome() {
        UserDefaults.standard.set(true, forKey: "v3_welcome_shown")
        withAnimation(.easeOut(duration: 0.3)) { showWelcome = false }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .imageDetail(let imageId):
            ImageDetailScreen(imageId: imageId, path: currentPathBinding)
        case .createChild(let parentId, let suggestedTitle, let rect, let tempPath):
            CreateChildScreen(
                parentId: parentId,
                suggestedTitle: suggestedTitle,
                rectangleOnParent: rect,
                tempPhotoPath: tempPath,
                path: currentPathBinding
            )
        case .settings:
            V3SettingsScreen()
        case .help:
            HelpScreen()
        case .v3Room(let roomId):
            V3RoomScreen(roomId: roomId, path: currentPathBinding)
        case .v3Space(let spaceId):
            V3SpaceScreen(spaceId: spaceId, path: currentPathBinding)
        case .v3CreateSub(let parentId, let tempPath, let rect, let title):
            V3CreateSubScreen(parentId: parentId, tempPhotoPath: tempPath,
                              suggestedRect: rect, suggestedTitle: title,
                              path: currentPathBinding)
        }
    }

    /// Tab selection binding that intercepts re-taps: tapping the already-
    /// selected tab pops that tab's NavigationStack back to its root.
    private var tabSelection: Binding<V3Tab> {
        Binding(
            get: { tab },
            set: { newValue in
                if newValue == tab {
                    // Re-tap on the current tab → clear its navigation path.
                    switch newValue {
                    case .home: homePath = NavigationPath()
                    case .find: findPath = NavigationPath()
                    case .you:  youPath  = NavigationPath()
                    }
                } else {
                    tab = newValue
                }
            }
        )
    }

    private var currentPathBinding: Binding<NavigationPath> {
        switch tab {
        case .home: return $homePath
        case .find: return $findPath
        case .you:  return $youPath
        }
    }
}

/// Minimal "You" tab — entry point to Settings, plus a quick stat row.
struct V3YouScreen: View {
    let palette: V3Palette
    @Binding var path: NavigationPath
    var onShowWelcome: () -> Void

    @Environment(AuthStore.self) private var auth
    @Query(sort: \ImageItem.createdAt) private var allItems: [ImageItem]
    @Query private var settingsRows: [AppSettings]

    private var firstName: String {
        auth.currentUser?.name.split(separator: " ").first.map(String.init) ?? "Friend"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(V3Greeting.phrase())
                        .v3SmallCaps(palette.ink3)
                    (Text("Hi \(firstName),\n").font(V3Font.headline(34)).foregroundStyle(palette.ink) +
                     Text("your stats").font(V3Font.headline(34, italic: true)).italic()
                        .foregroundStyle(palette.accent))
                        .tracking(-0.7)
                }
                .padding(.horizontal, 22)
                .padding(.top, 64)

                statRow
                    .padding(.horizontal, 22)
                    .padding(.top, 24)

                actionList
                    .padding(.top, 24)

                Spacer(minLength: 110)
            }
        }
        .background(paperBackground)
    }

    @ViewBuilder private var statRow: some View {
        HStack(spacing: 12) {
            statCard(title: "\(allItems.count)", subtitle: "places", hue: palette.accent)
            statCard(title: "\(allItems.filter(\.isUpdated).count)",
                     subtitle: "updated", hue: palette.pollen, fgOnColor: Color(hex: 0x3D2A0E))
            statCard(title: "\(Set(allItems.flatMap { $0.tags }).count)",
                     subtitle: "tags", hue: palette.ink2)
        }
    }

    private func statCard(title: String, subtitle: String, hue: Color, fgOnColor: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(V3Font.headline(28))
                .foregroundStyle(fgOnColor)
            Text(subtitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(fgOnColor.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(hue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder private var actionList: some View {
        VStack(spacing: 0) {
            actionRow("Settings", icon: "gear",
                      onTap: { path.append(Route.settings) },
                      accessibilityID: "v3-you-settings")
            Divider().background(palette.line).padding(.leading, 54)
            actionRow("Help", icon: "questionmark.circle",
                      onTap: { path.append(Route.help) },
                      accessibilityID: "v3-you-help")
            Divider().background(palette.line).padding(.leading, 54)
            actionRow("Show walkthrough", icon: "info.bubble",
                      onTap: onShowWelcome,
                      accessibilityID: "v3-you-walkthrough")
            Divider().background(palette.line).padding(.leading, 54)
            actionRow("Sign out", icon: "rectangle.portrait.and.arrow.right",
                      onTap: { auth.signOut() },
                      accessibilityID: "v3-you-signout",
                      destructive: true)
        }
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        .padding(.horizontal, 22)
    }

    private func actionRow(_ title: String, icon: String, onTap: @escaping () -> Void,
                           accessibilityID: String? = nil, destructive: Bool = false) -> some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(destructive ? palette.danger : palette.accent)
                    .frame(width: 32, height: 32)
                    .background(destructive ? palette.danger.opacity(0.1) : palette.accentBg,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.system(size: 15, weight: destructive ? .semibold : .medium))
                    .foregroundStyle(destructive ? palette.danger : palette.ink)
                Spacer()
                if !destructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.ink3)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(SwiftUI.Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID ?? "v3-you-row-\(title.lowercased())")
    }

    @ViewBuilder private var paperBackground: some View {
        ZStack {
            palette.paper
            LinearGradient(colors: [palette.surface.opacity(0.6), .clear],
                           startPoint: .top, endPoint: .center)
        }
        .ignoresSafeArea()
    }
}
