import Foundation
import BackgroundTasks
import SwiftData
import UserNotifications
import UIKit

/// Background-task–driven reminder that posts a local notification listing the
/// count of items currently marked "Updated", on a weekly or monthly cadence
/// controlled by `AppSettings.updatedRemindersEnabled` /
/// `.updatedRemindersFrequency`. Port of Android `UpdatedItemsReminderWorker`.
///
/// iOS-vs-Android caveat: BGTaskScheduler fires opportunistically — the system
/// chooses the actual moment within (roughly) the window we request. The
/// reminder might come up to a day after the scheduled minimum. This matches
/// Android's WorkManager flexibility behavior.
enum UpdatedItemsReminder {

    /// The single identifier registered in Info.plist
    /// (`BGTaskSchedulerPermittedIdentifiers`).
    static var taskIdentifier: String {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.matthewcromaz.forgetmenote.v3.dev"
        return "\(bundleId).updatedItemsReminder"
    }

    private static let category = "UPDATED_ITEMS_REMINDER"

    // MARK: - Registration

    /// Call from `App.init` to register the handler. Must be called before the
    /// app finishes launch.
    static func registerHandler(modelContainer: ModelContainer) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(task: task, modelContainer: modelContainer)
        }
    }

    /// Call when the app foregrounds (and when reminders get enabled) to
    /// schedule the next opportunity. Cancels any previous request first.
    @MainActor
    static func reschedule(modelContainer: ModelContainer) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)

        let context = modelContainer.mainContext
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first
        guard let settings, settings.updatedRemindersEnabled else { return }

        let days = ReminderFrequency(rawValue: settings.updatedRemindersFrequency)?.dayInterval ?? 7
        let interval = TimeInterval(days * 24 * 60 * 60)

        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("UpdatedItemsReminder: submit failed: \(error)")
        }
    }

    // MARK: - Handler

    private static func handle(task: BGAppRefreshTask, modelContainer: ModelContainer) {
        // Always schedule the next firing — the task we're handling now is
        // single-shot.
        Task { @MainActor in
            reschedule(modelContainer: modelContainer)
        }

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task { @MainActor in
            let context = modelContainer.mainContext
            let count = (try? context.fetchCount(FetchDescriptor<ImageItem>(
                predicate: #Predicate { $0.isUpdated == true }
            ))) ?? 0
            if count > 0 {
                await postNotification(count: count)
                AppIconBadge.refresh(modelContext: context, showBadge: true)
            }
            task.setTaskCompleted(success: true)
        }
    }

    private static func postNotification(count: Int) async {
        let center = UNUserNotificationCenter.current()
        let auth = await center.notificationSettings()
        if auth.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        }
        let content = UNMutableNotificationContent()
        content.title = "Forget Me Note"
        content.body = count == 1
            ? "You have 1 item marked Updated. Want to revisit it?"
            : "You have \(count) items marked Updated. Want to revisit them?"
        content.sound = .default
        content.badge = NSNumber(value: count)
        content.categoryIdentifier = category

        let req = UNNotificationRequest(
            identifier: "updated-items-reminder",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        do {
            try await center.add(req)
        } catch {
            print("UpdatedItemsReminder: add notification failed: \(error)")
        }
    }
}
