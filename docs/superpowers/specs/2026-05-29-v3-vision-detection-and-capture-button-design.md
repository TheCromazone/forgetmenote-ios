# Design — V3 On-Device Vision Detection + Capture Button Reposition

**Date:** 2026-05-29
**Project:** ForgetMeNote v3 (iOS, SwiftUI/SwiftData)
**Status:** Approved (design) — pending spec review → implementation plan

---

## Goal

Two related improvements to the V3 experience:

1. **Reposition the capture (camera) button** so it sits as a separate
   liquid-glass circle to the *right* of the bottom tab-bar pill, vertically
   centered at the same level (the iOS 26 accessory pattern) — instead of
   floating above the tab bar as it does today.

2. **Surface a "Gemini-like" object-detection feature** that is more precise,
   accurate, and visually impressive than the original Android port's method.
   The user explicitly wants to *drop* the Android ML Kit fixed-category
   bounding-box approach in favor of a cooler one. Decision: **fully
   on-device**, showing **segmentation outlines (masks) + labels**, triggered
   by a **button** on the single-photo view, where tapping a detected object
   **selects** it and the user **confirms** to create a sub-space.

---

## Key context discovered in the codebase

The hardest part already exists but is **not wired into V3**:

- `ObjectDetectionService.detectForegroundInstances(imagePath:)`
  (`ML/ObjectDetectionService.swift:160-212`, `@available(iOS 18.0, *)`) already
  uses Apple Vision's `GenerateForegroundInstanceMaskRequest` to produce
  **per-object instance segmentation masks**, computes each instance's
  bounding box, crops + classifies it, and returns
  `DetectedObjectInfo { boundingBox, label, confidence, alternates, maskPNGData }`.
- `DetectedObjectInfo` (`Models/DetectedObjectInfo.swift`) already carries
  `maskPNGData: Data?` — but nothing renders it.
- The currently-reachable detection path is the v2 ML Kit object detector
  ("the Android guy's method") in the legacy `Views/Screens/ImageDetailScreen`.
  V3 screens (`V3SpaceScreen`, `V3RoomScreen`, `V3CreateSubScreen`) call **no
  detection at all**.

So the work is: build a clean V3-native Vision path, surface it on
`V3SpaceScreen` with a beautiful mask overlay, and reposition the FAB.

### Relevant files
- `ForgetMeNote/V3/V3RootView.swift` — tab bar + FAB overlay (`signedInBody`, lines 73-174); `destination(for:)` routing (214-239).
- `ForgetMeNote/V3/Components/V3CaptureFAB.swift` — the camera button (solid accent circle today).
- `ForgetMeNote/V3/Screens/V3SpaceScreen.swift` — single-photo view; hero photo + sub-space rect overlays (`heroPhoto`, 113-238); nav header with `•••` button (65-86).
- `ForgetMeNote/ML/ObjectDetectionService.swift` — existing detection incl. the iOS-18 mask path.
- `ForgetMeNote/ML/VisionClassificationService.swift` — Apple Vision `VNClassifyImageRequest` labeller (no ML Kit).
- `ForgetMeNote/Models/DetectedObjectInfo.swift`, `Models/Rectangle.swift`, `Models/ImageItem.swift` — data shapes.
- `ForgetMeNote/Views/Route.swift` — `Route.createChild(parentId:suggestedTitle:rectangleOnParent:tempPhotoPath:)` is the existing create-sub-space entry point.

---

## Part 1 — Capture button as a glass pill to the right

### Current state
In `V3RootView.signedInBody`, inside `ZStack(alignment: .bottomTrailing)`:
```swift
V3CaptureFAB(palette: palette) { showCaptureSheet = true }
    .padding(.trailing, 20)
    .padding(.bottom, 90)   // floats ABOVE the tab bar
    .zIndex(5)
```
`V3CaptureFAB` is a 64pt solid `palette.accent` circle with a white
`camera.fill` icon and a 4pt `palette.surface` ring.

