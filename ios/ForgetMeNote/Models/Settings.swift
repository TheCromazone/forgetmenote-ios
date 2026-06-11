import Foundation
import SwiftData

/// Mirrors `com.imageorganizer.app.data.Settings` (Room v12 schema).
///
/// Single-row pattern: the repository keeps exactly one `AppSettings` instance
/// in the container. Named `AppSettings` instead of `Settings` to avoid the
/// SwiftUI `Settings` scene type collision.
@Model
final class AppSettings {
    @Attribute(.unique) var id: Int
    var childRectangleTransparency: Float
    var childRectangleBorderWidth: Float
    var childRectangleBorderTransparency: Float
    var enableTagsListEdit: Bool
    var checkOrphanedImages: Bool
    var lastOrphanedCheck: Int64
    var searchThroughCollapsedImages: Bool
    /// ARGB packed (`0xFF6750A4` = Material 3 primary purple by default).
    var roomBackgroundColor: Int64
    var roomTextColor: Int64
    /// Default `0xFFFF9800` orange.
    var updatedHighlightColor: Int64
    /// 0.0 ... 1.0 (default 0.2 = 20%).
    var updatedHighlightPercentage: Float
    var showUpdatedBadge: Bool
    var updatedRemindersEnabled: Bool
    /// `"weekly"` or `"monthly"`.
    var updatedRemindersFrequency: String
    var scaleDownPhotos: Bool
    var scaleDownMinWidth: Int

    init(
        id: Int = 1,
        childRectangleTransparency: Float = 0.25,
        childRectangleBorderWidth: Float = 3.0,
        childRectangleBorderTransparency: Float = 0.4,
        enableTagsListEdit: Bool = true,
        checkOrphanedImages: Bool = true,
        lastOrphanedCheck: Int64 = 0,
        searchThroughCollapsedImages: Bool = true,
        roomBackgroundColor: Int64 = 0xFF6750A4,
        roomTextColor: Int64 = 0xFFFFFFFF,
        updatedHighlightColor: Int64 = 0xFFFF9800,
        updatedHighlightPercentage: Float = 0.2,
        showUpdatedBadge: Bool = true,
        updatedRemindersEnabled: Bool = false,
        updatedRemindersFrequency: String = "weekly",
        scaleDownPhotos: Bool = true,
        scaleDownMinWidth: Int = 740
    ) {
        self.id = id
        self.childRectangleTransparency = childRectangleTransparency
        self.childRectangleBorderWidth = childRectangleBorderWidth
        self.childRectangleBorderTransparency = childRectangleBorderTransparency
        self.enableTagsListEdit = enableTagsListEdit
        self.checkOrphanedImages = checkOrphanedImages
        self.lastOrphanedCheck = lastOrphanedCheck
        self.searchThroughCollapsedImages = searchThroughCollapsedImages
        self.roomBackgroundColor = roomBackgroundColor
        self.roomTextColor = roomTextColor
        self.updatedHighlightColor = updatedHighlightColor
        self.updatedHighlightPercentage = updatedHighlightPercentage
        self.showUpdatedBadge = showUpdatedBadge
        self.updatedRemindersEnabled = updatedRemindersEnabled
        self.updatedRemindersFrequency = updatedRemindersFrequency
        self.scaleDownPhotos = scaleDownPhotos
        self.scaleDownMinWidth = scaleDownMinWidth
    }
}

enum ReminderFrequency: String, CaseIterable {
    case weekly
    case monthly

    /// Days between reminders, matching Android's WorkManager schedule.
    var dayInterval: Int {
        switch self {
        case .weekly: return 7
        case .monthly: return 30
        }
    }
}
