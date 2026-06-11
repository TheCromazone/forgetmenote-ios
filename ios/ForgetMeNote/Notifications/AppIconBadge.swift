import Foundation
import SwiftData
import UserNotifications

/// Keeps the iOS home-screen app icon badge in sync with the count of
/// `ImageItem` rows whose `isUpdated == true`. Mirrors the Android side's
/// ShortcutBadger integration.
///
/// Authorization for badges is requested on demand the first time the user
/// enables "Show badge on app icon" in Settings, or the first time we try to
/// set a non-zero badge.
@MainActor
enum AppIconBadge {

    /// Recompute and push the badge. If `showBadge` is false, clears the badge
    /// regardless of the actual count.
    static func refresh(modelContext: ModelContext, showBadge: Bool) {
        let count: Int
        if showBadge {
            count = countUpdatedItems(modelContext: modelContext)
        } else {
            count = 0
        }
        Task {
            if showBadge && count > 0 {
                await requestAuthorizationIfNeeded()
            }
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(count)
            } catch {
                print("AppIconBadge: setBadgeCount failed: \(error)")
            }
        }
    }

    /// Convenience: looks up the AppSettings row to read showUpdatedBadge,
    /// then refreshes. Use from places that don't already have settings in
    /// scope (background-task handlers, scene-phase callbacks).
    static func refreshFromCurrentSettings(modelContext: ModelContext) {
        let settingsRows = (try? modelContext.fetch(FetchDescriptor<AppSettings>())) ?? []
        let show = settingsRows.first?.showUpdatedBadge ?? true
        refresh(modelContext: modelContext, showBadge: show)
    }

    // MARK: - Helpers

    private static func countUpdatedItems(modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<ImageItem>(
            predicate: #Predicate { $0.isUpdated == true }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    private static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.badge])
        }
    }
}