### Target
- The button sits to the **right of** the tab-bar pill, vertically centered at
  the **same level** as the tab bar (matches the user-approved mockup).
- Reduce `.padding(.bottom, …)` so the button's vertical center aligns with the
  tab bar's center. The native iOS 26 tab bar floats just above the bottom safe
  area; empirically this is roughly `safeArea.bottom + ~14pt`. Exact value tuned
  on-device.
- Restyle `V3CaptureFAB` to read as a **sibling of the glass tab bar**:
  - Liquid-glass background: `.glassEffect(...)` where available (iOS 26),
    falling back to `.regularMaterial` for the deployment floor (iOS 17).
  - Accent-tinted `camera.fill` icon instead of white-on-accent.
  - Size ≈ 56pt to better match the tab bar's height (down from 64pt).
  - Keep `accessibilityIdentifier("v3-capture-fab")` and the accessibility label.

### Notes / risks
- The native `TabView` glass pill is horizontally centered; overlaying the FAB
  at `.bottomTrailing` places it in the right margin at the bar's height, which
  is exactly the desired look.
- `.glassEffect` is iOS 26 only — must be wrapped in `if #available(iOS 26, *)`
  with a `.regularMaterial` fallback so the iOS-17 deployment target still
  compiles.
- Behavior is unchanged: tapping still sets `showCaptureSheet = true`.

---

## Part 2 — On-device V3 vision detection

### Approach (chosen: A — Apple Vision Segmentation, V3-native)
A clean V3 path using **only Apple Vision** (instance masks + classification).
No ML Kit in the V3 detection path. This:
- Drops the Android ML Kit fixed-category method, as requested.
- Shows segmentation masks + labels (the "cooler" result).
- Runs in the **iOS Simulator** (pure Vision, no device-only ML Kit binary), so
  Maestro QA can finally cover detection without the `SKIP_MLKIT` build dance.
- Leaves v2 / ML Kit pods untouched — the legacy `ImageDetailScreen` keeps working.

### New: `V3VisionService`
- Location: `ForgetMeNote/V3/` (e.g. `V3/Vision/V3VisionService.swift`) or `ML/`.
- API: `static func detect(imagePath: String) async -> [DetectedObjectInfo]`.
- Implementation: the iOS-18 `GenerateForegroundInstanceMaskRequest` instance-mask
  pipeline (mirroring the existing `detectForegroundInstances`), with labels from
  `VisionClassificationService.classifyTop` only (no `ImageLabelingService`/ML Kit).
  Reuse the existing helpers (`alphaMaskAndBounds`, `cropToNormalizedRect`,
  `mergeOverlaps`, `cgOrientation`) — extract/share them rather than duplicate
  where practical.
- Availability: `if #available(iOS 18, *)` → run; otherwise return `[]` (the UI
  shows a graceful "not supported on this iOS" state). The user's demo iPhone is
  iOS 26.5, so the real path is always exercised there.
- **Verification risk:** confirm `GenerateForegroundInstanceMaskRequest` actually
  produces instances on the iOS-18 *Simulator*; if it returns empty there, keep
  the on-device path authoritative and treat Sim as best-effort for the overlay
  (Maestro asserts the button + scanning state rather than specific masks).

### `V3SpaceScreen` changes
- Add a **"Find objects"** control. Placement: a pill button directly under the
  hero photo (preferred — more discoverable than burying it in the `•••`),
  styled to match V3. Accessibility id `v3-space-detect`.
- New `@State`: `detections: [DetectedObjectInfo]`, `isDetecting: Bool`,
  `selectedDetectionId` (use `DetectedObjectInfo.id`).
- Tapping "Find objects":
  1. Set `isDetecting = true`, show a scanning shimmer over the hero photo.
  2. `await V3VisionService.detect(imagePath: item.filePath)`.
  3. Store results, animate the overlay in, `isDetecting = false`.
  4. If empty, show a gentle "No objects found — draw one yourself" message.

