# Design — v3 round 3: crop fix, guided walkthrough, CoreML detector, tap-to-identify

**Date:** 2026-05-29 (round 3) · **Target:** v3 only · **Status:** approved, proceeding to plan.

## Items (user-approved decisions)
1. **Crop smoothness + corner handles** — bug fix. Root cause: `.drawingGroup()` on the interactive crop layer in `V3CreateSubScreen.photoArea` rasterizes the subtree → kills handle hit-testing + forces per-frame re-render (lag). Plus the enclosing `ScrollView` can steal the drag.
2. **Guided walkthrough** — replace the current "Show walkthrough" (which just re-shows the welcome splash and feels like nothing) with a real multi-step coach overlay.
3. **On-device CoreML detector** — user chose "add on-device CoreML detector" (no cloud). Bundle Apple's `YOLOv3Tiny.mlmodel` (verified reachable, 35.5 MB, outputs `VNRecognizedObjectObservation` directly; runs on device AND Simulator).
4. **Tap-to-identify** — tap a point on a photo → translucent ML label at that point.

## Constraints
v3 only. No edits to `V4/*`, `Views/*`, `ML/*` (call public APIs). Fully on-device, no cloud/keys. New `.mlmodel` lives under `ForgetMeNote/V3/Vision/`; xcodegen includes it (CoreML auto-compiles + generates the `YOLOv3Tiny` Swift class).

## 1. Crop fix
- Remove `.drawingGroup()` from `V3CreateSubScreen.photoArea`.
- In `V3CropBox`, use `.highPriorityGesture(...)` for the move + the 4 resize gestures so the parent `ScrollView` can't intercept drags.

## 2. Guided walkthrough
- New `V3/Components/V3Walkthrough.swift`: a dimmed full-screen overlay with a caption card, progress dots, **Next**/**Back**/**Skip**, stepping through: places grid → capture (+) button → "Find objects" detection → tap-to-identify. Pragmatic card-style steps (short title + body + a hint of where to look) rather than pixel-anchored coach marks (robust, no fragile geometry).
- `V3RootView`: add `@State showTour`. **You → Show walkthrough** sets `showTour = true` (separate from the first-launch `showWelcome` splash). Overlay renders above the TabView, dismiss returns the user exactly where they were. Fixes the "does nothing / goes home" behavior.

## 3. CoreML detector (engine upgrade)
- Add `ForgetMeNote/V3/Vision/YOLOv3Tiny.mlmodel` (downloaded during impl from Apple's ML assets; if unreachable, user supplies one).
- New `V3/Vision/V3CoreMLDetector.swift`: `VNCoreMLRequest` over the model → `[VNRecognizedObjectObservation]` → `(rect, label, confidence)` with bounding boxes **flipped from Vision bottom-left to our top-left** normalized coords. Lazy-loaded `VNCoreMLModel`. Works on Simulator (CoreML CPU).
- `V3VisionService.detect` becomes: CoreML detector boxes (primary — more + accurate COCO objects) **∪** Apple Vision instance masks (for the glowing outlines), matched by IoU so detected objects get a mask silhouette when available; mask-only instances with no CoreML box are still kept (catches non-COCO things). Each label refined by the existing Vision classifier fusion (COCO label + `VNClassifyImageRequest`). NMS to de-dup. Drop the ML Kit dependency from the v3 path (CoreML supersedes the Android-port detector).

## 4. Tap-to-identify
- On `V3SpaceScreen`'s hero photo, a `SpatialTapGesture` captures the tap location → normalized point. If the point falls inside a current detection box → show that label; else crop a small region around the point and classify via `VisionClassificationService.classifyTop`. Show a **translucent label capsule** at the tap point that auto-fades (~2.5 s). Lightweight, reuses the engine.

## Testing
- Per-task Simulator builds. CoreML + Vision now run on Sim (ML Kit no longer required for v3 detection), so detection is finally Sim-exercisable.
- Final device build; user verifies on the **FMN v3** icon: smooth crop + working corners; the guided tour; richer detection; tap-to-identify labels.

## Risks
- Model download size/availability (mitigated: verified URL; fallback = user-supplied model).
- Auto-generated `YOLOv3Tiny` class name depends on the file name — keep the file named `YOLOv3Tiny.mlmodel`.
- Bounding-box coordinate flip (Vision bottom-left → top-left) must be correct or boxes appear vertically mirrored.

## VC note
Not a git repo; docs written, not committed.
