import SwiftUI
import SwiftData

/// Top-level container — owns the `NavigationPath` and hosts every screen
/// reachable via `Route`. Replaces the Phase 0 `ContentView`.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var path = NavigationPath()
    @State private var didSeed = false
    @State private var walkthrough = WalkthroughViewModel()

    var body: some View {
        ZStack {
            NavigationStack(path: $path) {
                MainScreen(path: $path)
                    .environment(walkthrough)
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .imageDetail(let imageId):
                            ImageDetailScreen(imageId: imageId, path: $path)
                        case .createChild(let parentId, let suggestedTitle, let rect, let tempPath):
                            CreateChildScreen(
                                parentId: parentId,
                                suggestedTitle: suggestedTitle,
                                rectangleOnParent: rect,
                                tempPhotoPath: tempPath,
                                path: $path
                            )
                        case .settings:
                            SettingsScreen()
                                .environment(walkthrough)
                        case .help:
                            HelpScreen()
                        case .v3Room(let roomId):
                            // v2 RootView fallback: open the legacy image detail.
                            ImageDetailScreen(imageId: roomId, path: $path)
                        case .v3Space(let spaceId):
                            ImageDetailScreen(imageId: spaceId, path: $path)
                        case .v3CreateSub(let parentId, let tempPath, _, _):
                            // v2 fallback: route to legacy CreateChildScreen so
                            // building the v2 RootView still resolves.
                            CreateChildScreen(
                                parentId: parentId,
                                suggestedTitle: nil,
                                rectangleOnParent: nil,
                                tempPhotoPath: tempPath,
                                path: $path
                            )
                        }
                    }
                    .onPreferenceChange(WalkthroughBoundsPreferenceKey.self) { bounds in
                        for (target, rect) in bounds {
                            walkthrough.reportBounds(target, rect)
                        }
                    }
            }

            if walkthrough.isActive {
                WalkthroughOverlay(viewModel: walkthrough)
                    .transition(.opacity)
                    .accessibilityIdentifier("walkthrough-overlay")
            }
        }
        .task {
            guard !didSeed else { return }
            didSeed = true
            let repo = ImageRepository(modelContainer: modelContext.container)
            try? await repo.initializeDefaultRoomsIfNeeded()
            _ = await repo.settings()  // ensure settings row exists

            // First-launch: auto-start the walkthrough.
            if !walkthrough.isCompleted() {
                // Slight delay so the carousel/tree have laid out and reported
                // their bounds via PreferenceKey before the spotlight steps
                // are reached.
                try? await Task.sleep(nanoseconds: 400_000_000)
                walkthrough.start()
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [ImageItem.self, AppSettings.self], inMemory: true)
}