### New: `V3DetectionOverlay` component
- Location: `ForgetMeNote/V3/Components/V3DetectionOverlay.swift`.
- Input: the detections, the displayed image rect (from the hero `GeometryReader`),
  the selected id, and an `onSelect` callback.
- Renders, per detection:
  - The **mask** (`maskPNGData` → `UIImage`) drawn as a glowing accent **outline**
    over the photo (tint the mask to `palette.accent`, add a soft glow/shadow;
    optionally an animated reveal). This is the signature "cool" visual.
  - A floating **label capsule** (the object's label) anchored to the mask's
    bounding box.
  - Coexists with the existing sub-space rectangle overlays in `heroPhoto`
    (detections are a transient layer above them).
- Tapping a mask calls `onSelect(detection.id)` → highlight it (brighter glow,
  others dim).

### Selection → confirm → create (chosen: "just select, user confirms")
- When a detection is selected, show a **"Add as sub-space ✦"** confirm button
  (e.g. a bottom bar/capsule on the photo) plus the chosen label.
- Confirming routes via the **existing** create flow:
  ```swift
  path.append(Route.createChild(
      parentId: spaceId,
      suggestedTitle: detection.label,          // editable name prefilled
      rectangleOnParent: detection.boundingBox, // box prefilled
      tempPhotoPath: nil
  ))
  ```
  (No new persistence model — the sub-space is created exactly as a manually
  drawn one would be. Mask data is display-only and not stored.)
- After creation, detections can be cleared so the screen returns to its normal
  sub-space view.

### Data flow (end to end)
`V3SpaceScreen` → tap **Find objects** → `V3VisionService.detect` →
`[DetectedObjectInfo]` in `@State` → `V3DetectionOverlay` draws masks + labels →
user taps a mask (select) → taps **Add as sub-space** (confirm) →
`Route.createChild(..., suggestedTitle: label, rectangleOnParent: box)` →
existing `CreateChildScreen`/create logic saves the child → screen refreshes.

---

## Testing

### Maestro (Simulator)
- New flow (or extend `v3_full_qa.yaml`): open a space with a photo → tap
  `v3-space-detect` → assert scanning/overlay state appears → (if masks present)
  tap a detection → assert the confirm button → confirm → assert a new sub-space
  row appears in "What's inside".
- All new interactive elements get `v3-`-prefixed accessibility identifiers.
- Honor known Maestro/iOS-26 quirks: prefer accessibility IDs over text taps;
  avoid relying on `Text + Text` concatenations for assertions.

### On-device (iPhone, iOS 26.5)
- Verify real segmentation-mask quality, overlay glow, label accuracy.
- Verify the FAB glass pill alignment beside the tab bar (the bottom-padding
  value), since simulator-only checks have missed device-specific issues before.

---

## Scope guards (YAGNI — explicitly out of scope)

- No cloud / Gemini API, no API keys, no networking, no privacy-manifest change
  (fully on-device).
- No changes to v2 legacy screens or the ML Kit pods (v2 keeps working).
- Raw detections are **not** persisted; only the confirmed sub-space (box + name)
  is saved, via the existing model.
- No mask *editing* / freeform segmentation authoring — masks are for display and
  bounding-box extraction only.
- No new settings toggles.
- `V3RoomScreen` (room = no photo) is unaffected; detection only applies to
  photo-backed spaces in `V3SpaceScreen`.

---

## Open verification items (resolve during implementation)

1. Exact `.padding(.bottom, …)` for vertical alignment of the FAB with the tab
   bar — tune on-device.
2. Whether `GenerateForegroundInstanceMaskRequest` yields instances on the iOS-18
   Simulator (affects how strict the Maestro assertions can be).
3. `.glassEffect` availability gating vs the iOS-17 deployment floor — confirm the
   `if #available(iOS 26, *)` fallback compiles cleanly.

---

## Note on version control

This project is **not** a git repository (per session environment). The design
doc is written to disk but cannot be committed; skip the git-commit step.
