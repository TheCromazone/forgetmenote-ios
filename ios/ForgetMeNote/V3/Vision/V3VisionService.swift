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

    /// Detect objects on the photo. Primary: bundled CoreML detector (works on
    /// device + Simulator). Outlines: Apple Vision instance masks (iOS 18+),
    /// matched to detector boxes by IoU. Labels refined by the Vision classifier.
    static func detect(imagePath: String) async -> [DetectedObjectInfo] {
        guard let original = workingImage(for: imagePath) else { return [] }

        // 1) CoreML detector boxes (COCO). BALANCED floor — low enough to still
        //    surface the distinct items on a shelf, high enough to suppress the
        //    speculative low-confidence boxes that read as noise.
        let coreml = await V3CoreMLDetector.detect(original, minConfidence: 0.18)

        // 2) Instance masks for shape-accurate outlines (iOS 18+ only).
        var masks: [(box: Rectangle, png: Data)] = []
        if #available(iOS 18.0, *) {
            masks = await foregroundMasks(original)
        }

        // 3) Objectness-saliency region proposals. The COCO detector has no
        //    class for things like a TV STAND, shelf, sideboard or random
        //    container, so saliency gives us extra candidate regions that the
        //    Vision/ML Kit classifier can then name. This is what lets us
        //    "detect everything on the stand AND the stand itself".
        let salient = await saliencyRegions(original)

        var out: [DetectedObjectInfo] = []

        // 3a) Each CoreML detection → refine label + attach an overlapping mask.
        for det in coreml {
            let crop = cropToNormalizedRect(original, rect: det.rect) ?? original
            var labels = await fusedLabels(for: crop)
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

        // 3b) Mask-only instances the detector missed (smaller floor → more).
        for m in masks {
            let covered = out.contains { V3DetectionGeometry.iou($0.boundingBox, m.box) > 0.4 }
            if covered { continue }
            guard m.box.width * m.box.height > 0.0035 else { continue }
            let crop = cropToNormalizedRect(original, rect: m.box) ?? original
            let labels = await fusedLabels(for: crop)
            guard let top = labels.first else { continue }
            out.append(DetectedObjectInfo(
                boundingBox: m.box, label: top.text, confidence: top.confidence,
                alternates: Array(labels.dropFirst().map(\.text)), maskPNGData: m.png))
        }

        // 3c) Salient regions neither pass covered → classify + add (with an
        //     overlapping mask if one exists, else a plain box).
        for box in salient {
            let area = box.width * box.height
            guard area > 0.006, area < 0.92 else { continue }   // skip specks + whole-frame
            let covered = out.contains { V3DetectionGeometry.iou($0.boundingBox, box) > 0.40 }
            if covered { continue }
            let crop = cropToNormalizedRect(original, rect: box) ?? original
            let labels = await fusedLabels(for: crop)
            guard let top = labels.first else { continue }
            out.append(DetectedObjectInfo(
                boundingBox: box, label: top.text, confidence: top.confidence,
                alternates: Array(labels.dropFirst().map(\.text)),
                maskPNGData: bestMask(for: box, in: masks)))
        }

        // Cap so the overlay stays readable even on busy photos.
        return Array(mergeOverlaps(out).prefix(14))
    }

    /// Objectness-based saliency region proposals → up to a handful of
    /// normalized boxes of "things" in the photo, including ones the COCO
    /// detector has no label for. Apple Vision; runs on device + Simulator.
    private static func saliencyRegions(_ image: UIImage) async -> [Rectangle] {
        guard let cg = image.cgImage else { return [] }
        let request = VNGenerateObjectnessBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cg,
                                            orientation: cgOrientation(image),
                                            options: [:])
        do { try handler.perform([request]) } catch { return [] }
        guard let obs = request.results?.first as? VNSaliencyImageObservation,
              let objects = obs.salientObjects else { return [] }
        return objects.map { o in
            let bb = o.boundingBox            // normalized, ORIGIN BOTTOM-LEFT
            return Rectangle(x: Float(bb.minX),
                             y: Float(1 - bb.maxY),   // flip to top-left origin
                             width: Float(bb.width),
                             height: Float(bb.height))
        }
    }

    /// Lightweight single-region classify used by tap-to-identify.
    static func classifyRegion(imagePath: String, around point: CGPoint, size: Float = 0.18) async -> String? {
        guard let original = workingImage(for: imagePath) else { return nil }
        let half = size / 2
        let r = Rectangle(
            x: max(0, Float(point.x) - half), y: max(0, Float(point.y) - half),
            width: size, height: size)
        let crop = cropToNormalizedRect(original, rect: r) ?? original
        return await fusedLabels(for: crop).first?.text
    }

    /// Auto-suggest a place name for the whole photo: classify the downsampled
    /// working image and return the single most prominent, non-generic label,
    /// prettified + capitalized for use as a place name. Returns nil if nothing
    /// confident. Cheap by design — whole-image classify, no full detection.
    /// On-device only; works in the Simulator (Apple Vision + cached decode).
    static func suggestName(imagePath: String) async -> String? {
        guard let working = workingImage(for: imagePath) else { return nil }
        let best = await fusedLabels(for: working).first
        guard let best, best.confidence >= 0.20 else { return nil }
        let name = best.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    // MARK: - Working-image cache

    /// Last decoded/downsampled working image, keyed by its source path. Both
    /// `detect` and `classifyRegion` re-decode the original bitmap on every
    /// call; caching the downsampled (~1024px) image lets repeated identify
    /// taps on the same photo reuse it instead of decoding each time.
    private static let cacheLock = NSLock()
    private static var cachedPath: String?
    private static var cachedImage: UIImage?

    /// Return a downsampled working image for `imagePath`, reusing the cached
    /// one when the path is unchanged. Invalidates whenever the path differs.
    private static func workingImage(for imagePath: String) -> UIImage? {
        cacheLock.lock()
        if cachedPath == imagePath, let image = cachedImage {
            cacheLock.unlock()
            return image
        }
        cacheLock.unlock()

        let image = V3ImageDownsampler.downsample(path: imagePath, maxPixelSize: 1024)
            ?? UIImage(contentsOfFile: imagePath)

        cacheLock.lock()
        cachedPath = imagePath
        cachedImage = image
        cacheLock.unlock()
        return image
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

    // MARK: - Helpers (self-contained so the v2 ML Kit service stays untouched)

    private static func mergeOverlaps(_ detections: [DetectedObjectInfo]) -> [DetectedObjectInfo] {
        detections
            .sorted { $0.confidence > $1.confidence }
            .reduce(into: [DetectedObjectInfo]()) { kept, candidate in
                guard !kept.contains(where: {
                    V3DetectionGeometry.iou($0.boundingBox, candidate.boundingBox) > 0.5
                }) else { return }
                kept.append(candidate)
            }
    }

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
