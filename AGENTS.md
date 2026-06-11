# AGENTS.md — ForgetMeNote v3

This file orients any future Codex session on this project. Read it
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
| iOS v3 (`com.matthewcromaz.forgetmenote.v3.dev`) | `~/Documents/forgetmenotev3/ios/` | **This project.** Same codebase as v2 plus a `V3/` design overhaul folder |

v2 and v3 are installed **side by side** on the user's iPhone with different
icons. Do NOT touch the v2 folder from this project.

---

## Where things are

```
~/Documents/forgetmenotev3/
├── AGENTS.md                 ← this file
├── README.md                 ← quickstart for humans
└── ios/
    ├── project.yml           ← xcodegen spec (bundle ID, Info.plist, deps)
    ├── Podfile               ← CocoaPods (ML Kit + RevenueCat, ML Kit optional via SKIP_MLKIT env)
    ├── TESTFLIGHT.md         ← App Store Connect / TestFlight upload steps
    ├── ForgetMeNote.xcworkspace  ← OPEN THIS, not .xcodeproj
    ├── ForgetMeNote/
    │   ├── ForgetMeNoteApp.swift  ← @main, mounts V3RootView
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
    │   └── V3/               ← V3 DESIGN OVERHAUL — all new code lives here
    │       ├── Theme/V3Theme.swift        ← forget-me-not / forest / clay palettes + hue picker
    │       ├── Theme/V3Typography.swift   ← Instrument Serif helpers + small-caps modifier
    │       ├── Components/FlowerMark.swift     ← 5-petal SVG flower (SwiftUI Canvas)
    │       ├── Components/V3RoomTile.swift     ← colored card with big serif initial
    │       ├── Screens/V3WelcomeScreen.swift   ← flower scatter + "Remember where things live"
    │       ├── Screens/V3HomeScreen.swift      ← greeting + carousel + room grid
    │       ├── Screens/V3FindScreen.swift      ← search + tags + recent
    │       └── V3RootView.swift                ← TabView (Home/Find/You), welcome gate, V3YouScreen
    │
    ├── ForgetMeNoteTests/
    ├── qa/maestro/flows/
    │   ├── v3_full_qa.yaml    ← v3 end-to-end Maestro flow (passes 100%)
    │   └── (older v2 flows kept for reference)
    └── scripts/generate_app_icon.py  ← Python/PIL fallback icon generator
```

### Key principle

**v2 code is preserved and reused.** The legacy `Views/Screens/SettingsScreen`,
`ImageDetailScreen`, etc. are still mounted by v3 navigation when the user
drills into details. The `V3/` folder only redesigns the top-level screens
(Welcome, Home, Find, You). Future v3 work that touches detail/edit screens
should either modify the v2 screens carefully (keep them compatible with v2
look-and-feel concerns) or write fresh `V3DetailScreen` etc. and update
`V3RootView.destination(for:)` to route to them.

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
- ✅ Walkthrough restart via You → Show walkthrough re-shows the v3 welcome screen
- ✅ ML detection (device-only) uses Apple Vision for specific labels — same code as v2
- ✅ App-icon badge for updated-items count
- ✅ Mark-as-Updated toggle uses the `@State` mirror pattern (no snap-back)
- ✅ Maestro QA flow `qa/maestro/flows/v3_full_qa.yaml` passes 23/23 steps on iOS Simulator
- ✅ Privacy manifest declared, AppIcon registered, BGTaskScheduler ID matches Info.plist

### Deferred / known gaps

| Area | Status | What to do when picking it up |
|------|--------|------|
| `V3HomeScreen` "New room" button | TODO no-op | Wire a sheet with name input + room hue picker → call `ImageRepository.createRoom(name:)` |
| Capture (+) button | Not present in tab bar yet | The JS prototype shows a center "+" floating button overlapping the tab bar. Port `CaptureSheet` from `screens-secondary.jsx`, present via `.sheet` on V3RootView. |
| `V3RoomTile` tap → opens v2 detail | Acceptable interim | When user taps a room, currently uses `Route.imageDetail(imageId:)` → v2 `ImageDetailScreen`. Eventually port `V3RoomScreen` from `screens-space.jsx` (grid view of children) and `V3SpaceScreen` (single-image detail). |
| Instrument Serif font | Falls back to system serif | Drop the OTF files into `ForgetMeNote/Fonts/`, register `UIAppFonts` array in Info.plist (`InstrumentSerif-Regular.otf`, `InstrumentSerif-Italic.otf`). Then `V3Font.headline()` actually uses them. |
| Drag-to-reorder | Inherited broken state from v2 | v2 uses `.onMove` on root-level rows only (flat-list refactor); not surfaced in v3 UI yet. |
| `V3YouScreen` stat values | Counts are correct but the layout is plain | Could match the JSX `screens-secondary.jsx` more precisely (illustrated cards). |
| Cross-platform import from Android | Not wired | iOS export → iOS import works (JSON manifest). Android's `forgetmenote.db` (Room SQLite) format is incompatible without a bridge. |
| RevenueCat real IAP | Stub-only | `StubPaywallView` is the prototype shell. Real flow requires RevenueCat account + App Store Connect product registration. |

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

## Conventions any future Codex session must follow

### Code style
- Swift 5.10, iOS 17.0+ deployment target.
- Prefer `@Observable` (Swift 5.9+) over `ObservableObject`.
- All SwiftData mutations on `ModelContext.mainContext` from the main actor; long-running work in a `@ModelActor` (see `ImageRepository`).
- For UI toggles bound to `@Model` properties, use the **@State mirror pattern** (see `UpdatedToggleRow` in `ImageDetailScreen.swift`). Do NOT bind a Toggle directly to a SwiftData property — there's a regression history of snap-back.
- All identifiers added for Maestro must use `.accessibilityIdentifier("…")`. Prefix v3-specific IDs with `v3-` (e.g. `v3-search-input`, `v3-welcome-start`).
- ML services must guard with `#if !targetEnvironment(simulator)` for ML Kit code paths. Apple Vision works fine in the Simulator.

### Project structure rules
- New v3 screens go under `V3/Screens/`. New v3 components under `V3/Components/`. Theme tokens under `V3/Theme/`.
- Do NOT modify legacy `Views/` files unless absolutely necessary — v2 still builds from this codebase. If you must, keep the changes additive.
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
- AGENTS.md + README handoff docs

### Phase 10 — next likely work
- Port `V3RoomScreen` from `screens-space.jsx` RoomScreen
- Port `V3SpaceScreen` (single-photo detail with rect overlays)
- Port `CreateSubScreen` (camera-first → name → tags) to replace legacy `CreateChildScreen` in the v3 flow
- Wire the capture (+) FAB in the tab bar
- Bundle Instrument Serif font files

### Phase 11 — polish + paywall
- Real `V3SettingsScreen` (not the v2 legacy)
- Real RevenueCat IAP after the user creates the App Store Connect product
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
