# V3 On-Device Vision Detection + Capture Button Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reposition the V3 capture button as a liquid-glass circle beside the tab bar, and add a fully on-device "Find objects" feature on the single-photo screen that draws Apple Vision segmentation masks + labels and turns a tapped object into a sub-space.

**Architecture:** A new `V3VisionService` wraps Apple Vision's iOS-18 `GenerateForegroundInstanceMaskRequest` (instance masks) + `VNClassifyImageRequest` (labels) — no ML Kit, so it runs in the Simulator and retires the Android fixed-category detector for V3. `V3SpaceScreen` gains a button that runs detection into `@State`, a new `V3DetectionOverlay` renders glowing masks + labels over the hero photo, and confirming a selection routes through the existing `Route.createChild` create-sub-space flow (box + label prefilled). The capture FAB is restyled to glass and moved beside the tab-bar pill.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, Apple Vision framework, XCTest (one geometry unit test), Maestro (regression), xcodegen + CocoaPods.

---

## Important environment notes (read before starting)

- **This project is NOT a git repository** (confirmed in session env). There are no `git commit` steps in this plan. Each task ends with a **build/verify checkpoint** instead. Do not run `git` commands.
- **xcodegen auto-discovers sources** under `ForgetMeNote/` and `ForgetMeNoteTests/` (see `project.yml` `sources: - path: ForgetMeNote`). After creating a new `.swift` file you **must run `xcodegen generate`** before building, or Xcode won't see it.
- **Simulator builds must skip ML Kit** because the v2 `ObjectDetectionService` still links ML Kit (device-only binary). Use `SKIP_MLKIT=1` for all Simulator `pod install` + builds. The new V3 path is pure Vision and works in the Simulator regardless.
- **Build commands** are documented in `CLAUDE.md`. The canonical device UDID is `E7A0CD3B-A97A-5548-A204-E046CA2ACAFD`; the user's iPhone runs iOS 26.5.
- **TDD note:** This is a SwiftUI/Maestro codebase with no real unit-test culture (only a stub `ForgetMeNoteTests.swift`). Per the skill's instruction-priority rule, project reality wins: we write **one** fast, genuinely valuable unit test (coordinate-mapping geometry — exactly the kind of logic that silently breaks), and verify everything else via **build + Simulator/Maestro + on-device**, matching how this project has always been QA'd.

---

## File structure

**Create:**
- `ForgetMeNote/V3/Vision/V3DetectionGeometry.swift` — pure coordinate/IoU helpers (unit-tested).
- `ForgetMeNote/V3/Vision/V3VisionService.swift` — Apple Vision instance-mask + classification detection.
- `ForgetMeNote/V3/Components/V3DetectionOverlay.swift` — renders masks + labels + selection over the hero photo.
- `ForgetMeNoteTests/V3DetectionGeometryTests.swift` — unit tests for the geometry helpers.

**Modify:**
- `ForgetMeNote/V3/Components/V3CaptureFAB.swift` — restyle to a glass circle.
- `ForgetMeNote/V3/V3RootView.swift:109-117` — reposition the FAB beside the tab bar.
- `ForgetMeNote/V3/Screens/V3SpaceScreen.swift` — detection state, "Find objects" button, overlay, confirm→create.

**Untouched (regression surface):** v2 `Views/` screens, `ML/ObjectDetectionService.swift`, the ML Kit pods, `Podfile`, `project.yml` info keys.

---

## Task 1: Restyle the capture FAB to a glass circle

**Files:**
- Modify: `ForgetMeNote/V3/Components/V3CaptureFAB.swift`

- [ ] **Step 1: Replace the FAB body with a glass-circle style**

Replace the entire contents of `ForgetMeNote/V3/Components/V3CaptureFAB.swift` with:

```swift
import SwiftUI

/// Capture button styled as a liquid-glass circle so it reads as a sibling of
/// the bottom glass tab bar. ~56pt to match the bar's height; accent-tinted
/// camera icon. Tapping presents the `V3CaptureSheet`.
struct V3CaptureFAB: View {
    let palette: V3Palette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 56, height: 56)
                .background(glass)
                .overlay(Circle().stroke(.white.opacity(0.45), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("v3-capture-fab")
        .accessibilityLabel("Capture new memory")
    }

    @ViewBuilder private var glass: some View {
        if #available(iOS 26.0, *) {
            Circle()
                .fill(.regularMaterial)
                .glassEffect(.regular.tint(palette.accentSoft), in: .circle)
        } else {
            Circle().fill(.regularMaterial)
        }
    }
}
```

