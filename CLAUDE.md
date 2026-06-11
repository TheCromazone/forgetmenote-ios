# CLAUDE.md — ForgetMeNote v3

This file orients any future Claude Code session on this project. Read it
end-to-end before making any changes.

---

## What this project is

**ForgetMeNote v3** is a native iOS app — a visual-memory organizer that
lets users photograph physical spaces (rooms, drawers, shelves) and draw
rectangles inside each photo to create child "sub-spaces" recursively. The
result is a tree that mirrors physical reality:
*Living Room → Bookshelf → Top Shelf → Specific Book*.

It is a **third iteration** of the same product. The lineage is:

| Version | Source repo | Status |
|---------|-------------|--------|
| Android v1.3.7 | `github.com/zhum/forgetmenote-v2.git` (Kotlin + Compose) | Original — untouched |
| iOS v2 (`com.matthewcromaz.forgetmenote.dev`) | `~/Documents/foregtmenote-v2/ios/` | Native SwiftUI port; Material 3 aesthetic; ships separately |
| iOS v3 (`com.matthewcromaz.forgetmenote.v3.dev`) | `~/Documents/forgetmenotev3/ios/` | **This project — Claude Code's version.** Mounts `V3RootView`. |
| iOS v4 (`com.matthewcromaz.forgetmenote.v4.dev`) | same repo, `ForgetMeNote/V4/` | **Codex's version.** A separate app target (`ForgetMeNoteV4`, flagged `-D FMN_V4`) mounting `V4RootView`. **Do NOT modify** — use only as inspiration. |

### ⚠️ Three apps build from THIS one repo — know which is which

`project.yml` defines **three app targets** that install side-by-side on the
iPhone with different icons/bundle IDs:

| Target / scheme | Flag | Bundle | Root view | Owner |
|---|---|---|---|---|
| `ForgetMeNote` | (none) | `…forgetmenote.v3.dev` | `V3RootView` | **Claude Code (work here)** |
| `ForgetMeNoteV4` | `-D FMN_V4` | `…forgetmenote.v4.dev` | `V4RootView` | **Codex (do not touch)** |
| (older v2) | — | `…forgetmenote.dev` | v2 `RootView` | legacy |

`ForgetMeNoteApp.swift` chooses the root via `#if FMN_V4 → V4RootView else
V3RootView`. The default scheme/build commands here build the **`ForgetMeNote`
target → v3**. When the user says "it's not working," first confirm **which app
icon** they opened (FMN v3 vs FMN v4) — they are different binaries.

**Read-only from v3 work:** `ForgetMeNote/V4/*` (Codex), `ForgetMeNote/Views/*`
(legacy v2, incl. `InteractiveRectangleSelector`, `CreateChildScreen`,
`ImageDetailScreen`), and `ForgetMeNote/ML/*` are **shared/legacy**. Call their
public APIs but do **not** edit them — edits ripple into v2 and Codex's v4. Do
NOT touch the separate v2 repo at `~/Documents/foregtmenote-v2/` either.

---

## Where things are

