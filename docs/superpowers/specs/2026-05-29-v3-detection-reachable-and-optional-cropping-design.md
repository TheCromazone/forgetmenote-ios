# Design — v3: detection that actually works + better, and opt-in cropping

**Date:** 2026-05-29 (round 2)
**Project:** ForgetMeNote — **v3 target only** (`ForgetMeNote` target / bundle `…v3.dev` / `V3RootView`)
**Status:** Design approved by user ("looks good… continue"); proceeding to plan.

---

## Background / why this round

The previous round added a "Find objects" detection feature to `V3SpaceScreen`
and a glass capture FAB. The user reported the detection "doesn't seem to be
there or work," cropping is "laggy and bad," and asked for the detection/AI to
be "more like the Codex v4 version."

Investigation findings (verified):
- The repo builds **three side-by-side apps**: v2, **v3** (`V3RootView`, bundle
  `…v3.dev`), and **v4** (`V4RootView`, bundle `…v4.dev`, gated by `-D FMN_V4`
  on the `ForgetMeNoteV4` target only — `project.yml:119`). The user was almost
  certainly testing the **v4** app, which never got the detection feature.
- There is **no external "Codex v4" app** anywhere on the machine. The in-repo
  `ForgetMeNote/V4/` *is* the Codex version, and it contains **no detection/AI
  code** — v3 and v4 share the same on-device engine in `ML/`.
- **User decisions:** work on **v3 only**; do **not** modify v4 or any shared
  legacy code; use v4 only as inspiration. Detection goals (all four): actually
  show up & work, more accurate/specific labels, precise outlines, detect
  more/smaller objects. Cropping must be **optional behind a button**, with
  **working four-corner drag handles**, and not laggy.

## Hard constraint: do not touch v4 or shared code

v2 and v4 both route to the shared legacy screens (`ImageDetailScreen`,
`CreateChildScreen`) and the shared `InteractiveRectangleSelector`, and both use
the shared `ML/ObjectDetectionService`. Therefore **all changes are v3-only**:
new components under `V3/`, edits confined to `V3/` screens, and the shared
`ML/*`, `Views/*`, and `V4/*` files are **read-only** (we call their public APIs
but never edit them).

---

## Part 1 — Better on-device detection engine (v3-only)

Enrich `V3/Vision/V3VisionService.swift` (v3-only) so `detect(imagePath:)`
returns more, smaller, better-labelled objects — by composing the **public**
shared services without editing them:

1. **More / smaller objects:** lower the instance-mask min-area filter from
   `0.006` to `0.0015`, and additionally run the ML Kit object detector
   (`ObjectDetectionService.detectObjects(imagePath:)`, public) and **merge** its
   boxes with the mask results (de-dup by IoU), instead of treating ML Kit as a
   fallback-only path. ML Kit is device-only (returns `[]` on Simulator) — fine,
   the user runs on device.
2. **More accurate / specific labels:** for every candidate (mask crop or ML Kit
   box crop), fuse labels from **Apple Vision** (`VisionClassificationService.classifyTop`,
   weight 1.0) and **ML Kit labeling** (`ImageLabelingService.labelsForCroppedImage`,
   weight 0.9), dropping generic labels, keeping top-3 → `label` + `alternates`.
   (This mirrors the shared engine's `labels()` fusion but lives in v3.)
3. **Precise outlines:** mask-derived detections keep `maskPNGData`; the existing
   `V3DetectionOverlay` already renders these as glowing silhouettes. ML-Kit-only
   detections have no mask and render as a box (acceptable).
4. De-dup the merged set with `V3DetectionGeometry.iou` NMS (> 0.6).

No edits to `ML/ObjectDetectionService.swift` etc. — only public calls.

## Part 2 — Make detection reachable in v3

- Detection stays on `V3SpaceScreen` (semantically correct: detect objects in a
  space's photo → create sub-regions). **Verify and guarantee** the path
  Room → `V3RoomScreen` → tap a photo place → `Route.v3Space` → `V3SpaceScreen`
  works, so the "Find objects" button reliably appears for any photo. Fix any
  routing gap found. (Agent indicates `V3RoomScreen` already pushes `Route.v3Space`;
  confirm during implementation and on-device.)

## Part 3 — Opt-in cropping with working corner handles, no lag (v3-only)

Reshape `V3/Screens/V3CreateSubScreen.swift` (v3-only) and extract a reusable
crop component:

1. **New `V3/Components/V3CropBox.swift`:** the crop rectangle + four
   independently-draggable corner handles + move gesture, extracted from
   `V3CreateSubScreen`'s current overlay. Fixes the jank: capture the
   gesture-start rect via `@GestureState`/an `onChanged`-first latch so handles
   don't jump, and enlarge handle hit targets. Binds to a `Rectangle`.
2. **Optional cropping:** in `V3CreateSubScreen`, the crop box is **hidden by
   default**. A button **"Mark the exact spot ✦"** toggles it on (and a way to
   turn it back off). When **off**, save the photo with `rectangleOnParent: nil`
   (the model and repo already accept nil — it's the room-parent case). When
   **on**, save with the box. (Today the rect is mandatory + always written.)
3. **No lag:** downsample the displayed photo via ImageIO
   (`CGImageSourceCreateThumbnailAtIndex`) to ~image-view size before showing it,
   and wrap the photo+overlay in `.drawingGroup()`. Remove any per-frame heavy
   work. Helper: `V3/Vision/V3ImageDownsampler.swift` (or a small UIImage
   extension under `V3/`).
4. **Detection → create flow uses the v3 cropper, prefilled:** extend
   `Route.v3CreateSub` to carry an optional suggested rectangle + title, and have
   `V3SpaceScreen`'s detection-confirm ("Add … ✦") and "Add a spot" route there
   (instead of the legacy `Route.createChild`). When a suggested rect is passed,
   `V3CreateSubScreen` opens with cropping **on** and the box + name prefilled.
   Update the `Route.v3CreateSub` call sites in `V3RootView` accordingly.
   (`Route.v3CreateSub` is only used by v3 — extending it is v3-safe.)

---

## Testing
- Build for Simulator after each change (`SKIP_MLKIT=1`); ML Kit paths no-op on
  Sim but Apple Vision masks + the cropper UI are exercisable.
- Geometry stays unit-tested (`V3DetectionGeometryTests`).
- **Device build at the end** (restore ML Kit) so the user can verify on the
  iPhone: detection appears on a real photo, finds multiple/small objects with
  good labels + outlines; cropping is off by default, the button reveals it, and
  the four corner handles drag smoothly without lag.

## Scope guards
- v3 only. No edits to `V4/*`, `ML/*`, `Views/*` (incl. `InteractiveRectangleSelector`,
  `CreateChildScreen`, `ImageDetailScreen`). Still fully on-device; no cloud, no
  API keys, no new model files.
- Not adding a CoreML object detector this round (possible future "detect even
  more" upgrade) — the ML Kit + Vision fusion is the pragmatic on-device best.

## Note on version control
Project is not a git repo; spec/plan written to disk, not committed.
