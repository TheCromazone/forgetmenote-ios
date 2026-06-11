# v3: Working/Better Detection + Opt-in Cropping — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** In the **v3 app only**, make object detection reachable and noticeably better (more/smaller objects, more specific labels, segmentation outlines), and make the sub-space crop box **optional behind a button** with smooth, working four-corner drag handles and no lag.

**Architecture:** All changes are v3-isolated. A new reusable `V3CropBox` (corner-handle cropper) and `V3ImageDownsampler` (ImageIO downsampling) fix the lag/handles; `V3CreateSubScreen` gains an opt-in crop toggle and prefill support; `V3VisionService` is enriched to compose the **public** shared ML services (Apple Vision masks + ML Kit detector/labeler) for richer results. One **additive** repo method (`createSubSpace`) persists a rectangle-anchored child with no photo. Shared `ML/*`, `Views/*`, and `V4/*` files are NOT edited.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, Apple Vision, Google ML Kit (device-only), ImageIO. xcodegen + CocoaPods.

---

## Environment notes (read first)
- **NOT a git repo** — no commits; each task ends at a build-verify checkpoint.
- xcodegen auto-discovers sources under `ForgetMeNote/`. After creating files run `xcodegen generate`. Build convention: `xcodegen generate` THEN `SKIP_MLKIT=1 pod install` (pod install must follow xcodegen). Sim builds skip ML Kit; the final device build uses plain `pod install` to restore it.
- Sim build command (used for per-task verification):
  ```bash
  cd ~/Documents/forgetmenotev3/ios && xcodegen generate && \
    SKIP_MLKIT=1 LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install >/dev/null 2>&1; \
  JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
    xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote \
      -configuration Debug -destination "generic/platform=iOS Simulator" \
      -allowProvisioningUpdates ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build 2>&1 | tail -8
  ```
  Expected: `** BUILD SUCCEEDED **`.
- **Do NOT edit** `ForgetMeNote/V4/*`, `ForgetMeNote/Views/*` (incl. `InteractiveRectangleSelector`, `CreateChildScreen`, `ImageDetailScreen`), or `ForgetMeNote/ML/*`. Call their public APIs only.
- Existing facts: `Rectangle{Float x,y,width,height}`; `DetectedObjectInfo{id:UUID, boundingBox:Rectangle, label:String, confidence:Float, alternates:[String], maskPNGData:Data?}`; `V3DetectionGeometry.iou(_:_:)`/`displayRect(for:in:)`; public `ObjectDetectionService.detectObjects(imagePath:area:) async -> [DetectedObjectInfo]`; public `VisionClassificationService.classifyTop(_:maxResults:minConfidence:) async -> [(text:String,confidence:Float)]`; public `ImageLabelingService.labelsForCroppedImage(_:maxResults:) async -> [ImageLabel]` where `ImageLabel{text:String,confidence:Float}`; `VisionClassificationService.prettifyIdentifier`/`isGenericIdentifier` are public; `v3LoadImage(filePath:)` exists; palette tokens `accent/accentSoft/accentBg/surface/ink/ink2/ink3/line/paper/paperEdge/danger`.

---

## Task 1: `V3ImageDownsampler`

**Files:** Create `ForgetMeNote/V3/Vision/V3ImageDownsampler.swift`

- [ ] **Step 1: Create the file**
```swift
import UIKit
import ImageIO

/// ImageIO-based downsampling so we never decode a full-resolution camera
/// bitmap into memory just to show it behind the crop box. v3-only.
enum V3ImageDownsampler {

    /// Downsample an image file to roughly `maxPixelSize` on its longest edge.
    static func downsample(path: String, maxPixelSize: CGFloat = 1400) -> UIImage? {
        let url = URL(fileURLWithPath: path)
        let srcOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithURL(url as CFURL, srcOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixelSize, 1)
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// Downsample an in-memory image (e.g. a freshly captured temp photo).
    static func downsample(_ image: UIImage, maxPixelSize: CGFloat = 1400) -> UIImage {
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > maxPixelSize else { return image }
        let ratio = maxPixelSize / maxSide
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize, format: .default())
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
```

