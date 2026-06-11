# v3 Round 3 — Crop Fix, Guided Walkthrough, CoreML Detector, Tap-to-Identify

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`.

**Goal:** Fix the crop drag/handles, add a real guided walkthrough, bundle an on-device CoreML object detector for much better detection, and add tap-to-identify translucent labels — all v3-only, fully on-device.

**Architecture:** Remove the rasterizing `.drawingGroup()` and raise crop gestures to high priority. New `V3Walkthrough` overlay driven by `V3RootView`. Bundle Apple `YOLOv3Tiny.mlmodel`; new `V3CoreMLDetector` wraps it with `VNCoreMLRequest`; `V3VisionService` merges CoreML boxes + Vision instance masks + classifier-fused labels. Tap-to-identify adds a `SpatialTapGesture` on the hero photo.

**Tech Stack:** Swift 5.10, SwiftUI, Vision, CoreML, SwiftData. xcodegen + CocoaPods.

---

## Environment notes
- **NOT a git repo.** No commits; each task ends at a build-verify checkpoint.
- Build convention: `xcodegen generate` THEN `SKIP_MLKIT=1 pod install` (pod install MUST follow xcodegen). Sim build command:
  ```bash
  cd ~/Documents/forgetmenotev3/ios && xcodegen generate && \
    SKIP_MLKIT=1 LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install >/dev/null 2>&1; \
  JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
    xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote \
      -configuration Debug -destination "generic/platform=iOS Simulator" \
      -allowProvisioningUpdates ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build 2>&1 | tail -8
  ```
- Do NOT edit `V4/*`, `Views/*`, `ML/*`. Only `V3/*` (+ new files).
- Existing v3 facts: `Rectangle{Float x,y,width,height}` (top-left origin, y-down); `DetectedObjectInfo{id:UUID,boundingBox:Rectangle,label:String,confidence:Float,alternates:[String],maskPNGData:Data?}`; `V3DetectionGeometry.iou/displayRect`; `VisionClassificationService.classifyTop(_:maxResults:minConfidence:)`, `.prettifyIdentifier`, `.isGenericIdentifier` (public); palette tokens `accent/accentSoft/accentBg/surface/ink/ink2/ink3/line/paper/paperEdge/pollen/danger`; `V3DetectionOverlay(palette:detections:size:selectedId:onSelect:)`.

---

## Task 1: Crop fix (smooth drag + working corners)

**Files:** Modify `ForgetMeNote/V3/Components/V3CropBox.swift`, `ForgetMeNote/V3/Screens/V3CreateSubScreen.swift`.

- [ ] **Step 1: Remove the rasterizing drawingGroup.** In `V3CreateSubScreen.swift` `photoArea`, delete the `.drawingGroup()` line (it sits between `.clipShape(...)` and `.shadow(...)` on the photo ZStack). Leave `.clipShape` and `.shadow`.

- [ ] **Step 2: Raise crop gestures to high priority.** In `V3CropBox.swift`, change the gesture attachments from `.gesture(...)` to `.highPriorityGesture(...)` so the enclosing `ScrollView` cannot steal the drag:
  - On the rect body: `.gesture(moveGesture(w: w, h: h))` → `.highPriorityGesture(moveGesture(w: w, h: h))`.
  - On each handle: `.gesture(resizeGesture(isLeft: isLeft, isTop: isTop, w: w, h: h))` → `.highPriorityGesture(resizeGesture(isLeft: isLeft, isTop: isTop, w: w, h: h))`.

- [ ] **Step 3: Build for Simulator.** Expected `** BUILD SUCCEEDED **`.

---

## Task 2: Guided walkthrough

**Files:** Create `ForgetMeNote/V3/Components/V3Walkthrough.swift`; modify `ForgetMeNote/V3/V3RootView.swift` and `ForgetMeNote/V3/Screens/V3YouScreen` (in `V3RootView.swift`).

- [ ] **Step 1: Create the walkthrough overlay.** Create `ForgetMeNote/V3/Components/V3Walkthrough.swift`:
```swift
import SwiftUI

/// Multi-step guided tour shown over the app. Dimmed backdrop + a caption card
/// with progress dots and Back/Next/Skip. v3-only.
struct V3Walkthrough: View {
    let palette: V3Palette
    var onFinish: () -> Void

    @State private var step = 0

    private struct Page { let icon: String; let title: String; let body: String }
    private let pages: [Page] = [
        Page(icon: "square.grid.2x2.fill", title: "Your places",
             body: "Every room, shelf and drawer lives on the Home tab. Tap one to look inside."),
        Page(icon: "camera.fill", title: "Snap to remember",
             body: "Tap the camera button by the tab bar to photograph a space and add it."),
        Page(icon: "sparkles", title: "Find objects",
             body: "Open a photo and tap “Find objects” — the app outlines what it sees and lets you turn anything into a sub-spot."),
        Page(icon: "hand.tap.fill", title: "Tap to identify",
             body: "Not sure what something is? Tap it in a photo and a label pops up right there."),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { } // swallow taps to the app behind

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: pages[step].icon)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 72, height: 72)
                        .background(palette.accentBg, in: Circle())

                    Text(pages[step].title)
                        .font(V3Font.headline(26))
                        .foregroundStyle(palette.ink)
                        .multilineTextAlignment(.center)
                    Text(pages[step].body)
                        .font(.system(size: 15))
                        .foregroundStyle(palette.ink2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        ForEach(pages.indices, id: \.self) { i in
                            Circle()
                                .fill(i == step ? palette.accent : palette.line)
                                .frame(width: 7, height: 7)
                        }
                    }
                    .padding(.top, 2)

                    HStack(spacing: 12) {
                        if step > 0 {
                            Button("Back") { withAnimation { step -= 1 } }
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(palette.ink2)
                                .accessibilityIdentifier("v3-tour-back")
                        }
                        Spacer()
                        Button(step == pages.count - 1 ? "Done" : "Next") {
                            if step == pages.count - 1 { onFinish() }
                            else { withAnimation { step += 1 } }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22).frame(height: 44)
                        .background(palette.accent, in: Capsule())
                        .accessibilityIdentifier("v3-tour-next")
                    }
                    .padding(.top, 4)
                }
                .padding(22)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)

                Button("Skip") { onFinish() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 16)
                    .accessibilityIdentifier("v3-tour-skip")
                Spacer()
            }
        }
        .accessibilityIdentifier("v3-walkthrough")
    }
}
```

- [ ] **Step 2: Wire it into `V3RootView`.** Read `V3RootView.swift`. Add state near the capture-flow state: `@State private var showTour: Bool = false`. In `signedInBody`'s outer `ZStack`, ADD (after the `showWelcome` overlay block) :
```swift
            if showTour {
                V3Walkthrough(palette: palette) {
                    withAnimation(.easeOut(duration: 0.25)) { showTour = false }
                }
                .transition(.opacity)
                .zIndex(20)
            }
```
Then change the `V3YouScreen(... onShowWelcome:)` call so "Show walkthrough" opens the tour instead of the splash: replace the `onShowWelcome` closure body with:
```swift
                                onShowWelcome: {
                                    withAnimation(.easeIn(duration: 0.25)) { showTour = true }
                                }
```
(Leave the `V3YouScreen` parameter name `onShowWelcome` as-is to avoid touching its signature; only its closure changes. The first-launch `showWelcome` splash logic stays unchanged.)

- [ ] **Step 3: Build for Simulator.** Expected `** BUILD SUCCEEDED **`.

---

## Task 3: Bundle YOLOv3Tiny + `V3CoreMLDetector`

**Files:** Add `ForgetMeNote/V3/Vision/YOLOv3Tiny.mlmodel`; create `ForgetMeNote/V3/Vision/V3CoreMLDetector.swift`.

- [ ] **Step 1: Download the model into the source tree.**
```bash
cd ~/Documents/forgetmenotev3/ios && \
  curl -L --fail --max-time 300 -o ForgetMeNote/V3/Vision/YOLOv3Tiny.mlmodel \
  "https://ml-assets.apple.com/coreml/models/Image/ObjectDetection/YOLOv3Tiny/YOLOv3Tiny.mlmodel" && \
  ls -lh ForgetMeNote/V3/Vision/YOLOv3Tiny.mlmodel
```
Expected: a ~35 MB file. If the download fails (non-200 / size 0), STOP and report BLOCKED — the user will supply a `.mlmodel`. Do not invent a model.

- [ ] **Step 2: Create the detector.** Create `ForgetMeNote/V3/Vision/V3CoreMLDetector.swift`:
```swift
import Vision
import CoreML
import UIKit

/// On-device object detector backed by the bundled YOLOv3Tiny CoreML model
/// (80 COCO classes). Outputs labeled boxes in TOP-LEFT normalized coords.
/// Runs on device AND Simulator (CoreML CPU). v3-only.
enum V3CoreMLDetector {

    struct Box { let rect: Rectangle; let label: String; let confidence: Float }

    /// Lazily-built Vision model wrapper. `YOLOv3Tiny` is the class CoreML
    /// auto-generates from `YOLOv3Tiny.mlmodel` at build time.
    private static let visionModel: VNCoreMLModel? = {
        do {
            let cfg = MLModelConfiguration()
            let model = try YOLOv3Tiny(configuration: cfg)
            return try VNCoreMLModel(for: model.model)
        } catch {
            print("V3CoreMLDetector: model load failed: \(error)")
            return nil
        }
    }()

    static func detect(_ image: UIImage, minConfidence: Float = 0.25) async -> [Box] {
        guard let visionModel, let cg = image.cgImage else { return [] }
        return await withCheckedContinuation { cont in
            let request = VNCoreMLRequest(model: visionModel) { req, _ in
                let observations = (req.results as? [VNRecognizedObjectObservation]) ?? []
                let boxes: [Box] = observations.compactMap { obs in
                    guard let top = obs.labels.first, top.confidence >= minConfidence else { return nil }
                    let bb = obs.boundingBox // normalized, ORIGIN BOTTOM-LEFT
                    let rect = Rectangle(
                        x: Float(bb.minX),
                        y: Float(1 - bb.maxY),       // flip to top-left origin
                        width: Float(bb.width),
                        height: Float(bb.height)
                    )
                    return Box(rect: rect, label: top.identifier, confidence: top.confidence)
                }
                cont.resume(returning: boxes)
            }
            request.imageCropAndScaleOption = .scaleFill
            let handler = VNImageRequestHandler(cgImage: cg, orientation: cgOrientation(image), options: [:])
            do { try handler.perform([request]) } catch {
                print("V3CoreMLDetector: perform failed: \(error)")
                cont.resume(returning: [])
            }
        }
    }

    private static func cgOrientation(_ image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up; case .down: return .down
        case .left: return .left; case .right: return .right
        case .upMirrored: return .upMirrored; case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored; case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
```

- [ ] **Step 3: Build for Simulator.** Run `xcodegen generate` (so the .mlmodel is added to the target and CoreML generates the `YOLOv3Tiny` class), then the Sim build. Expected `** BUILD SUCCEEDED **`. If the build can't find type `YOLOv3Tiny`, confirm the model file is under a path included by `project.yml` sources (`ForgetMeNote/`) and that `xcodegen generate` picked it up; report the exact error otherwise.

---

## Task 4: Merge CoreML into `V3VisionService`

**Files:** Modify `ForgetMeNote/V3/Vision/V3VisionService.swift`.

- [ ] **Step 1: Read the current file.** It has `detect(imagePath:)`, `@available(iOS 18.0,*) detectInstances(...)` (mask pass producing `[DetectedObjectInfo]` with `maskPNGData`), `fusedLabels(for:)`, `mergeOverlaps`, `cropToNormalizedRect`, `alphaMaskAndBounds`, `image(from:)`, `cgOrientation`, and a current ML Kit merge block.

- [ ] **Step 2: Replace the `detect`/`detectInstances` flow** so the primary path is CoreML, masks attach by IoU, and ML Kit is dropped from v3. Replace the public entry and instance logic with:
```swift
    /// Detect objects on the photo. Primary: bundled CoreML detector (works on
    /// device + Simulator). Outlines: Apple Vision instance masks (iOS 18+),
    /// matched to detector boxes by IoU. Labels refined by the Vision classifier.
    static func detect(imagePath: String) async -> [DetectedObjectInfo] {
        guard let original = UIImage(contentsOfFile: imagePath) else { return [] }

        // 1) CoreML detector boxes (COCO).
        let coreml = await V3CoreMLDetector.detect(original)

        // 2) Instance masks for outlines (iOS 18+ only).
        var masks: [(box: Rectangle, png: Data)] = []
        if #available(iOS 18.0, *) {
            masks = await foregroundMasks(original)
        }

        var out: [DetectedObjectInfo] = []

        // 3) Each CoreML detection → refine label + attach an overlapping mask.
        for det in coreml {
            let crop = cropToNormalizedRect(original, rect: det.rect) ?? original
            var labels = await fusedLabels(for: crop)
            // Seed with the COCO label so it competes.
            let coco = VisionClassificationService.prettifyIdentifier(det.label)
            labels = mergeLabel(coco, det.confidence, into: labels)
            let best = labels.first
            let mask = bestMask(for: det.rect, in: masks)
            out.append(DetectedObjectInfo(
                boundingBox: det.rect,
                label: best?.text ?? coco,
                confidence: best?.confidence ?? det.confidence,
                alternates: Array(labels.dropFirst().map(\.text)),
                maskPNGData: mask))
        }

        // 4) Mask-only instances the detector missed (catches non-COCO things).
        for m in masks {
            let covered = out.contains { V3DetectionGeometry.iou($0.boundingBox, m.box) > 0.4 }
            if covered { continue }
            guard m.box.width * m.box.height > 0.0015 else { continue }
            let crop = cropToNormalizedRect(original, rect: m.box) ?? original
            let labels = await fusedLabels(for: crop)
            guard let top = labels.first else { continue }
            out.append(DetectedObjectInfo(
                boundingBox: m.box, label: top.text, confidence: top.confidence,
                alternates: Array(labels.dropFirst().map(\.text)), maskPNGData: m.png))
        }

        return mergeOverlaps(out)
    }

    /// Lightweight single-region classify used by tap-to-identify.
    static func classifyRegion(imagePath: String, around point: CGPoint, size: Float = 0.18) async -> String? {
        guard let original = UIImage(contentsOfFile: imagePath) else { return nil }
        let half = size / 2
        let r = Rectangle(
            x: max(0, Float(point.x) - half), y: max(0, Float(point.y) - half),
            width: size, height: size)
        let crop = cropToNormalizedRect(original, rect: r) ?? original
        return await fusedLabels(for: crop).first?.text
    }

    @available(iOS 18.0, *)
    private static func foregroundMasks(_ original: UIImage) async -> [(box: Rectangle, png: Data)] {
        guard let cg = original.cgImage else { return [] }
        let handler = Vision.ImageRequestHandler(cg, orientation: cgOrientation(original))
        let request = Vision.GenerateForegroundInstanceMaskRequest()
        guard let obs = try? await handler.perform(request) else { return [] }
        var result: [(Rectangle, Data)] = []
        for instance in obs.allInstances {
            let set = IndexSet(integer: instance)
            guard let buffer = try? obs.generateScaledMask(for: set, scaledToImageFrom: handler),
                  let m = alphaMaskAndBounds(from: buffer) else { continue }
            result.append((m.boundingBox, m.pngData))
        }
        return result.map { (box: $0.0, png: $0.1) }
    }

    private static func bestMask(for rect: Rectangle, in masks: [(box: Rectangle, png: Data)]) -> Data? {
        masks.max(by: { V3DetectionGeometry.iou($0.box, rect) < V3DetectionGeometry.iou($1.box, rect) })
            .flatMap { V3DetectionGeometry.iou($0.box, rect) > 0.3 ? $0.png : nil }
    }

    private static func mergeLabel(_ text: String, _ confidence: Float,
                                   into labels: [(text: String, confidence: Float)]) -> [(text: String, confidence: Float)] {
        guard text.count >= 2 else { return labels }
        var dict: [String: Float] = [:]
        for l in labels { dict[l.text] = max(dict[l.text] ?? 0, l.confidence) }
        dict[text] = max(dict[text] ?? 0, min(0.99, confidence + 0.05))
        return dict.map { (text: $0.key, confidence: $0.value) }.sorted { $0.confidence > $1.confidence }
    }
```
Then DELETE the now-unused old `detectInstances(...)` method and the ML Kit merge block (the new `detect` replaces them). Keep `fusedLabels`, `mergeOverlaps`, `cropToNormalizedRect`, `alphaMaskAndBounds`, `image(from:)`, `cgOrientation`. If `fusedLabels` still calls `ImageLabelingService` that's fine to keep (device-only, no-op on Sim) OR simplify to Vision-only — either compiles; do whichever is least churn. Keep imports valid (`Vision`, `CoreImage`, `UIKit`, `Foundation`).

- [ ] **Step 3: Build for Simulator.** Expected `** BUILD SUCCEEDED **`.

---

## Task 5: Tap-to-identify on `V3SpaceScreen`

**Files:** Modify `ForgetMeNote/V3/Screens/V3SpaceScreen.swift`.

- [ ] **Step 1: Add state** near the other detection state:
```swift
    @State private var identifyLabel: String? = nil
    @State private var identifyPoint: CGPoint = .zero      // normalized 0..1
    @State private var identifyToken: Int = 0
```

- [ ] **Step 2: Add the tap gesture + translucent label** inside the hero photo's `GeometryReader` ZStack (where the detections overlay lives). Add, as the LAST overlay layer in that ZStack:
```swift
                // Tap-to-identify translucent label.
                if let label = identifyLabel {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(palette.accent.opacity(0.82), in: Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                        .position(x: identifyPoint.x * geo.size.width,
                                  y: max(18, identifyPoint.y * geo.size.height))
                        .transition(.opacity.combined(with: .scale))
                        .allowsHitTesting(false)
                }
```
And attach a spatial-tap gesture to the hero photo ZStack (add `.gesture(...)` on the same ZStack that has the image; place it so it doesn't block the detection-overlay taps — use a simultaneous low-priority gesture):
```swift
            .simultaneousGesture(
                SpatialTapGesture().onEnded { value in
                    let p = CGPoint(x: value.location.x / geo.size.width,
                                    y: value.location.y / geo.size.height)
                    identifyAt(point: p)
                }
            )
```
> Note: `geo` is the hero `GeometryReader` proxy. If the detection overlay already consumes taps for selection, that's fine — tap-to-identify is a simultaneous gesture and still fires for taps on empty photo areas.

- [ ] **Step 3: Add the identify action** in the Actions section:
```swift
    private func identifyAt(point: CGPoint) {
        // Prefer an existing detection box under the tap.
        if let hit = detections.first(where: {
            let b = $0.boundingBox
            return point.x >= CGFloat(b.x) && point.x <= CGFloat(b.x + b.width)
                && point.y >= CGFloat(b.y) && point.y <= CGFloat(b.y + b.height)
        }) {
            showIdentify(hit.label, at: point); return
        }
        guard let path = item?.filePath else { return }
        identifyToken += 1
        let token = identifyToken
        Task {
            let label = await V3VisionService.classifyRegion(imagePath: path, around: point)
            await MainActor.run {
                guard token == identifyToken else { return }
                showIdentify(label ?? "Not sure", at: point)
            }
        }
    }

    private func showIdentify(_ label: String, at point: CGPoint) {
        identifyToken += 1
        let token = identifyToken
        withAnimation(.easeOut(duration: 0.2)) {
            identifyLabel = label
            identifyPoint = point
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                guard token == identifyToken else { return }
                withAnimation(.easeOut(duration: 0.3)) { identifyLabel = nil }
            }
        }
    }
```
> `identifyToken` guards against stale async results / overlapping taps clearing the wrong label.

- [ ] **Step 4: Build for Simulator.** Expected `** BUILD SUCCEEDED **`.

---

## Task 6: Device build + verification

- [ ] **Step 1: Device build (restore ML Kit) + install + launch.**
```bash
cd ~/Documents/forgetmenotev3/ios && xcodegen generate && \
  LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install 2>&1 | tail -3
JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote -configuration Debug \
    -destination "id=E7A0CD3B-A97A-5548-A204-E046CA2ACAFD" -allowProvisioningUpdates build 2>&1 | tail -12
APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/ForgetMeNote-*/Build/Products/Debug-iphoneos/ForgetMeNote.app | head -1)
xcrun devicectl device install app --device E7A0CD3B-A97A-5548-A204-E046CA2ACAFD "$APP" 2>&1 | tail -3
xcrun devicectl device process launch --device E7A0CD3B-A97A-5548-A204-E046CA2ACAFD com.matthewcromaz.forgetmenote.v3.dev 2>&1 | tail -3
```
Expected `** BUILD SUCCEEDED **` + install/launch. Note the .app is now ~35 MB larger (model). If compile errors, paste them.

- [ ] **Step 2: On-device verification (user — open FMN v3):**
  1. Capture/open a busy photo → "Mark a spot" crop box drags smoothly, all four corners resize, no lag.
  2. You → Show walkthrough → a 4-step guided tour appears and returns you in place.
  3. Find objects → more objects, accurate labels, outlines.
  4. Tap various spots on the photo → a translucent label appears at the tap and fades.

---

## Self-review
- Crop fix → Task 1 (remove drawingGroup + highPriorityGesture). ✓
- Guided walkthrough → Task 2 (`V3Walkthrough` + `showTour` trigger). ✓
- CoreML detector → Task 3 (bundle model + `V3CoreMLDetector`, box y-flip) + Task 4 (merge into `V3VisionService`, masks-by-IoU, label fusion, drop ML Kit primary). ✓
- Tap-to-identify → Task 5 (`SpatialTapGesture`, `classifyRegion`, translucent capsule, token guard). ✓
- v3-only / on-device → new files under `V3/`, no `V4/`/`Views/`/`ML/` edits; CoreML+Vision (no cloud). ✓
- Placeholders: full code provided; the only conditional is the model-download BLOCKED fallback (explicit). ✓
- Types: `V3CoreMLDetector.detect(_:minConfidence:) -> [Box]`, `Box{rect,label,confidence}`; `V3VisionService.detect(imagePath:)` unchanged signature; `classifyRegion(imagePath:around:size:) -> String?` matches Task 5 call; `bestMask`/`mergeLabel`/`foregroundMasks` internal-consistent; `SpatialTapGesture` is iOS16+ (deployment 17 ✓).
