import SwiftUI
import SwiftData

@main
struct ForgetMeNoteApp: App {
    /// Single shared SwiftData container for the app. Schema lists every @Model type.
    @State private var modelContainer: ModelContainer
    @State private var authStore: AuthStore

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let fileManager = FileManager.default
        if let applicationSupportURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            try? fileManager.createDirectory(
                at: applicationSupportURL,
                withIntermediateDirectories: true
            )
        }

        let schema = Schema([ImageItem.self, AppSettings.self, User.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error)")
        }
        _modelContainer = State(initialValue: container)
        _authStore = State(initialValue: AuthStore(modelContainer: container))
        // Register the BGTaskScheduler handler before launch completes.
        UpdatedItemsReminder.registerHandler(modelContainer: container)
    }

    var body: some Scene {
        WindowGroup {
            #if FMN_V4
            V4RootView()
                .environment(authStore)
            #else
            V3RootView()
                .environment(authStore)
            #endif
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task { @MainActor in
                    AppIconBadge.refreshFromCurrentSettings(
                        modelContext: modelContainer.mainContext
                    )
                }
            case .background:
                // System is about to put us to sleep — schedule the next
                // reminder firing now so it fires while we're not running.
                Task { @MainActor in
                    UpdatedItemsReminder.reschedule(modelContainer: modelContainer)
                }
            default:
                break
            }
        }
    }
}