- [ ] **Step 2: Build for Simulator** (command above). Expected `** BUILD SUCCEEDED **`.

---

## Task 2: `V3CropBox` (corner-handle cropper)

**Files:** Create `ForgetMeNote/V3/Components/V3CropBox.swift`

- [ ] **Step 1: Create the file**
```swift
import SwiftUI

/// Reusable crop rectangle with four independently-draggable corner handles and
/// a drag-to-move body, operating in normalized (0..1) coords bound to `rect`.
/// Place inside a container of pixel `size`. Latches the rect at drag-start so
/// handles don't jump (the bug in the old selector). v3-only.
struct V3CropBox: View {
    let palette: V3Palette
    @Binding var rect: Rectangle
    let size: CGSize

    @State private var dragStart: Rectangle? = nil
    private let minSize: Float = 0.06

    var body: some View {
        let w = size.width, h = size.height
        let rw = CGFloat(rect.width) * w
        let rh = CGFloat(rect.height) * h

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(palette.accent.opacity(0.10))
                .frame(width: rw, height: rh)
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(palette.accent, lineWidth: 2.5))
                .contentShape(SwiftUI.Rectangle())
                .gesture(moveGesture(w: w, h: h))
                .accessibilityIdentifier("v3-cropbox-rect")

            ForEach(0..<4, id: \.self) { idx in
                handle(idx: idx, w: w, h: h, rw: rw, rh: rh)
            }
        }
        .offset(x: CGFloat(rect.x) * w, y: CGFloat(rect.y) * h)
    }

    private func moveGesture(w: CGFloat, h: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if dragStart == nil { dragStart = rect }
                let base = dragStart ?? rect
                let dx = Float(v.translation.width / w)
                let dy = Float(v.translation.height / h)
                let nx = max(0, min(1 - base.width, base.x + dx))
                let ny = max(0, min(1 - base.height, base.y + dy))
                rect = Rectangle(x: nx, y: ny, width: base.width, height: base.height)
            }
            .onEnded { _ in dragStart = nil }
    }

    @ViewBuilder
    private func handle(idx: Int, w: CGFloat, h: CGFloat, rw: CGFloat, rh: CGFloat) -> some View {
        let isLeft = (idx == 0 || idx == 2)
        let isTop = (idx == 0 || idx == 1)
        Circle()
            .fill(.white)
            .overlay(Circle().strokeBorder(palette.accent, lineWidth: 2.5))
            .frame(width: 20, height: 20)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .offset(x: isLeft ? -10 : rw - 10, y: isTop ? -10 : rh - 10)
            .contentShape(Circle().inset(by: -16))
            .gesture(resizeGesture(isLeft: isLeft, isTop: isTop, w: w, h: h))
            .accessibilityIdentifier("v3-cropbox-handle-\(idx)")
    }

    private func resizeGesture(isLeft: Bool, isTop: Bool, w: CGFloat, h: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if dragStart == nil { dragStart = rect }
                let base = dragStart ?? rect
                let dx = Float(v.translation.width / w)
                let dy = Float(v.translation.height / h)
                var r = base
                if isLeft {
                    let nx = max(0, min(base.x + base.width - minSize, base.x + dx))
                    r.x = nx; r.width = base.width - (nx - base.x)
                } else {
                    r.width = max(minSize, min(1 - base.x, base.width + dx))
                }
                if isTop {
                    let ny = max(0, min(base.y + base.height - minSize, base.y + dy))
                    r.y = ny; r.height = base.height - (ny - base.y)
                } else {
                    r.height = max(minSize, min(1 - base.y, base.height + dy))
                }
                rect = r
            }
            .onEnded { _ in dragStart = nil }
    }
}
```

- [ ] **Step 2: Build for Simulator.** Expected `** BUILD SUCCEEDED **`.

---

## Task 3: Additive repo method `createSubSpace`

**Files:** Modify `ForgetMeNote/Repository/ImageRepository.swift`

