# Android → iOS mapping reference

Companion to `/Users/matthewcromaz/.claude/plans/i-need-to-help-dazzling-mccarthy.md`.
Captures everything I extracted from line-by-line reading of the Kotlin source so
we don't have to re-read it during implementation.

## Identifiers, names, versions

| Thing | Value in Android |
|---|---|
| Application ID / bundle | `com.imageorganizer.app` |
| App display name | `Forget Me Note` (settings.gradle.kts `rootProject.name`) |
| versionName / versionCode | `1.3.7` / `14` |
| Min SDK / Target SDK | `24` / `35` |
| Database name | `image_database` (filename inside `getDatabasePath`) |
| **Database version** | **12** (not 11 as Requirements.md says — Requirements is one revision behind) |
| App-private images directory | `${filesDir}/images/` |
| Image filename pattern | `{uuid}_{name}.jpg`, JPEG compression quality 90 |
| Default rooms created on first launch | "My home", "Good things", "Bad things" (in that insertion order, but timestamps make "My home" first by `createdAt + 0`, then Good +1s, then Bad +2s — wait, actually the insertion order is `myHomeRoom`, `goodThingsRoom`, `badThingsRoom` per `initializeDefaultRoomsIfNeeded`) |
| First-launch flag storage | SharedPreferences file `forgetmenote_prefs`, key `default_rooms_created` |

## Data model exact field set

### `ImageItem` (table `images`)
| Field | Kotlin type | Notes |
|---|---|---|
| `id` | `String` PRIMARY KEY | UUID string |
| `name` | `String` | required |
| `tags` | `List<String>` | persisted as Gson JSON `["a","b"]` |
| `thumbnail` | `String?` | file path or null |
| `filePath` | `String?` | null = "room" with no image |
| `parentId` | `String?` | null = root-level |
| `childIds` | `List<String>` | persisted as Gson JSON |
| `rectangleOnParent` | `Rectangle?` | persisted as Gson JSON of `{x,y,width,height}` |
| `createdAt` | `Long` | epoch millis; used for ordering (ASC) |
| `roomBackgroundColor` | `Long?` | ARGB packed |
| `roomTextColor` | `Long?` | ARGB packed |
| `notes` | `String` (default `""`) | added v7→v8 |
| `isUpdated` | `Boolean` (default `false`) | added v8→v9 |

### `Rectangle`
Plain data class, four floats, normalized 0..1.

### `Settings` (table `settings`, single row with `id = 1`)
17 fields, all with defaults:

| Field | Default | Notes |
|---|---|---|
| `id` | `1` | always 1, single-row pattern |
| `childRectangleTransparency` | `0.25` | 5-60% range |
| `childRectangleBorderWidth` | `3.0` | 1-10 px |
| `childRectangleBorderTransparency` | `0.4` | 5-60% |
| `enableTagsListEdit` | `true` | |
| `checkOrphanedImages` | `true` | auto-check on startup |
| `lastOrphanedCheck` | `0L` | epoch ms |
| `searchThroughCollapsedImages` | `true` | added v4→v5 |
| `roomBackgroundColor` | `0xFF6750A4` | Material3 primary purple, added v5→v6 |
| `roomTextColor` | `0xFFFFFFFF` | white, added v5→v6 |
| `updatedHighlightColor` | `0xFFFF9800` | orange, added v8→v9 |
| `updatedHighlightPercentage` | `0.2f` | 20% opacity, added v8→v9 |
| `showUpdatedBadge` | `true` | added v9→v10 |
| `updatedRemindersEnabled` | `false` | added v10→v11 |
| `updatedRemindersFrequency` | `"weekly"` | values `"weekly"` or `"monthly"` |
| `scaleDownPhotos` | `true` | added v11→v12 |
| `scaleDownMinWidth` | `740` | px, added v11→v12 |

## Repository public surface (port these to Swift `ImageRepositoryProtocol`)

Flow-returning (publishers on iOS):
- `getAllImages() -> Flow<List<ImageItem>>` ORDER BY createdAt ASC
- `getParentImages() -> Flow<List<ImageItem>>` WHERE parentId IS NULL
- `getChildImages(parentId) -> Flow<List<ImageItem>>`
- `getSettings() -> Flow<Settings?>`
- `getUpdatedItemsCountFlow() -> Flow<Int>`

Suspend (async on iOS):
- `getImageById(id) -> ImageItem?`
- `saveImageFromBitmap(bitmap, name, tags, parentId, rectangleOnParent) -> ImageItem`
- `saveImageFromUri(uri, name, tags, parentId) -> ImageItem`
- `createRoom(name, tags, parentId, bgColor?, textColor?) -> ImageItem`
- `updateImage(item)`
- `getAllUniqueTags() -> List<String>` — parses Gson-encoded tags strings
- `deleteImage(item, strategy: DeletionStrategy)` — three strategies
- `updateImageFromBitmap(current, bitmap) -> ImageItem` — resets `isUpdated=false`
- `updateImageFromUri(current, uri) -> ImageItem` — resets `isUpdated=false`
- `updateImageOrder(reorderedImages: List)` — rewrites `createdAt` with 1-second spacing
- `initializeDefaultRoomsIfNeeded()` — first-launch only via shared pref flag
- `checkOrphanedImages() -> List<ImageItem>` — filePath references missing files
- `removeOrphanedImages() -> Int` — also updates `lastOrphanedCheck`
- `exportData() -> String?` — path to zip in Downloads
- `importData(zipUri, mergeMode: Boolean) -> Boolean`
- `getUpdatedItemsCount() -> Int`
- Plus per-field settings update methods (16 of them)

