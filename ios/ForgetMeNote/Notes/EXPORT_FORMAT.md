# Export zip format (cross-platform spec)

The Android app's export, produced by `ImageRepository.exportData()`, is the
authoritative format. The iOS app must produce and consume byte-compatible zips.

## Zip filename

```
forgetmenote_export_YYYY-MM-DD_HH-mm-ss.zip
```

Generated with `SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault())` —
i.e. **local time**, not UTC. iOS should match this for filenames produced on iOS.

## Zip entry layout

```
database/
  image_database              (SQLite database file, required)
  image_database-wal          (Write-Ahead Log, optional — present only if mid-transaction at export)
  image_database-shm          (Shared memory, optional — same)
images/
  {uuid}_{name}.jpg           (one entry per ImageItem with non-null filePath)
```

Entry names use forward slashes. No directory entries are written — the
`ZipOutputStream` only writes file entries.

## Database schema (v12) — what to read on import

The iOS importer opens `image_database` as a read-only SQLite file (via GRDB.swift
or raw sqlite3) and SELECTs from two tables.

### `images` table columns (v12)
```
id                   TEXT PRIMARY KEY NOT NULL
name                 TEXT NOT NULL
tags                 TEXT NOT NULL DEFAULT '[]'    (Gson JSON: ["a","b"])
thumbnail            TEXT
filePath             TEXT
parentId             TEXT
childIds             TEXT NOT NULL DEFAULT '[]'    (Gson JSON)
rectangleOnParent    TEXT                          (Gson JSON: {"x":..,"y":..,"width":..,"height":..})
createdAt            INTEGER NOT NULL              (epoch millis)
roomBackgroundColor  INTEGER                       (ARGB packed)
roomTextColor        INTEGER                       (ARGB packed)
notes                TEXT NOT NULL DEFAULT ''
isUpdated            INTEGER NOT NULL DEFAULT 0    (boolean)
```

### `settings` table columns (v12)
```
id                                  INTEGER PRIMARY KEY NOT NULL
childRectangleTransparency          REAL NOT NULL DEFAULT 0.25
childRectangleBorderWidth           REAL NOT NULL DEFAULT 3.0
childRectangleBorderTransparency    REAL NOT NULL DEFAULT 0.4
enableTagsListEdit                  INTEGER NOT NULL DEFAULT 1
checkOrphanedImages                 INTEGER NOT NULL DEFAULT 1
lastOrphanedCheck                   INTEGER NOT NULL DEFAULT 0
searchThroughCollapsedImages        INTEGER NOT NULL DEFAULT 1
roomBackgroundColor                 INTEGER NOT NULL DEFAULT 4284960420   (0xFF6750A4)
roomTextColor                       INTEGER NOT NULL DEFAULT 4294967295   (0xFFFFFFFF)
updatedHighlightColor               INTEGER NOT NULL DEFAULT 4294948096   (0xFFFF9800)
updatedHighlightPercentage          REAL NOT NULL DEFAULT 0.2
showUpdatedBadge                    INTEGER NOT NULL DEFAULT 1
updatedRemindersEnabled             INTEGER NOT NULL DEFAULT 0
updatedRemindersFrequency           TEXT NOT NULL DEFAULT 'weekly'
scaleDownPhotos                     INTEGER NOT NULL DEFAULT 1
scaleDownMinWidth                   INTEGER NOT NULL DEFAULT 740
```

## On-import rewrite of `filePath`/`thumbnail`

Imported `ImageItem` rows have `filePath` and `thumbnail` pointing at Android's
`/data/data/com.imageorganizer.app/files/images/{uuid}_{name}.jpg`. The iOS
importer must rewrite both to point at the iOS app's documents directory,
extracting the basename and reconstructing the path.

```swift
let basename = (oldPath as NSString).lastPathComponent
let newPath = imagesDirectory.appendingPathComponent(basename).path
```

## Merge mode vs replace mode

`importData(zipFileUri, mergeMode: Boolean)` — iOS implements both.

**Merge mode (`mergeMode = true`):**
1. Extract zip to temp directory
2. Copy any images not already in our images dir (no overwrite — keep existing if name collision)
3. Open the imported SQLite as read-only
4. SELECT all images, split into parents (`parentId IS NULL`) and children
5. For each imported parent:
   - If our DB has no row with this `id`: insert it (with rewritten paths)
   - Else: union `childIds` between existing and imported, update
6. For each imported child:
   - Skip if its `parentId` doesn't exist in our DB
   - If new: insert; append `id` to parent's `childIds` if missing
   - If existing: update; sync parent's `childIds`; if parent changed, remove from old parent's `childIds`
7. Final pass: for every image, if its `parentId` is set but parent's `childIds` doesn't include it, fix the parent

**Replace mode (`mergeMode = false`):**
1. Close current SwiftData container
2. Delete current SQLite file (and -wal, -shm if present)
3. Wipe images directory
4. Copy imported SQLite and images
5. Reopen SwiftData container

The iOS port should default to merge mode — Android's UI defaults to merge as well.

## Notes on SwiftData vs raw SQLite

SwiftData uses its own internal schema metadata. We **cannot** drop the imported
`image_database` file into the SwiftData container — its schema metadata won't
match. The iOS importer must:
1. Open the Android DB file as raw SQLite (via `GRDB.swift` or `sqlite3` C API).
2. Read out rows as plain structs.
3. Insert/update them into the iOS SwiftData `ModelContainer` via our `ImageRepository`.

Replace mode therefore is also "extract, then bulk-insert into a fresh SwiftData
container" — not a literal file swap.

This is the one place where the "single shared format" pays for itself: a user
can move from Android to iOS by emailing a zip, and we will preserve the entire
hierarchy, all notes, all updated flags, and all settings.