> Note: If `.glassEffect(.regular.tint(_:), in:)` fails to compile against the
> installed SDK (the API is iOS 26 and signatures shifted across betas), delete
> the `if #available` branch and keep only `Circle().fill(.regularMaterial)` —
> it still reads as glass and always compiles. Do not block on this.

- [ ] **Step 2: Regenerate the project and build for Simulator**

Run:
```bash
cd ~/Documents/forgetmenotev3/ios && xcodegen generate && \
  SKIP_MLKIT=1 LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install
JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote \
    -configuration Debug -destination "generic/platform=iOS Simulator" \
    -allowProvisioningUpdates ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Verify checkpoint (no git — just confirm build is green)**

Confirm the output ends with `** BUILD SUCCEEDED **`. If it failed on `glassEffect`, apply the fallback note from Step 1 and rebuild.

---

## Task 2: Position the FAB beside the tab bar

**Files:**
- Modify: `ForgetMeNote/V3/V3RootView.swift:109-117`

- [ ] **Step 1: Reduce the FAB's bottom padding so it sits at tab-bar level**

In `ForgetMeNote/V3/V3RootView.swift`, find this block (lines ~109-117):

```swift
            if !showWelcome {
                V3CaptureFAB(palette: palette) {
                    showCaptureSheet = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 90)
                .allowsHitTesting(true)
                .zIndex(5)
            }
```

Replace it with:

```swift
            if !showWelcome {
                // Sits as a separate glass circle to the RIGHT of the tab-bar
                // pill, vertically centered at the same level (iOS 26 accessory
                // look). Bottom padding is tuned on-device — see Step 3.
                V3CaptureFAB(palette: palette) {
                    showCaptureSheet = true
                }
                .padding(.trailing, 16)
                .padding(.bottom, 6)
                .allowsHitTesting(true)
                .zIndex(5)
            }
```

- [ ] **Step 2: Build for Simulator**

Run:
```bash
cd ~/Documents/forgetmenotev3/ios && \
JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote \
    -configuration Debug -destination "generic/platform=iOS Simulator" \
    -allowProvisioningUpdates ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: On-device visual tune (verification — requires the user)**

The exact `.padding(.bottom, …)` for perfect vertical alignment with the glass tab bar is visual and device-specific. Build + install on the iPhone (commands in `CLAUDE.md`), launch, and ask the user to confirm the camera button is level with the tab bar to its right. If it sits too low/high, adjust the `.padding(.bottom,` value (try 0–16) and reinstall. Do not consider this task done until the user confirms the placement looks right.

---

## Task 3: Geometry helpers + unit test (TDD)

**Files:**
- Create: `ForgetMeNote/V3/Vision/V3DetectionGeometry.swift`
- Test: `ForgetMeNoteTests/V3DetectionGeometryTests.swift`

- [ ] **Step 1: Write the failing test**

Create `ForgetMeNoteTests/V3DetectionGeometryTests.swift`:

```swift
import XCTest
@testable import ForgetMeNote

final class V3DetectionGeometryTests: XCTestCase {

    func testDisplayRectMapsNormalizedToContainer() {
        let r = Rectangle(x: 0.25, y: 0.5, width: 0.5, height: 0.25)
        let rect = V3DetectionGeometry.displayRect(for: r, in: CGSize(width: 200, height: 400))
        XCTAssertEqual(rect.origin.x, 50, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 200, accuracy: 0.001)
        XCTAssertEqual(rect.size.width, 100, accuracy: 0.001)
        XCTAssertEqual(rect.size.height, 100, accuracy: 0.001)
    }

    func testIoUIdenticalRectsIsOne() {
        let a = Rectangle(x: 0.1, y: 0.1, width: 0.4, height: 0.4)
        XCTAssertEqual(V3DetectionGeometry.iou(a, a), 1.0, accuracy: 0.0001)
    }

    func testIoUDisjointRectsIsZero() {
        let a = Rectangle(x: 0.0, y: 0.0, width: 0.2, height: 0.2)
        let b = Rectangle(x: 0.5, y: 0.5, width: 0.2, height: 0.2)
        XCTAssertEqual(V3DetectionGeometry.iou(a, b), 0.0, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails to compile (type not defined)**

Run:
```bash
cd ~/Documents/forgetmenotev3/ios && xcodegen generate && \
JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  xcodebuild test -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -only-testing:ForgetMeNoteTests/V3DetectionGeometryTests \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES 2>&1 | tail -15
```
Expected: FAIL — `cannot find 'V3DetectionGeometry' in scope`.

> If `iPhone 16` is not an installed simulator, run `xcrun simctl list devices available` and substitute any booted/available iPhone name.

- [ ] **Step 3: Create the geometry helper**

Create `ForgetMeNote/V3/Vision/V3DetectionGeometry.swift`:

```swift
import CoreGraphics