### `DeletionStrategy` enum
- `DELETE_ALL_CHILDREN` — recursive cascade
- `ATTACH_CHILDREN_TO_PARENT` — orphan reparent (move children to deleted item's parent)
- `DELETE_ONLY_IF_NO_CHILDREN` — throws if children present

## Side effects on image replace
`updateImageFromBitmap` and `updateImageFromUri` both:
1. Delete the old `filePath` file
2. Write new file at `{filesDir}/images/{currentImage.id}_{currentImage.name}.jpg`
3. Set `filePath = thumbnail = newPath`
4. **Set `isUpdated = false`** (auto-drop the updated flag — this is FR-UPDATE-006)

## Default rooms creation
On first launch, three rooms with `filePath=null, parentId=null, rectangleOnParent=null`, `createdAt` spaced by 1 second:
- `My home`     (createdAt = baseTime)
- `Good things` (createdAt = baseTime + 1000)
- `Bad things`  (createdAt = baseTime + 2000)

Gated by SharedPreferences flag `default_rooms_created`.

## ML Kit usage
- **Object Detection** (`ObjectDetectionUtils`): `SINGLE_IMAGE_MODE`, `enableMultipleObjects()`, `enableClassification()`. Returns normalized 0..1 bounding boxes. Area-scoped detection: crops bitmap to area first, then re-maps boxes back to full-image coordinates. Label fallback: `"Object N"` if no classification.
- **Image Labeling** (`ImageLabelingUtils`): default options. `generateTitle()` returns top-confidence label or null. `getTopLabels(maxResults=3)` returns `[(text, confidence)]`.

iOS port: use `GoogleMLKit/ObjectDetection` and `GoogleMLKit/ImageLabeling` CocoaPods. Same API shapes. Wrap in Swift `ObjectDetectionService` and `ImageLabelingService` actors. Bitmap → `UIImage` → `MLKVisionImage`.

## Image scaling on save
`ImageUtils.scalePhotoForStorage(bitmap, minWidth: Int)` is invoked when `settings.scaleDownPhotos == true`. iOS port: implement a `UIImage` extension `scaleDown(minWidth: CGFloat)` that preserves aspect ratio and downsizes when `width > minWidth`.

## Tags parsing (matters for `getAllUniqueTags`)
Tags are stored as JSON strings like `["foo","bar"]` via Gson. The Android implementation does a hand-rolled parse (`removeSurrounding("[", "]")` then split by `,` then `removeSurrounding("\"")`) rather than JSON-parsing, presumably for tolerance to legacy bad data. iOS port should use `JSONDecoder.decode([String].self, ...)` with a try/fallback path that handles a single bare tag value as a degenerate case.

## Badge implementation
Android uses ShortcutBadger + an invisible IMPORTANCE_MIN notification on a channel `updated_items_badge_v2` with notification ID `1001`. The "invisible notification" trick is needed because some launchers only show badge counts from active notifications.

iOS equivalent: `UNUserNotificationCenter.current().setBadgeCount(_:withCompletionHandler:)` (iOS 16+) — no invisible notification needed; iOS supports app badges directly. Wire to a Combine subscription on the updated-items count + `showUpdatedBadge` setting.

## Reminders implementation
`UpdatedItemsReminderWorker` (WorkManager) — needs separate reading; uses periodic work request with frequency from `updatedRemindersFrequency` setting (`"weekly"` = 7 days, `"monthly"` = 30 days). Only fires notification when `getUpdatedItemsCount() > 0`.

iOS port: `BGTaskScheduler` with a `BGAppRefreshTaskRequest`. iOS does NOT guarantee schedule precision — it fires opportunistically. Document this in-app. Notification via `UNUserNotificationCenter`.

## Permissions needed (iOS Info.plist)
| Android permission | iOS equivalent |
|---|---|
| `CAMERA` | `NSCameraUsageDescription` |
| `READ_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES` | `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription` |
| `RECORD_AUDIO` | `NSMicrophoneUsageDescription` |
| `POST_NOTIFICATIONS` | request via `UNUserNotificationCenter.requestAuthorization` |
| `INTERNET` | not needed on iOS (allowed by default unless ATS blocks) |
| `BILLING` | not needed; StoreKit handled by RevenueCat |
| (none — Android has no speech permission) | `NSSpeechRecognitionUsageDescription` (for SFSpeechRecognizer) |

## Database migrations (1 → 12)
Reproduce only the FINAL v12 schema for iOS — no need to port migration steps unless we ever read a v1 import zip in the wild. Document v12 schema in `Models/ImageItem.swift` and `Models/Settings.swift`.

For the import path: the zip contains an Android Room DB. We have two options:
1. **Read it directly from iOS** using `sqlite3` C API or `GRDB.swift` (NOT SwiftData — SwiftData can't easily attach to an arbitrary file). Extract rows, transform, insert into our SwiftData container.
2. **Require Android-side export to a portable JSON format** instead of raw SQLite. Diverges from the existing Android export.

Option 1 is preferred for compatibility. The import path will use a small GRDB helper that opens the imported file as readonly, runs `SELECT * FROM images` and `SELECT * FROM settings`, and the Swift `ImageRepository` does the upsert into SwiftData.

## Open questions to resolve during implementation

1. `Settings.id` is always 1 in Android — SwiftData doesn't have a single-row constraint pattern. Use a `@Query` for the first record + `init-on-empty`.
2. Confirm `image_database-wal` and `-shm` files are safe to ignore on import (they're WAL/shm, regenerated on first open).
3. RevenueCat product IDs — need to confirm with friend, may need new App Store Connect IDs for the iOS bundle.