This is **additive** — no existing caller changes, so v2/v4 behavior is unchanged.

- [ ] **Step 1: Add the method** immediately AFTER the existing `createRoom(...)` method (which ends around line 125, before `saveImage`). Read the file to confirm the `ImageItem(...)` initializer accepts `rectangleOnParent:` (it does — `saveImage` uses it). Insert:
```swift
    /// Create a sub-space (region) anchored on a parent photo by a rectangle,
    /// WITHOUT its own photo. Used by the v3 detection / "mark a spot" flow when
    /// the user doesn't attach a picture. Additive — mirrors `createRoom` plus a
    /// `rectangleOnParent`.
    @discardableResult
    func createSubSpace(
        name: String,
        tags: [String] = [],
        parentId: String,
        rectangleOnParent: Rectangle?
    ) throws -> String {
        let item = ImageItem(
            name: name,
            tags: tags,
            thumbnail: nil,
            filePath: nil,
            parentId: parentId,
            rectangleOnParent: rectangleOnParent
        )
        modelContext.insert(item)
        try attachToParent(itemId: item.id, parentId: parentId)
        try modelContext.save()
        return item.id
    }
```
> If the `ImageItem(...)` initializer used by `createRoom` does NOT accept `rectangleOnParent:` and `filePath:` together in one initializer, instead construct the item like `createRoom` does and then set `item.rectangleOnParent = rectangleOnParent` before `modelContext.insert` (confirm `rectangleOnParent` has a setter on `ImageItem`; if it only has `rectangleJSON`, set that via the model's encode helper). Pick whichever compiles; do not change `createRoom`.

- [ ] **Step 2: Build for Simulator.** Expected `** BUILD SUCCEEDED **`.

---

## Task 4: Wire the v3 create flow (Route + V3RootView + V3SpaceScreen + V3CreateSubScreen rework)

This single task makes all the interconnected signature changes at once so the build stays green. **Files:**
- Modify `ForgetMeNote/Views/Route.swift`
- Modify `ForgetMeNote/V3/V3RootView.swift`
- Modify `ForgetMeNote/V3/Screens/V3SpaceScreen.swift`
- Replace `ForgetMeNote/V3/Screens/V3CreateSubScreen.swift`

- [ ] **Step 1: Extend the `v3CreateSub` route.** In `Route.swift`, replace:
```swift
    case v3CreateSub(parentId: String, tempPhotoPath: String?)
```
with:
```swift
    case v3CreateSub(parentId: String, tempPhotoPath: String?,
                     suggestedRect: Rectangle? = nil, suggestedTitle: String? = nil)
```

- [ ] **Step 2: Update `V3RootView` call sites.** Read `V3RootView.swift`. In `destination(for:)`, replace the `.v3CreateSub` case with:
```swift
        case .v3CreateSub(let parentId, let tempPath, let rect, let title):
            V3CreateSubScreen(parentId: parentId, tempPhotoPath: tempPath,
                              suggestedRect: rect, suggestedTitle: title,
                              path: currentPathBinding)
```
The existing `routeToCreateSub` calls `Route.v3CreateSub(parentId:tempPhotoPath:)`; thanks to the defaulted new params it still compiles unchanged. Verify by grepping `grep -rn "\.v3CreateSub(" ForgetMeNote/` and confirm every construction site still compiles (defaults cover them).

- [ ] **Step 3: Replace `V3CreateSubScreen.swift`** with the full content below (adds opt-in cropping via `V3CropBox`, downsampled display image, prefill, and the no-photo+rect save path):
```swift
import SwiftUI
import SwiftData

/// V3 create-sub-space screen. Shows the parent photo with an OPTIONAL crop box
/// (off by default, revealed by a button) whose four corners drag to fit the
/// spot. Save commits a new ImageItem under `parentId`: with a photo when one
/// was captured, otherwise a rectangle-anchored sub-space (or a plain sub-room
/// when cropping is off).
struct V3CreateSubScreen: View {
    let parentId: String
    let tempPhotoPath: String?
    let suggestedRect: Rectangle?
    let suggestedTitle: String?
    @Binding var path: NavigationPath

    @Environment(\.v3Palette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var parents: [ImageItem]
    private var parent: ImageItem? { parents.first }

    @State private var rect: Rectangle
    @State private var cropEnabled: Bool
    @State private var name: String
    @State private var tagsText: String = ""
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var displayImage: UIImage?

    init(parentId: String, tempPhotoPath: String?,
         suggestedRect: Rectangle? = nil, suggestedTitle: String? = nil,
         path: Binding<NavigationPath>) {
        self.parentId = parentId
        self.tempPhotoPath = tempPhotoPath
        self.suggestedRect = suggestedRect
        self.suggestedTitle = suggestedTitle
        self._path = path
        let id = parentId
        self._parents = Query(filter: #Predicate<ImageItem> { $0.id == id })
        _rect = State(initialValue: suggestedRect ?? Rectangle(x: 0.25, y: 0.30, width: 0.50, height: 0.40))
        _cropEnabled = State(initialValue: suggestedRect != nil)
        _name = State(initialValue: suggestedTitle ?? "")
    }

    private var parentName: String { parent?.name ?? "" }
    /// Whether there is any photo to crop against (capture temp OR parent's photo).
    private var hasCroppablePhoto: Bool {
        tempPhotoPath != nil || parent?.filePath != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            V3NavHeader(
                palette: palette,
                title: "Mark a spot",
                subtitle: parentName.isEmpty ? nil : "in \(parentName)",
                onBack: { dismiss() }
            ) {
                Button(action: save) {
                    Text(saving ? "Saving…" : "Save")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(saving ? palette.ink3 : palette.accent)
                }
                .buttonStyle(.plain)
                .disabled(saving)
                .accessibilityIdentifier("v3-create-sub-save")
            }

            ScrollView {
                VStack(spacing: 0) {
                    photoArea
                        .padding(.horizontal, 16)

                    if hasCroppablePhoto {
                        cropToggleButton
                            .padding(.top, 12)
                        if cropEnabled {
                            Text("Drag the corners to fit the spot.")
                                .font(.system(size: 12))
                                .foregroundStyle(palette.ink3)
                                .padding(.top, 6)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }

                    fieldsCard
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(palette.danger)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 80)
                }
            }
        }
        .background(palette.paper.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: parent?.id) { await loadDisplayImage() }
    }

    private func loadDisplayImage() async {
        let img: UIImage?
        if let tempPhotoPath {
            img = V3ImageDownsampler.downsample(path: tempPhotoPath)
        } else if let fp = parent?.filePath {
            img = V3ImageDownsampler.downsample(path: fp)
        } else {
            img = nil
        }
        await MainActor.run { displayImage = img }
    }

    // MARK: - Photo area

    @ViewBuilder private var photoArea: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let rx = CGFloat(rect.x) * w, ry = CGFloat(rect.y) * h
            let rw = CGFloat(rect.width) * w, rh = CGFloat(rect.height) * h

            ZStack(alignment: .topLeading) {
                Group {
                    if let img = displayImage {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        palette.paperEdge.overlay(
                            Text(parentName.trimmingCharacters(in: .whitespaces).prefix(1).uppercased())
                                .font(V3Font.display(120)).foregroundStyle(palette.ink3))
                    }
                }
                .frame(width: w, height: h)
                .clipped()

                if cropEnabled && hasCroppablePhoto {
                    // Dimming around the crop box.
                    Group {
                        SwiftUI.Rectangle().fill(.black.opacity(0.45)).frame(width: w, height: ry)
                        SwiftUI.Rectangle().fill(.black.opacity(0.45))
                            .frame(width: w, height: max(0, h - (ry + rh))).offset(y: ry + rh)
                        SwiftUI.Rectangle().fill(.black.opacity(0.45))
                            .frame(width: rx, height: rh).offset(y: ry)
                        SwiftUI.Rectangle().fill(.black.opacity(0.45))
                            .frame(width: max(0, w - (rx + rw)), height: rh).offset(x: rx + rw, y: ry)
                    }
                    .allowsHitTesting(false)

                    V3CropBox(palette: palette, rect: $rect, size: geo.size)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .drawingGroup()
            .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
    }

    @ViewBuilder private var cropToggleButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { cropEnabled.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: cropEnabled ? "xmark.circle" : "viewfinder")
                    .font(.system(size: 14, weight: .bold))
                Text(cropEnabled ? "Don't mark a spot" : "Mark the exact spot ✦")
                    .font(.system(size: 14, weight: .semibold)).tracking(-0.1)
            }
            .foregroundStyle(palette.accent)
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(palette.accentBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("v3-create-sub-crop-toggle")
    }

    // MARK: - Fields card

    @ViewBuilder private var fieldsCard: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NAME").font(.system(size: 11, weight: .bold)).tracking(0.6)
                    .foregroundStyle(palette.ink3)
                TextField("e.g. Bay leaf tin", text: $name)
                    .font(V3Font.headline(24)).foregroundStyle(palette.ink)
                    .textInputAutocapitalization(.words).submitLabel(.done)
                    .accessibilityIdentifier("v3-create-sub-name")
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)

            SwiftUI.Rectangle().fill(palette.line).frame(height: 1).padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 4) {
                Text("TAGS").font(.system(size: 11, weight: .bold)).tracking(0.6)
                    .foregroundStyle(palette.ink3)
                TextField("optional · comma, separated", text: $tagsText)
                    .font(.system(size: 15)).foregroundStyle(palette.ink).submitLabel(.done)
                    .accessibilityIdentifier("v3-create-sub-tags")
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }

    // MARK: - Save

    private func save() {
        guard !saving else { return }
        saving = true
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let finalName = trimmedName.isEmpty ? "Untitled" : trimmedName
        let tagList = tagsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let savedRect: Rectangle? = cropEnabled ? rect : nil

        Task {
            let repo = ImageRepository(modelContainer: modelContext.container)
            do {
                if let tempPath = tempPhotoPath,
                   let data = try? Data(contentsOf: URL(fileURLWithPath: tempPath)) {
                    _ = try await repo.saveImage(
                        jpegData: data, name: finalName, tags: tagList,
                        parentId: parentId, rectangleOnParent: savedRect)
                    TempPhotoStore.remove(tempPath)
                } else if savedRect != nil {
                    // Anchored region on the parent photo, no photo of its own.
                    _ = try await repo.createSubSpace(
                        name: finalName, tags: tagList,
                        parentId: parentId, rectangleOnParent: savedRect)
                } else {
                    _ = try await repo.createRoom(
                        name: finalName, tags: tagList, parentId: parentId,
                        backgroundColor: nil, textColor: nil)
                }
                await MainActor.run {
                    saving = false
                    if !path.isEmpty { path.removeLast() } else { dismiss() }
                }
            } catch {
                await MainActor.run {
                    saving = false
                    errorMessage = "Save failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
```

- [ ] **Step 4: Route V3SpaceScreen's add/confirm to the v3 flow with prefill.** In `V3SpaceScreen.swift`, find `addSubAction()` and `confirmSelectedDetection()`. Replace their `path.append(Route.createChild(...))` with `Route.v3CreateSub(...)`:

`addSubAction()` becomes:
```swift
    private func addSubAction() {
        path.append(Route.v3CreateSub(parentId: spaceId, tempPhotoPath: nil,
                                      suggestedRect: nil, suggestedTitle: nil))
    }
```
`confirmSelectedDetection()` becomes (keep the rest of its body the same, only change the appended route):
```swift
    private func confirmSelectedDetection() {
        guard let id = selectedDetectionId,
              let det = detections.first(where: { $0.id == id }) else { return }
        let box = det.boundingBox
        let label = det.label
        clearDetections()
        path.append(Route.v3CreateSub(parentId: spaceId, tempPhotoPath: nil,
                                      suggestedRect: box, suggestedTitle: label))
    }
```

- [ ] **Step 5: Build for Simulator.** Expected `** BUILD SUCCEEDED **`. If a `.v3CreateSub(` construction elsewhere fails to compile, update it to pass the new defaulted args (or rely on defaults).

---

## Task 5: Enrich `V3VisionService` (more/smaller objects, better labels)

**Files:** Modify `ForgetMeNote/V3/Vision/V3VisionService.swift` (created in the prior round).

- [ ] **Step 1: Read the current file**, then make these changes inside it (keep the public `detect(imagePath:)` entry and the iOS-18 mask pass; compose public shared services for the rest). Replace the body of `detectInstances` and add helpers:

1. Lower the sliver filter from `> 0.006` to `> 0.0015`.
2. Replace the per-instance label call with a new `fusedLabels(for:)` helper that merges Apple Vision + ML Kit labeling.
3. After collecting mask detections, also fetch ML Kit detector boxes and merge.
4. NMS at IoU `> 0.6`.

Concretely, change the classification line in the instance loop from:
```swift
            let labels = await VisionClassificationService.classifyTop(
                crop, maxResults: 3, minConfidence: 0.16)
            let top = labels.first
            detections.append(DetectedObjectInfo(
                boundingBox: mask.boundingBox,
                label: top?.text ?? "Object",
                confidence: top?.confidence ?? 0.3,
                alternates: Array(labels.dropFirst().map(\.text)),
                maskPNGData: mask.pngData))
```
to:
```swift
            let labels = await fusedLabels(for: crop)
            let top = labels.first
            detections.append(DetectedObjectInfo(
                boundingBox: mask.boundingBox,
                label: top?.text ?? "Object",
                confidence: top?.confidence ?? 0.3,
                alternates: Array(labels.dropFirst().map(\.text)),
                maskPNGData: mask.pngData))
```
Change the sliver guard:
```swift
            guard mask.boundingBox.width * mask.boundingBox.height > 0.0015 else { continue }
```
At the END of `detectInstances`, before `return mergeOverlaps(detections)`, insert the ML Kit merge:
```swift
        // Merge in ML Kit detector boxes for extra/smaller objects the mask
        // pass missed (device-only; returns [] on Simulator).
        let mlBoxes = await ObjectDetectionService.detectObjects(imagePath: imagePath)
        if !mlBoxes.isEmpty, let original = UIImage(contentsOfFile: imagePath) {
            for box in mlBoxes {
                let dup = detections.contains {
                    V3DetectionGeometry.iou($0.boundingBox, box.boundingBox) > 0.5
                }
                if dup { continue }
                let crop = cropToNormalizedRect(original, rect: box.boundingBox) ?? original
                let labels = await fusedLabels(for: crop)
                guard let top = labels.first else { continue }
                detections.append(DetectedObjectInfo(
                    boundingBox: box.boundingBox,
                    label: top.text,
                    confidence: top.confidence,
                    alternates: Array(labels.dropFirst().map(\.text)),
                    maskPNGData: nil))
            }
        }
```
And change the final NMS threshold inside `mergeOverlaps` from `> 0.74` to `> 0.6`.

Add this helper (mirrors the shared engine's fusion, using public APIs):
```swift
    /// Fuse Apple Vision + ML Kit labels for one cropped region. Drops generic
    /// labels, returns up to 3 candidates by merged confidence.
    private static func fusedLabels(for crop: UIImage) async -> [(text: String, confidence: Float)] {
        var scores: [String: Float] = [:]
        func add(_ raw: String, _ confidence: Float, weight: Float) {
            let text = VisionClassificationService.prettifyIdentifier(raw)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let key = text.lowercased().replacingOccurrences(of: " ", with: "_")
            guard text.count >= 3, !VisionClassificationService.isGenericIdentifier(key) else { return }
            scores[text] = max(scores[text] ?? 0, confidence * weight)
        }
        for l in await VisionClassificationService.classifyTop(crop, maxResults: 5, minConfidence: 0.16) {
            add(l.text, l.confidence, weight: 1.0)
        }
        for l in await ImageLabelingService.labelsForCroppedImage(crop, maxResults: 5) {
            add(l.text, l.confidence, weight: 0.9)
        }
        return scores.map { (text: $0.key, confidence: min($0.value, 0.99)) }
            .sorted { $0.confidence > $1.confidence }
            .prefix(3).map { $0 }
    }
```
> Note: `VisionClassificationService.prettifyIdentifier` and `isGenericIdentifier` are already public (confirmed). `ObjectDetectionService.detectObjects` and `ImageLabelingService.labelsForCroppedImage` are public and no-op on Simulator — that's fine.

- [ ] **Step 2: Build for Simulator.** Expected `** BUILD SUCCEEDED **`.

---

## Task 6: Verify detection reachability + final device build + on-device verification

**Files:** none required (read-only verification + a possible tiny routing fix).

- [ ] **Step 1: Confirm the path to V3SpaceScreen.** Read `V3/Screens/V3RoomScreen.swift` and `V3/Components/V3PlaceCard.swift`/`V3RoomTile.swift`. Confirm that tapping a photo-backed item inside a room pushes `Route.v3Space(spaceId:)` (which renders `V3SpaceScreen` with the "Find objects" button). If a photo item instead routes to `Route.imageDetail`, change that v3 navigation to push `Route.v3Space` for items that have a `filePath` (leave room items going to `Route.v3Room`). Build for Simulator after any change.

- [ ] **Step 2: Device build (restore ML Kit) + install + launch.**
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
Expected: `** BUILD SUCCEEDED **`, install + launch OK. (If the iPhone is locked/disconnected, report it — the build success is the key signal.)

- [ ] **Step 3: On-device verification (requires the user — open the "FMN v3" icon, NOT v4).** Confirm:
  1. Take/select a photo of a busy shelf → view it (room → tap the photo) → the **Find objects** button shows.
  2. Tap it → multiple objects (incl. smaller ones) get glowing outlines + reasonably specific labels.
  3. Tap one → **Add "<label>" ✦** → lands on "Mark a spot" with the crop box **on** and the box prefilled on that object.
  4. From a fresh capture, "Mark a spot" opens with **no crop box**; tapping **Mark the exact spot ✦** reveals it; the four corners drag smoothly with **no lag**; saving without enabling it stores no rectangle.

---

## Self-review

**Spec coverage:**
- Better detection (more/smaller, specific labels, outlines) → Task 5 (lower threshold + ML Kit merge + label fusion; masks already rendered). ✓
- Detection reachable/works in v3 → Task 6 Step 1 (verify/fix Room→Space path) + device build. ✓
- Opt-in cropping behind a button → Task 4 (`cropEnabled` default off, `v3-create-sub-crop-toggle`). ✓
- Working four-corner handles → Task 2 (`V3CropBox`, drag-start latch fixes jump). ✓
- No lag → Task 1 (downsample) + Task 4 (`.drawingGroup()`, downsampled `displayImage`). ✓
- Detection → create with prefilled box+name → Task 4 (Route extension + `confirmSelectedDetection` → `v3CreateSub` with `suggestedRect`/`suggestedTitle`). ✓
- v3-only / no v4 or shared edits → only `V3/*`, `Route.swift` (additive default args), and one additive repo method touched; no edits to `V4/*`, `Views/*`, `ML/*`. ✓

**Placeholder scan:** All code provided in full; commands have expected output. The two conditional notes (repo init fallback in Task 3; reachability fix in Task 6) are explicit decision branches, not placeholders.

**Type consistency:** `Route.v3CreateSub(parentId:tempPhotoPath:suggestedRect:suggestedTitle:)` matches the `destination(for:)` extraction and `V3CreateSubScreen.init`. `suggestedRect: Rectangle?`, `suggestedTitle: String?` consistent. `createSubSpace(name:tags:parentId:rectangleOnParent:)` matches the call in `save()`. `V3CropBox(palette:rect:size:)` matches its use. `fusedLabels(for:) -> [(text:String,confidence:Float)]` matches its callers. `V3ImageDownsampler.downsample(path:)`/`downsample(_:)` match their calls.