/// Pure geometry helpers shared by the V3 detection overlay and service.
/// Kept free of UIKit/Vision so it is trivially unit-testable.
enum V3DetectionGeometry {

    /// Map a normalized rect (0..1, origin top-left) into pixel coordinates
    /// within a container of the given `size`. Mirrors how `V3SpaceScreen`
    /// already positions sub-space rectangles (normalized × frame size).
    static func displayRect(for r: Rectangle, in size: CGSize) -> CGRect {
        CGRect(
            x: CGFloat(r.x) * size.width,
            y: CGFloat(r.y) * size.height,
            width: CGFloat(r.width) * size.width,
            height: CGFloat(r.height) * size.height
        )
    }

    /// Intersection-over-union of two normalized rects (0 = disjoint, 1 = equal).
    static func iou(_ a: Rectangle, _ b: Rectangle) -> Float {
        let ax2 = a.x + a.width, ay2 = a.y + a.height
        let bx2 = b.x + b.width, by2 = b.y + b.height
        let ix = max(0, min(ax2, bx2) - max(a.x, b.x))
        let iy = max(0, min(ay2, by2) - max(a.y, b.y))
        let intersection = ix * iy
        let union = a.width * a.height + b.width * b.height - intersection
        guard union > 0 else { return 0 }
        return intersection / union
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
cd ~/Documents/forgetmenotev3/ios && xcodegen generate && \
JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  xcodebuild test -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    -only-testing:ForgetMeNoteTests/V3DetectionGeometryTests \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES 2>&1 | tail -15
```
Expected: `** TEST SUCCEEDED **` with 3 tests passing.

---

## Task 4: V3VisionService (Apple Vision detection)

**Files:**
- Create: `ForgetMeNote/V3/Vision/V3VisionService.swift`

- [ ] **Step 1: Create the service**

Create `ForgetMeNote/V3/Vision/V3VisionService.swift`:

```swift
import Foundation
import UIKit
import Vision
import CoreImage

/// V3-native, fully on-device object detection. Uses Apple Vision's instance
/// segmentation (`GenerateForegroundInstanceMaskRequest`, iOS 18+) to find
/// foreground objects with shape-accurate masks, then names each with
/// `VNClassifyImageRequest`. No ML Kit — so it runs in the Simulator and
/// replaces the Android-port fixed-category detector for the V3 flow.
///
/// Returns `DetectedObjectInfo` with a normalized bounding box, top label +
/// alternates, and a full-image alpha mask PNG for drawing the silhouette.
enum V3VisionService {

    /// Detect foreground object instances. Returns `[]` on iOS < 18, when the
    /// image can't be loaded, or when nothing is found.
    static func detect(imagePath: String) async -> [DetectedObjectInfo] {
        guard #available(iOS 18.0, *) else { return [] }
        return await detectInstances(imagePath: imagePath)
    }

    @available(iOS 18.0, *)
    private static func detectInstances(imagePath: String) async -> [DetectedObjectInfo] {
        guard let original = UIImage(contentsOfFile: imagePath),
              let cg = original.cgImage else { return [] }

        let handler = Vision.ImageRequestHandler(cg, orientation: cgOrientation(original))
        let request = Vision.GenerateForegroundInstanceMaskRequest()

        let observation: Vision.InstanceMaskObservation?
        do {
            observation = try await handler.perform(request)
        } catch {
            print("V3VisionService: foreground mask failed: \(error)")
            return []
        }
        guard let observation else { return [] }

        var detections: [DetectedObjectInfo] = []
        for instance in observation.allInstances {
            let set = IndexSet(integer: instance)

            guard let maskBuffer = try? observation.generateScaledMask(
                for: set, scaledToImageFrom: handler),
                  let mask = alphaMaskAndBounds(from: maskBuffer) else { continue }

            // Skip slivers — not worth offering as a sub-space.
            guard mask.boundingBox.width * mask.boundingBox.height > 0.006 else { continue }

            // Prefer the background-removed crop for cleaner classification.
            let crop: UIImage
            if let maskedBuffer = try? observation.generateMaskedImage(
                for: set, imageFrom: handler, croppedToInstancesExtent: true),
               let maskedImage = image(from: maskedBuffer) {
                crop = maskedImage
            } else {
                crop = cropToNormalizedRect(original, rect: mask.boundingBox) ?? original
            }

            let labels = await VisionClassificationService.classifyTop(
                crop, maxResults: 3, minConfidence: 0.16)
            let top = labels.first

            detections.append(DetectedObjectInfo(
                boundingBox: mask.boundingBox,
                label: top?.text ?? "Object",
                confidence: top?.confidence ?? 0.3,
                alternates: Array(labels.dropFirst().map(\.text)),
                maskPNGData: mask.pngData
            ))
        }
        return mergeOverlaps(detections)
    }

    // MARK: - Helpers (self-contained so the v2 ML Kit service stays untouched)

    private static func mergeOverlaps(_ detections: [DetectedObjectInfo]) -> [DetectedObjectInfo] {
        detections
            .sorted { $0.confidence > $1.confidence }
            .reduce(into: [DetectedObjectInfo]()) { kept, candidate in
                guard !kept.contains(where: {
                    V3DetectionGeometry.iou($0.boundingBox, candidate.boundingBox) > 0.74
                }) else { return }
                kept.append(candidate)
            }
    }

    private static func cropToNormalizedRect(_ image: UIImage, rect r: Rectangle) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let cropRect = CGRect(
            x: max(0, CGFloat(r.x) * w),
            y: max(0, CGFloat(r.y) * h),
            width: min(w, CGFloat(r.width) * w),
            height: min(h, CGFloat(r.height) * h)
        )
        guard cropRect.width >= 1, cropRect.height >= 1 else { return nil }
        guard let cropped = cg.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Convert a single-instance mask pixel buffer into a white-RGB / alpha-mask
    /// PNG and its tight normalized bounding box.
    private static func alphaMaskAndBounds(from pixelBuffer: CVPixelBuffer) -> (pngData: Data, boundingBox: Rectangle)? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)

        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        var minX = width, minY = height, maxX = -1, maxY = -1

        for y in 0..<height {
            let row = base.advanced(by: y * bytesPerRow)
            for x in 0..<width {
                let value: Float
                if format == kCVPixelFormatType_OneComponent32Float {
                    value = row.assumingMemoryBound(to: Float.self)[x]
                } else {
                    value = Float(row.assumingMemoryBound(to: UInt8.self)[x]) / 255.0
                }
                let alpha = UInt8(max(0, min(255, Int(value * 255))))
                let i = (y * width + x) * 4
                rgba[i] = 255; rgba[i + 1] = 255; rgba[i + 2] = 255; rgba[i + 3] = alpha
                if alpha > 24 {
                    minX = min(minX, x); minY = min(minY, y)
                    maxX = max(maxX, x); maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let cg = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent),
              let png = UIImage(cgImage: cg).pngData() else { return nil }

        return (
            png,
            Rectangle(
                x: Float(minX) / Float(width),
                y: Float(minY) / Float(height),
                width: Float(maxX - minX + 1) / Float(width),
                height: Float(maxY - minY + 1) / Float(height)
            )
        )
    }

    private static func image(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cg = CIContext().createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private static func cgOrientation(_ image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
```

- [ ] **Step 2: Regenerate + build for Simulator**

Run:
```bash
cd ~/Documents/forgetmenotev3/ios && xcodegen generate && \
JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote \
    -configuration Debug -destination "generic/platform=iOS Simulator" \
    -allowProvisioningUpdates ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

---

## Task 5: V3DetectionOverlay component

**Files:**
- Create: `ForgetMeNote/V3/Components/V3DetectionOverlay.swift`

- [ ] **Step 1: Create the overlay**

Create `ForgetMeNote/V3/Components/V3DetectionOverlay.swift`:

```swift
import SwiftUI

/// Draws detected objects over the hero photo: each object's segmentation mask
/// as a glowing accent silhouette, a tappable hit-area over its bounding box,
/// and a floating label capsule. Tapping selects (the caller shows a confirm
/// action). Designed to be placed INSIDE the hero photo's `GeometryReader`, so
/// it receives the same `size` the photo is drawn at.
struct V3DetectionOverlay: View {
    let palette: V3Palette
    let detections: [DetectedObjectInfo]
    let size: CGSize
    let selectedId: UUID?
    let onSelect: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(detections) { det in
                let selected = det.id == selectedId
                let box = V3DetectionGeometry.displayRect(for: det.boundingBox, in: size)

                // Glowing silhouette from the alpha mask, drawn at full photo
                // size with the same scaledToFill so it aligns with the image.
                if let maskImage = maskImage(det.maskPNGData) {
                    Image(uiImage: maskImage)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .foregroundStyle(palette.accent)
                        .opacity(selectedId == nil ? 0.32 : (selected ? 0.6 : 0.12))
                        .shadow(color: palette.accent.opacity(selected ? 0.7 : 0.35),
                                radius: selected ? 14 : 6)
                        .allowsHitTesting(false)
                        .animation(.easeOut(duration: 0.25), value: selectedId)
                }

                // Tappable bounding-box hit area + outline.
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? palette.accent : .white.opacity(0.9),
                            lineWidth: selected ? 2.5 : 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.001)) // keeps the whole box tappable
                    )
                    .frame(width: box.width, height: box.height)
                    .offset(x: box.minX, y: box.minY)
                    .onTapGesture { onSelect(det.id) }
                    .accessibilityIdentifier("v3-detection-\(det.id.uuidString)")

                // Label capsule pinned to the top-left of the box.
                Text(det.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .tracking(-0.1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(selected ? palette.accent : Color(white: 0.08).opacity(0.7),
                                in: Capsule())
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .offset(x: box.minX, y: max(0, box.minY - 26))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func maskImage(_ data: Data?) -> UIImage? {
        guard let data else { return nil }
        return UIImage(data: data)
    }
}
```

- [ ] **Step 2: Regenerate + build for Simulator**

Run:
```bash
cd ~/Documents/forgetmenotev3/ios && xcodegen generate && \
JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote \
    -configuration Debug -destination "generic/platform=iOS Simulator" \
    -allowProvisioningUpdates ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

---

## Task 6: Wire detection into V3SpaceScreen

**Files:**
- Modify: `ForgetMeNote/V3/Screens/V3SpaceScreen.swift`

- [ ] **Step 1: Add detection state**

In `ForgetMeNote/V3/Screens/V3SpaceScreen.swift`, find the existing state block (lines ~18-20):

```swift
    @State private var activeSubId: String? = nil
    @State private var viewMode: SubViewMode = .photo
    @State private var showDetail: Bool = false
```

Add below it:

```swift
    // On-device object detection (V3VisionService).
    @State private var detections: [DetectedObjectInfo] = []
    @State private var isDetecting: Bool = false
    @State private var selectedDetectionId: UUID? = nil
    @State private var detectionMessage: String? = nil
```

- [ ] **Step 2: Render the overlay + scanning state inside the hero photo**

In the `heroPhoto(item:)` function, find the closing of the sub-space rectangles `ForEach` and the "Tap hint" block. Immediately AFTER the sub-space `ForEach(Array(subs.enumerated())...)` closes (just before the `// Tap hint when no active sub` comment at line ~197), insert:

```swift
                // AI detection overlay (transient — not persisted).
                if !detections.isEmpty {
                    V3DetectionOverlay(
                        palette: palette,
                        detections: detections,
                        size: geo.size,
                        selectedId: selectedDetectionId,
                        onSelect: { id in
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedDetectionId = (selectedDetectionId == id) ? nil : id
                            }
                        }
                    )
                }

                // Scanning shimmer while detection runs.
                if isDetecting {
                    ZStack {
                        Color.black.opacity(0.28)
                        VStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)
                            Text("Finding objects…")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .allowsHitTesting(false)
                }
```

- [ ] **Step 3: Add the "Find objects" / confirm action bar under the photo**

In `body`, find where `heroPhoto(item: item)` is called (lines ~88-89):

```swift
                    heroPhoto(item: item)
                        .padding(.horizontal, 16)
```

Insert directly AFTER it:

```swift
                    detectionBar(item: item)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
```

- [ ] **Step 4: Add the `detectionBar` view + actions**

In `V3SpaceScreen`, in the `// MARK: - Actions` section (just before `private func openSub`), add:

```swift
    @ViewBuilder private func detectionBar(item: ImageItem) -> some View {
        VStack(spacing: 10) {
            if let id = selectedDetectionId,
               let det = detections.first(where: { $0.id == id }) {
                // A detection is selected → offer to turn it into a sub-space.
                HStack(spacing: 10) {
                    Button(action: confirmSelectedDetection) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add “\(det.label)” ✦")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("v3-space-add-detection")

                    Button(action: clearDetections) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.ink2)
                            .frame(width: 46, height: 46)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("v3-space-clear-detection")
                }
            } else {
                // No selection → the detect trigger (or a re-run while results show).
                Button(action: runDetection) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                        Text(detections.isEmpty ? "Find objects" : "Scan again")
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(-0.1)
                    }
                    .foregroundStyle(palette.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(palette.accentBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isDetecting || item.filePath == nil)
                .opacity(item.filePath == nil ? 0.4 : 1)
                .accessibilityIdentifier("v3-space-detect")
            }

            if let msg = detectionMessage {
                Text(msg)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.ink3)
            }
        }
    }

    private func runDetection() {
        guard let path = item?.filePath else { return }
        isDetecting = true
        detectionMessage = nil
        selectedDetectionId = nil
        Task {
            let results = await V3VisionService.detect(imagePath: path)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.35)) {
                    detections = results
                    isDetecting = false
                    detectionMessage = results.isEmpty ? "No objects found — add one by hand." : nil
                }
            }
        }
    }

    private func confirmSelectedDetection() {
        guard let id = selectedDetectionId,
              let det = detections.first(where: { $0.id == id }) else { return }
        let box = det.boundingBox
        let label = det.label
        clearDetections()
        path.append(Route.createChild(
            parentId: spaceId,
            suggestedTitle: label,
            rectangleOnParent: box,
            tempPhotoPath: nil
        ))
    }

    private func clearDetections() {
        withAnimation(.easeOut(duration: 0.2)) {
            detections = []
            selectedDetectionId = nil
            detectionMessage = nil
        }
    }
```

- [ ] **Step 5: Regenerate + build for Simulator**

Run:
```bash
cd ~/Documents/forgetmenotev3/ios && xcodegen generate && \
JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote \
    -configuration Debug -destination "generic/platform=iOS Simulator" \
    -allowProvisioningUpdates ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

---

## Task 7: Regression QA + device verification

**Files:**
- (No new files required.) Optionally extend `qa/maestro/flows/v3_full_qa.yaml`.

- [ ] **Step 1: Run the existing Maestro suite (regression baseline)**

Install the Simulator build, then run the existing flow to confirm the FAB
reposition and new code didn't break navigation:

```bash
cd ~/Documents/forgetmenotev3/ios
SIM_APP=~/Library/Developer/Xcode/DerivedData/ForgetMeNote-*/Build/Products/Debug-iphonesimulator/ForgetMeNote.app
xcrun simctl install booted "$SIM_APP"
JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  maestro test qa/maestro/flows/v3_full_qa.yaml
```
Expected: all 23 steps pass (the `v3-capture-fab` element is still present, just repositioned).

- [ ] **Step 2: Add a minimal detection-wiring Maestro check (optional but recommended)**

> Detection needs a photo-backed space; the seeded data is rooms only, and the
> Simulator has no camera. So this step verifies the **button wiring**, not mask
> quality. If you can navigate to a `V3SpaceScreen` that has a photo (e.g. via an
> imported/demo item), append to `qa/maestro/flows/v3_full_qa.yaml`:

```yaml
# --- AI detection wiring (only meaningful on a photo-backed space) ---
- runFlow:
    when:
      visible:
        id: "v3-space-detect"
    commands:
      - tapOn:
          id: "v3-space-detect"
      - extendedWaitUntil:
          visible:
            id: "v3-space-detect"   # returns to idle, or results appear
          timeout: 8000
```

Run the suite again; expected: passes (the `when:` guard no-ops if no photo space is reachable).

- [ ] **Step 3: Device build + install (commands from CLAUDE.md)**

```bash
cd ~/Documents/forgetmenotev3/ios && xcodegen generate && \
  LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install && \
  JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote -configuration Debug \
    -destination "id=E7A0CD3B-A97A-5548-A204-E046CA2ACAFD" -allowProvisioningUpdates build && \
  xcrun devicectl device install app --device E7A0CD3B-A97A-5548-A204-E046CA2ACAFD \
    ~/Library/Developer/Xcode/DerivedData/ForgetMeNote-*/Build/Products/Debug-iphoneos/ForgetMeNote.app && \
  xcrun devicectl device process launch --device E7A0CD3B-A97A-5548-A204-E046CA2ACAFD \
    com.matthewcromaz.forgetmenote.v3.dev
```
Expected: `** BUILD SUCCEEDED **`, app installs and launches.

> Note: this is the **non-`SKIP_MLKIT`** `pod install` so ML Kit is restored for
> the device build (v2 still uses it). The first build after toggling pods is slow.

- [ ] **Step 4: On-device manual verification (requires the user)**

Ask the user to confirm, on the iPhone:
1. The camera button is a glass circle level with and to the right of the tab bar.
2. Open a real photo space (capture a photo of a shelf/desk), tap **Find objects** → glowing object outlines + labels animate in within a couple seconds.
3. Tap an object → it highlights and the **Add "<label>" ✦** button appears.
4. Tap it → lands on the create-sub-space screen with the name + box prefilled; saving creates the sub-space, which then shows in "What's inside".

Do not mark the feature complete until the user confirms detection works on-device.

---

## Self-review

**Spec coverage:**
- FAB reposition → Tasks 1–2. ✓
- Glass-pill restyle → Task 1. ✓
- Apple-Vision-only, no-ML-Kit detection → Task 4 (`V3VisionService`). ✓
- Boxes + masks + labels rendering → Task 5 (`V3DetectionOverlay`). ✓
- "Find objects" button on the single-photo view → Task 6 (`detectionBar`, `v3-space-detect`). ✓
- Tap-to-select, user confirms → Task 6 (`onSelect` toggles selection; `confirmSelectedDetection`). ✓
- Confirm prefills box + label via existing create flow → Task 6 (`Route.createChild`). ✓
- Detections not persisted → held in `@State`, cleared on confirm/clear. ✓
- Simulator-testable / Maestro → Task 3 (unit) + Task 7 (regression + wiring check). ✓
- v2 untouched → no edits to `Views/`, ML Kit, Podfile, project.yml info. ✓

**Placeholder scan:** No TBD/TODO; every code step has full code; commands have expected output. The single intentional variability — the FAB `.padding(.bottom,` value and the optional Maestro photo-space — are explicitly flagged as on-device-tuned / guarded, not placeholders.

**Type consistency:**
- `DetectedObjectInfo.id` is `UUID` → `selectedDetectionId: UUID?`, `onSelect: (UUID) -> Void`, lookups via `first(where: { $0.id == id })`. ✓
- `Rectangle(x:y:width:height:)` Float fields used consistently. ✓
- `V3DetectionGeometry.displayRect(for:in:)` / `iou(_:_:)` names match across service, overlay, and tests. ✓
- `V3VisionService.detect(imagePath:)` signature matches the call in `runDetection`. ✓
- `VisionClassificationService.classifyTop(_:maxResults:minConfidence:)` matches its definition. ✓
- `Route.createChild(parentId:suggestedTitle:rectangleOnParent:tempPhotoPath:)` matches `Route.swift`. ✓
- `v3LoadImage` / `palette.accent|accentSoft|accentBg|surface|ink2|ink3` all exist in the codebase. ✓
```