```
~/Documents/forgetmenotev3/
├── CLAUDE.md                 ← this file
├── README.md                 ← quickstart for humans
└── ios/
    ├── project.yml           ← xcodegen spec (bundle ID, Info.plist, deps)
    ├── Podfile               ← CocoaPods (ML Kit + RevenueCat, ML Kit optional via SKIP_MLKIT env)
    ├── TESTFLIGHT.md         ← App Store Connect / TestFlight upload steps
    ├── ForgetMeNote.xcworkspace  ← OPEN THIS, not .xcodeproj
    ├── ForgetMeNote/
    │   ├── ForgetMeNoteApp.swift  ← @main; `#if FMN_V4` → V4RootView, else V3RootView
    │   ├── Assets.xcassets/AppIcon.appiconset/  ← teal closet icon
    │   ├── PrivacyInfo.xcprivacy  ← App Store privacy manifest
    │   │
    │   ├── Models/           ← @Model classes: ImageItem, AppSettings, Rectangle, DetectedObjectInfo
    │   ├── Repository/       ← @ModelActor: ImageRepository (CRUD + per-field updates + orphans)
    │   ├── Camera/           ← UIImagePickerController wrap, TempPhotoStore, DemoImage
    │   ├── ML/               ← ObjectDetectionService, VisionClassificationService, ImageLabelingService
    │   ├── Notifications/    ← AppIconBadge, UpdatedItemsReminder (BGTaskScheduler)
    │   ├── Utils/            ← ExportImportService (zip)
    │   ├── Theme/            ← v2's AppColors (Material 3 palette + Color(hex:/argb:) extensions)
    │   │
    │   ├── Views/            ← LEGACY v2 screens — kept intact for navigation reuse
    │   │   ├── RootView.swift         ← v2 root (NOT mounted by v3)
    │   │   ├── Route.swift            ← shared route enum
    │   │   ├── CustomBackButton.swift
    │   │   ├── Walkthrough/           ← v2 walkthrough overlay
    │   │   ├── Components/            ← NotesDialog, InteractiveRectangleSelector, ChildBoundingBoxOverlay, DetectedObjectOverlay, ZoomableImageOverlay, ShareSheet, StubPaywallView
    │   │   └── Screens/               ← MainScreen, ImageDetailScreen, CreateChildScreen, SettingsScreen, HelpScreen
    │   │
    │   ├── V3/               ← V3 (Claude Code's version) — work here
    │   │   ├── Theme/V3Theme.swift        ← forget-me-not / forest / clay palettes + hue picker
    │   │   ├── Theme/V3Typography.swift   ← Instrument Serif helpers + small-caps modifier
    │   │   ├── Vision/V3VisionService.swift     ← on-device detection (Apple Vision masks + ML Kit fusion)
    │   │   ├── Vision/V3DetectionGeometry.swift ← pure displayRect/IoU helpers (unit-tested)
    │   │   ├── Vision/V3ImageDownsampler.swift  ← ImageIO downsampling (crop-screen perf)
    │   │   ├── Components/FlowerMark.swift       ← 5-petal flower (SwiftUI Canvas)
    │   │   ├── Components/V3RoomTile.swift       ← colored card with big serif initial
    │   │   ├── Components/V3CaptureFAB.swift     ← glass capture circle beside the tab bar
    │   │   ├── Components/V3DetectionOverlay.swift ← glowing mask silhouettes + label capsules
    │   │   ├── Components/V3CropBox.swift        ← reusable 4-corner-handle crop box
    │   │   ├── Screens/V3WelcomeScreen.swift     ← flower scatter + "Remember where things live"
    │   │   ├── Screens/V3HomeScreen.swift        ← greeting + carousel + room grid
    │   │   ├── Screens/V3FindScreen.swift        ← search + tags + recent
    │   │   ├── Screens/V3RoomScreen.swift        ← room → places grid (taps photo → V3SpaceScreen)
    │   │   ├── Screens/V3SpaceScreen.swift       ← single photo + sub-space rects + "Find objects" detection
    │   │   ├── Screens/V3CreateSubScreen.swift   ← create sub-space; OPT-IN crop box (V3CropBox)
    │   │   └── V3RootView.swift                  ← TabView (Home/Find/You), welcome gate, capture flow
    │   │
    │   └── V4/               ← Codex's version (target ForgetMeNoteV4). DO NOT MODIFY.
    │       └── V4RootView.swift, V4Screens.swift, V4Components.swift, V4Theme.swift, V4FindYouSheets.swift, V4AuthConcept.swift
    │
    ├── ForgetMeNoteTests/
    ├── qa/maestro/flows/
    │   ├── v3_full_qa.yaml    ← v3 end-to-end Maestro flow (passes 100%)
    │   └── (older v2 flows kept for reference)
    └── scripts/generate_app_icon.py  ← Python/PIL fallback icon generator
```

### Key principle

**v3 now has its own full screen stack.** The drill-down flow uses native v3
screens: `V3RoomScreen` (room → places grid) → `V3SpaceScreen` (single photo,
sub-space rectangles, "Find objects" detection) → `V3CreateSubScreen` (create a
sub-space with an opt-in crop box). Navigation routes through
`Route.v3Room` / `Route.v3Space` / `Route.v3CreateSub` in
`V3RootView.destination(for:)` — v3 no longer falls back to the v2
`ImageDetailScreen`/`CreateChildScreen`. The shared `Views/Screens/SettingsScreen`
is still reused (via `V3SettingsScreen`). New v3 work goes under `V3/`; the
shared `Views/*` and `ML/*` are read-only (see the three-apps warning above).

---

## Current state — what works, what doesn't

### Working
- ✅ Build → device-install → side-by-side launch with v2
- ✅ First-launch welcome screen (flower scatter, serif headline)
- ✅ Home: greeting, "Hi Sam, welcome back" headline, flower stat row, room grid (with serif initials), "Lately remembered" carousel, tip card
- ✅ Find tab: serif title, pill search, popular-tag chip cloud, recent searches list, real-time results
- ✅ You tab: stat cards (places / updated / tags), Settings / Help / Show walkthrough action list
- ✅ Tab navigation works (Home / Find / You with accent tint)
- ✅ Settings (v2 legacy screen) reachable via You → Settings — fixed in v3 by injecting `WalkthroughViewModel` into the environment
- ✅ Walkthrough restart via You → Show walkthrough presents the `V3Walkthrough` guided-tour overlay (4 pages, Skip/Next; id `v3-walkthrough`, buttons `v3-tour-skip`/`v3-tour-next`)
- ✅ Glass capture FAB (`V3CaptureFAB`) sits beside the tab bar; opens the capture sheet
- ✅ v3 detail flow: `V3RoomScreen` → `V3SpaceScreen` → `V3CreateSubScreen` (all native v3)
- ✅ **On-device object detection wired into v3** (`V3VisionService`, surfaced on `V3SpaceScreen` "Find objects"): Apple Vision instance-segmentation masks + ML Kit detector boxes merged + fused Vision/ML Kit labels; glowing mask outlines via `V3DetectionOverlay`; tap an object → "Add ✦" → create sub-space with box+name prefilled
- ✅ **Opt-in cropping** in `V3CreateSubScreen`: crop box hidden by default, revealed by "Mark the exact spot ✦"; reusable `V3CropBox` has four working corner handles (drag-start latch); image downsampled + `.drawingGroup()` for no lag
- ✅ App-icon badge for updated-items count
- ✅ Mark-as-Updated toggle uses the `@State` mirror pattern (no snap-back)
- ✅ Privacy manifest declared, AppIcon registered, BGTaskScheduler ID matches Info.plist
- ✅ **P1/P2 polish pass (2026-06-03):** off-main thumbnail cache (`V3Thumbnail`) backs all cards/grids/carousels (no more synchronous full-res decodes); `V3SpaceScreen` hero decodes once off-main and feeds sub-cards; crop box + detection overlay rasterize via `.drawingGroup()` (the latter was MISSING despite the old doc claim); O(n²) parent/child scans replaced with one-pass dicts; haptics (`V3Haptics`) across capture/save/delete/toggles; `V3PressableButtonStyle` press feedback; real `@AppStorage` recent searches (Find); Home search button wired to the Find tab; "Add a place" routes to native `V3CreateSubScreen` (not legacy `CreateChildScreen`); capture/tab navigation resets stale stacks; orphan-file sweep wired into root `.task`; v3-native `V3PaywallSheet` on the Pro CTAs; Dynamic-Type-aware `V3Font`; `V3Switch` exposes `accessibilityValue`.
- ✅ **Auto-label after capture (NEW):** `V3VisionService.suggestName(imagePath:)` classifies a freshly captured photo on-device (Apple Vision, Simulator-safe) and pre-fills the new place's name in `V3CreateSubScreen` when the user hasn't typed one — mirrors v4's behavior.
- ✅ **Icon delete (2026-06-09):** rooms/places can be deleted right from their icons — a trash button overlays the SELECTED carousel card (`v3-card-delete-<id>`), and every carousel card + hierarchy-tree row has a long-press context menu (Open / Delete). Both confirm via alert then `ImageRepository.delete(.deleteAllChildren)`. Wired in `V3BrowseHome` AND `V3RoomScreen` via optional `onDelete` on `V3SpaceCarousel`/`V3HierarchyTree`. The 3-dot → detail-sheet delete still works.
- ✅ **Search jumps to the thing (2026-06-09):** Find result taps route via pure `v3SearchDestination(for:)` (unit-tested): photo/sub-picture → `V3SpaceScreen` directly; room/empty box → `V3RoomScreen`. `V3RoomScreen` now expands the target's ANCESTORS on appear (deep items were invisible — flatten() needs all ancestors expanded) and `V3SpaceCarousel` re-applies its scroll position one runloop after appear (initial `scrollPosition` landed on the first card). Result taps also record the query into recent searches.
- ⚠️ **a11y gotcha:** a bare `.accessibilityIdentifier` on a CONTAINER (e.g. the room screen's `V3NavHeader`) collapses the subtree — child ids like `v3-room-menu` vanish from Maestro/XCUITest. Pair it with `.accessibilityElement(children: .contain)`.
- ✅ **Gemini enhanced scan (2026-06-10):** `V3/Vision/V3GeminiVisionService.swift` calls `gemini-2.5-flash` (`generateContent`, `x-goog-api-key` header, JSON `box_2d` [ymin,xmin,ymax,xmax]/1000 → `DetectedObjectInfo`) when a key is set AND `v3_gemini_enabled` (default true); `V3SpaceScreen.runDetection` prefers it and falls back SILENTLY to on-device `V3VisionService` (no key / disabled / offline / error / empty). Model overridable via `v3_gemini_model`; Info.plist `GeminiAPIKey` fallback. Free tier ≈10 RPM / 1,500 req/day, no card. Parsing is pure + unit-tested (`V3GeminiVisionTests`). For App Store: move the key behind a cloud-function proxy (Sergey's pattern) + paywall hook.
- ✅ **Gemini model-fallback chain (2026-06-10):** free-tier `gemini-2.5-flash` intermittently 503s ("model overloaded", Google-side) and occasionally returns empty arrays. `V3GeminiVision.detect` now walks `candidateModels` (override → `gemini-2.5-flash` → `gemini-2.5-flash-lite` → `gemini-flash-latest` rolling alias) until one returns objects; 503/429/404/empty each advance the chain (unknown ids just 404 past). Per-attempt timeout 20s. Mock server 503s the primary so both the unit fallback test AND the Maestro E2E prove the rescue (`grep POST /tmp/mock_gemini.log` shows 503→flash-lite 200). The key itself (aistudio.google.com/apikey, "AIza…") is the right kind — 503 is load, not auth.
- ✅ **Gemini scan really verified + diagnosable (2026-06-10):** root cause of "key set but looks like Apple Vision": with `responseMimeType` json but NO schema, Gemini often wraps the array (`{"objects": [...]}`) → parse → 0 results → silent fallback. Fixed: `responseSchema` forces a bare array, parser also unwraps object-wrapped arrays, and `runDetection` now SHOWS the fallback reason ("Enhanced scan unavailable (HTTP 429) — used on-device scan"). Success shows "Enhanced scan ✦ Gemini". Verified 3 ways: URLProtocol-mocked E2E unit tests (`V3GeminiVisionE2ETests` assert request header/base64 image/schema + parse), a REAL-HTTP sim E2E (`qa/mock_gemini_server.py` on 127.0.0.1:8765 + `v3_gemini_scan.yaml` — 100% green incl. the ✕ clear), and live endpoint/key validation at setup. QA hooks: `v3_gemini_endpoint`/`v3_gemini_api_key`/`v3_gemini_model` read from UserDefaults OR launch args (Maestro `launchApp: arguments:`); sim-only `-fmnSeedPhoto` seeds a "Demo shelf" photo space (DemoImage) so photo flows are Maestro-testable; `V3GeminiVision.session` injectable for tests.
- ✅ **True-aspect photos (2026-06-10):** `V3SpaceScreen` hero uses the image's REAL aspect ratio (`heroAspect`, clamped 0.45–2.4) instead of a fixed 4:5 crop — full picture (esp. traced sub-space slices) visible WITHOUT Zoom, and since the image fills the frame uncropped the normalized rect overlays now align exactly. `V3SubScanCard` width likewise follows the sub-region's true aspect (fixed 224 height, width clamped 112–280) so "What's inside" cards stop stretching crops.
- ✅ **Guided Gemini key setup (2026-06-10):** `V3/Sheets/V3GeminiKeySheet.swift` — 3-step in-app flow: "Open" launches `https://aistudio.google.com/apikey` (`v3-gemini-get-key`), one-tap clipboard "Paste" (`v3-gemini-paste`), then "Verify & turn on ✦" (`v3-gemini-verify`) live-validates via `V3GeminiVision.validateKey` (GET model metadata, no quota) and only SAVES a key that works. Entry points: `V3SpaceScreen` "Want better scans? Set up free AI ✦" link under Find objects (`v3-space-enhance-setup`, hidden once a key is saved) and Settings → AI scanning (`v3-settings-gemini-setup` opens the sheet; `v3-settings-gemini-toggle` switches Gemini ⇄ on-device Apple Vision while keeping the key). Remove-key button returns to on-device-only.
- ✅ **AI scan is dismissible (2026-06-10):** when detections are showing with none selected, the bar is now [Scan again | ✕] (`v3-space-clear-scan`) so a bad scan can be cleared without re-scanning; entering Draw-a-spot also auto-clears any leftover detections so drawing starts on a clean photo.
- ✅ **Draw-a-spot offers Box AND Trace up front (2026-06-09):** `V3SpaceScreen`'s draw mode has a Box/Trace shape toggle (`v3-space-draw-mode-box`/`-trace`) reusing `V3TraceBox`; confirm is disabled until a trace has ≥3 points. The freehand outline reaches `V3CreateSubScreen` via the one-shot `V3PendingTrace` stash (`V3/Components/V3PendingTrace.swift`) — `Route.v3CreateSub` CANNOT grow an associated value because the read-only v2 `RootView` + v4 `V4RootView` destructure that case with exact arity. CreateSub consumes the stash `onAppear` and opens in trace mode with the shape preserved; its existing save path persists `traceOnParent` + bounding box.
- ⚠️ Maestro `qa/maestro/flows/v3_full_qa.yaml` was reworked and is **logically green** — every step verified passing across runs (social-stub sign-in entry to dodge the iOS-26.5-sim `SecureField` flakiness; conditional welcome; robust accessibility-id assertions). The keyboard/`SecureField` sign-up fix itself is real and proven (app-side `v3-keyboard-done` toolbar + reveal-via-eye); a dedicated `v3_signup.yaml` should cover it. **Caveat:** a single uninterrupted ~38-step run is hard to land on a memory-pressured host — killed runs orphan xcodebuild test-runners that OOM-kill the next run. See `memory/feedback-maestro-ios26.md` (points 5–8): uninstall v4/v2 from the sim, `pkill` stale `maestro`/`xcodebuild test`/`XCTRunner` between runs, keep flows short. New focused flows added: `v3_create_room`, `v3_delete_return`, `v3_search`, `v3_settings_toggle`, `v3_walkthrough_signout`, `v3_icon_delete`, `v3_search_navigate` (the last two cover icon-delete + search direct-jump; `v3_create_room`/`v3_delete_return` were updated 2026-06-09 for the V3BrowseHome home — the old ones targeted the unmounted `V3HomeScreen` grid).

### Deferred / known gaps

| Area | Status | What to do when picking it up |
|------|--------|------|
| `V3HomeScreen` "New room" button | ✅ DONE | Wires `showNewRoom` → `V3NewRoomSheet` (hue picker + name) → `ImageRepository.createRoom(...)`. id `v3-home-new-room`. |
| Delete → strand bug | ✅ FIXED (2026-06-03) | `V3DetailSheet.onDeleted` pops the parent NavigationStack after a successful delete (dispatched one runloop after `dismiss()`); `V3SpaceScreen`/`V3RoomScreen` also self-heal via `.onChange(of: matches.isEmpty)` and the not-found branch now has a working `V3NavHeader` back + `V3EmptyState`. Guarded by `v3_delete_return.yaml`. |
| `V3SettingsScreen` (native vs v2 legacy) | ✅ DONE | `V3/Screens/V3SettingsScreen.swift` is fully native v3 (own `V3NavHeader`, sliders, `@State`-mirror search toggle). The route `.settings` already mounts it; the v2 legacy `SettingsScreen` is no longer used by v3. |
| Recursive cascade delete (parentId vs childIds) | ✅ already-correct | `ImageRepository.deleteRecursive` walks `childItems(for:)` which UNIONS `childIds` + `children(of:)` (parentId query), so no child is stranded and photo files are removed. (The earlier "trusts only childIds" concern was stale.) |
| Room color persistence | ✅ DONE | `V3NewRoomSheet` stores ARGB bg/fg and `V3Theme.hue(for: item)` reads them; `V3HomeScreen`/`V3RoomScreen` call the `hue(for: item)` overload. |
| Capture (+) FAB | ✅ DONE | `V3CaptureFAB` glass circle beside the tab bar opens `V3CaptureSheet`. Bottom padding (`.padding(.bottom, 6)` in `V3RootView`) may want on-device fine-tuning. |
| v3 detail navigation | ✅ DONE | Room tile → `Route.v3Room` → `V3RoomScreen`; photo → `Route.v3Space` → `V3SpaceScreen`. No longer routes to v2 `ImageDetailScreen`. |
| Detection more objects | Possible future upgrade | `V3VisionService` already fuses Vision masks + ML Kit. To detect even more/smaller items, a bundled CoreML detector (e.g. YOLO) is the next step (model file + licensing). |
| Instrument Serif font | Falls back to system serif | Drop the OTF files into `ForgetMeNote/Fonts/`, register `UIAppFonts` array in Info.plist (`InstrumentSerif-Regular.otf`, `InstrumentSerif-Italic.otf`). Then `V3Font.headline()` actually uses them. |
| Drag-to-reorder | Inherited broken state from v2 | v2 uses `.onMove` on root-level rows only (flat-list refactor); not surfaced in v3 UI yet. |
| `V3YouScreen` stat values | Counts are correct but the layout is plain | Could match the JSX `screens-secondary.jsx` more precisely (illustrated cards). |
| Cross-platform import from Android | Not wired | iOS export → iOS import works (JSON manifest). Android's `forgetmenote.db` (Room SQLite) format is incompatible without a bridge. |
| RevenueCat real IAP | Stub-only | v3 now has its own native `V3/Sheets/V3PaywallSheet` shell wired to the Settings Pro CTAs (`onStartTrial` is the hook). Real flow still requires a RevenueCat account + App Store Connect product. (Do NOT use the legacy `StubPaywallView` — it's in read-only `Views/*`.) |

### Source design reference

The v3 visual + interaction design comes from a React prototype the user
provided. Extracted prototype lives at `/tmp/fmnv3-design/` (not in the
repo) — files include `theme.jsx`, `screens-home.jsx`, `screens-space.jsx`,
`screens-secondary.jsx`, etc. When porting more screens, **read the JSX
prototype first** — it has the exact spacing, copy, animations, and
component behavior intended.

---

## How to build, install, QA

### Prerequisites (one-time)
- Xcode (latest), iOS SDK 26+
- Homebrew + `brew install cocoapods` + `brew install --cask maestro` (and `brew install mobile-dev-inc/tap/maestro` if the cask is wrong)
- `brew install xcodegen`
- Apple Developer Program active (paid, $99/yr). Team ID: `DBCJXPJXQJ`.
- `JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home` for Maestro
- `LANG=en_US.UTF-8` for CocoaPods (added to `~/.zshrc`)

### Build for iPhone (device)
```bash
cd ~/Documents/forgetmenotev3/ios
xcodegen generate
pod install
JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote \
    -configuration Debug \
    -destination "id=E7A0CD3B-A97A-5548-A204-E046CA2ACAFD" \
    -allowProvisioningUpdates build
```

Install + launch (iPhone unlocked):
```bash
APP=~/Library/Developer/Xcode/DerivedData/ForgetMeNote-*/Build/Products/Debug-iphoneos/ForgetMeNote.app
xcrun devicectl device install app --device E7A0CD3B-A97A-5548-A204-E046CA2ACAFD "$APP"
xcrun devicectl device process launch --device E7A0CD3B-A97A-5548-A204-E046CA2ACAFD com.matthewcromaz.forgetmenote.v3.dev
```

### Build for iOS Simulator (Maestro QA)
ML Kit ships device-only binaries (no arm64-Simulator slice). For Sim
builds, skip the ML Kit pods:
```bash
cd ~/Documents/forgetmenotev3/ios
SKIP_MLKIT=1 LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install
JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote \
    -configuration Debug \
    -destination "generic/platform=iOS Simulator" \
    -allowProvisioningUpdates ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build

SIM_APP=~/Library/Developer/Xcode/DerivedData/ForgetMeNote-*/Build/Products/Debug-iphonesimulator/ForgetMeNote.app
xcrun simctl install booted "$SIM_APP"
```

After Sim QA, restore ML Kit:
```bash
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install   # without SKIP_MLKIT
```

### Run Maestro QA
```bash
cd ~/Documents/forgetmenotev3/ios
JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  maestro test qa/maestro/flows/v3_full_qa.yaml
```

The flow is **23 steps** and should pass 100% on a clean Sim install.
Screenshots land in the working directory `v3_01_welcome.png` … `v3_09_home_final.png`.

---

## Conventions any future Claude session must follow

### Code style
- Swift 5.10, iOS 17.0+ deployment target.
- Prefer `@Observable` (Swift 5.9+) over `ObservableObject`.
- All SwiftData mutations on `ModelContext.mainContext` from the main actor; long-running work in a `@ModelActor` (see `ImageRepository`).
- For UI toggles bound to `@Model` properties, use the **@State mirror pattern** (see `UpdatedToggleRow` in `ImageDetailScreen.swift`). Do NOT bind a Toggle directly to a SwiftData property — there's a regression history of snap-back.
- All identifiers added for Maestro must use `.accessibilityIdentifier("…")`. Prefix v3-specific IDs with `v3-` (e.g. `v3-search-input`, `v3-welcome-start`).
- ML services must guard with `#if !targetEnvironment(simulator)` for ML Kit code paths. Apple Vision works fine in the Simulator.

### Project structure rules
- New v3 screens go under `V3/Screens/`. New v3 components under `V3/Components/`. Theme tokens under `V3/Theme/`. Vision/ML helpers under `V3/Vision/`.
- **Do NOT modify `ForgetMeNote/V4/*`** — that's Codex's app; only read it for inspiration.
- Do NOT modify legacy `Views/*` or `ML/*` (shared with v2 + v4). Call their public APIs; if you truly must edit, keep it strictly additive (e.g. a new method, or an enum case with defaulted associated values so existing pattern-matches still compile).
- **This working tree IS a git repo (since 2026-06-10)** — pushed to `github.com/TheCromazone/forgetmenote-ios` (origin, branch `main`) and as branch `ios-v3-port` toward Sergey's `github.com/zhum/forgetmenote-v2`. Generated artifacts (`Pods/`, `.xcodeproj`, `.xcworkspace`, QA PNGs) are gitignored — always `xcodegen generate && pod install` after cloning. Commit only when the user asks.
- Any new pod dependency goes in the `Podfile`; wrap with the `unless ENV['SKIP_MLKIT']` block ONLY if it's device-only.
- New Info.plist keys go in `project.yml`'s `info.properties` (do not hand-edit `Info.plist` — xcodegen regenerates it).

### Bundle ID hygiene
- v3 production bundle ID: `com.matthewcromaz.forgetmenote.v3.dev`
- BGTaskScheduler identifier MUST match in both `project.yml` (`BGTaskSchedulerPermittedIdentifiers`) and `UpdatedItemsReminder.taskIdentifier`. If you change one, change the other.

### Working with the user
- The user iterates rapidly ("vibecoding") and wants a working demo by end of week to show a friend in person.
- iPhone UDID for direct device commands: `E7A0CD3B-A97A-5548-A204-E046CA2ACAFD`.
- After significant code changes, always rebuild + reinstall on the iPhone. Pure simulator-only verification has missed bugs before (Toggle snap-back was iPhone-specific).
- The user's iPhone uses iOS 26.5 dev beta. Some Maestro behaviors are quirky on that beta — text-based `tapOn` sometimes misses; prefer accessibility ID or point coordinates for tab bars (tab bar tap zones: 28% / 50% / 70% screen-x at y=96%).

### When picking up new work
1. Read this file first.
2. `git log` (if a git repo exists) or `ls -lt` in the relevant folder to see recent activity.
3. Run the Maestro suite to confirm baseline is still green BEFORE touching anything: `maestro test qa/maestro/flows/v3_full_qa.yaml`.
4. Make the change.
5. Build for iPhone, install, ask the user to verify visually if the change is UI.
6. Re-run Maestro suite to confirm no regressions.
7. Commit (only when the user explicitly asks).

### Things that have broken before — be careful with these
- **The "Mark as Updated" toggle** snapped back twice before the `@State` mirror pattern landed. Don't touch `UpdatedToggleRow` without testing the cycle on hardware.
- **ML Kit arm64-Simulator linking** fails — must use `SKIP_MLKIT=1 pod install` for Sim builds.
- **Maestro physical-device driving** is currently blocked because `idb_companion 1.1.8` can't see iOS 26+ devices over wireless pairing. All Maestro runs target the Simulator.
- **SwiftUI Text concatenation (`Text + Text`)** is exposed as a single accessibility node — Maestro can't find individual text fragments with text-based `tapOn` or `assertVisible`. Use accessibility IDs or fall back to unconcatenated standalone strings.
- **iOS keyboard occludes tab bar buttons** — `hideKeyboard` Maestro action doesn't always work. Either skip text-input flows or tap a non-input element to dismiss.

---

## Roadmap (rough)

### Phase 9 (this iteration) — DONE
- Side-by-side install of v3 on iPhone with new closet icon
- forget-me-not theme, FlowerMark, V3RoomTile, V3HomeScreen, V3FindScreen, V3YouScreen, V3WelcomeScreen
- Tab navigation
- Maestro v3 QA suite passing
- CLAUDE.md + README handoff docs

### Phase 10 — DONE (2026-05-29)
- ✅ `V3RoomScreen`, `V3SpaceScreen`, `V3CreateSubScreen` ported and wired
- ✅ Capture FAB (glass circle) in place
- ✅ On-device detection wired into v3 (`V3VisionService` + `V3DetectionOverlay`)
- ✅ Opt-in cropping with working corner handles (`V3CropBox`) + no-lag downsampling

### Phase 10.5 — fine-tune / polish pass — DONE (2026-06-03)
- ✅ Fixed the #1 delete→strand bug (auto-pop + self-heal + non-dead-end not-found)
- ✅ Reworked the Maestro suite to logical-green (social-stub entry, conditional welcome, robust ids; keyboard/SecureField sign-up fix proven app-side)
- ✅ Performance pass: off-main thumbnail cache, single hero decode, `.drawingGroup()` on crop + detection overlay, O(n²)→dict lookups, vision working-image cache
- ✅ Auto-label after capture (`V3VisionService.suggestName`)
- ✅ Haptics, pressable button style, real recent searches, native paywall shell, orphan sweep, tab/stack resets, Dynamic-Type fonts, switch a11y values
- ✅ New Maestro flows + unit tests (AuthStore / search-filter / cascade-delete)
- ⬜ Bundle Instrument Serif font files (still falls back to system serif)
- ⬜ On-device hardware verification pass (device was `unavailable` during this pass — needs the iPhone unlocked + trusted)
- ⬜ (Optional) on-device FAB bottom-padding fine-tune

### Phase 11 — paywall + ship
- Real RevenueCat IAP after the user creates the App Store Connect product (wire into `V3PaywallSheet.onStartTrial`)
- TestFlight upload (see `ios/TESTFLIGHT.md` for the checklist)

---

## Useful one-liners

```bash
# Confirm both apps installed on iPhone
xcrun devicectl device info apps --device E7A0CD3B-A97A-5548-A204-E046CA2ACAFD | grep -E "forgetmenote|FMN"

# Quick rebuild + reinstall + launch (iPhone unlocked)
cd ~/Documents/forgetmenotev3/ios && \
  xcodegen generate && pod install && \
  JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote -configuration Debug \
    -destination "id=E7A0CD3B-A97A-5548-A204-E046CA2ACAFD" -allowProvisioningUpdates build && \
  xcrun devicectl device install app --device E7A0CD3B-A97A-5548-A204-E046CA2ACAFD \
    ~/Library/Developer/Xcode/DerivedData/ForgetMeNote-*/Build/Products/Debug-iphoneos/ForgetMeNote.app && \
  xcrun devicectl device process launch --device E7A0CD3B-A97A-5548-A204-E046CA2ACAFD \
    com.matthewcromaz.forgetmenote.v3.dev

# Regenerate placeholder app icon (only if you don't have the user's ChatGPT-generated PNG)
python3 ios/scripts/generate_app_icon.py
```
