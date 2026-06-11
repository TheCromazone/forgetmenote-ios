import Foundation
import UIKit
import Vision
import CoreImage

#if !targetEnvironment(simulator)
import MLKitObjectDetection
import MLKitVision
import MLKitObjectDetectionCommon
#endif

/// Port of `com.imageorganizer.app.utils.ObjectDetectionUtils`.
///
/// Wraps Google ML Kit's iOS Object Detection SDK with the same API shape as
/// the Android side: returns `DetectedObjectInfo` with normalized 0..1
/// bounding boxes and confidence-scored labels.
///
/// Detector mode: SINGLE_IMAGE_MODE, multipleObjects = true, classification = true.
/// Matches Android `ObjectDetectorOptions.SINGLE_IMAGE_MODE` + `enableMultipleObjects()`
/// + `enableClassification()`.
///
/// ML Kit ships device-only on Apple Silicon (no arm64 Simulator slice). On
/// Simulator the service returns an empty result so the rest of the app still
/// compiles and runs — real verification must happen on a physical iPhone.
enum ObjectDetectionService {

    /// Detect objects across the whole image, or within a given normalized area.
    /// Returns a list of detected objects with normalized 0..1 bounding boxes
    /// expressed in the FULL image's coordinate space.
    static func detectObjects(
        imagePath: String,
        area: Rectangle? = nil
    ) async -> [DetectedObjectInfo] {
        #if targetEnvironment(simulator)
        // ML Kit can't link on arm64-Simulator. Return empty so UI still works.
        return []
        #else
        guard let original = UIImage(contentsOfFile: imagePath) else { return [] }

        // If area is specified, crop the bitmap first and remember the offset/scale.
        let (workingImage, areaOffset): (UIImage, Rectangle?) = {
            guard let area else { return (original, nil) }
            let cropped = cropToArea(original, area: area) ?? original
            return (cropped, area)
        }()

        let visionImage = VisionImage(image: workingImage)
        visionImage.orientation = workingImage.imageOrientation

        let options = ObjectDetectorOptions()
        options.detectorMode = .singleImage
        options.shouldEnableMultipleObjects = true
        options.shouldEnableClassification = true
        let detector = ObjectDetector.objectDetector(options: options)

        let raw: [Object]
        do {
            raw = try await detector.results(in: visionImage)
        } catch {
            print("ObjectDetectionService: detection failed: \(error)")
            return []
        }

        let imageW = workingImage.size.width
        let imageH = workingImage.size.height

        let detections: [DetectedObjectInfo] = raw.enumerated().compactMap { idx, obj in
            guard imageW > 0, imageH > 0 else { return nil }
            let box = obj.frame
            let localRect = Rectangle(
                x: Float(box.origin.x / imageW),
                y: Float(box.origin.y / imageH),
                width: Float(box.size.width / imageW),
                height: Float(box.size.height / imageH)
            )
            let mappedRect: Rectangle
            if let areaOffset {
                // Re-map cropped-space rectangle back into full-image space.
                mappedRect = Rectangle(
                    x: areaOffset.x + localRect.x * areaOffset.width,
                    y: areaOffset.y + localRect.y * areaOffset.height,
                    width: localRect.width * areaOffset.width,
                    height: localRect.height * areaOffset.height
                )
            } else {
                mappedRect = localRect
            }

            let topLabel = obj.labels.max(by: { $0.confidence < $1.confidence })
            let label = topLabel?.text ?? "Object \(idx + 1)"
            let confidence = topLabel?.confidence ?? 0.0

            return DetectedObjectInfo(
                boundingBox: mappedRect,
                label: label,
                confidence: Float(confidence)
            )
        }
        return detections
        #endif
    }

    // MARK: - Enrichment

    /// Run the default object detector THEN classify each detected box with
    /// Apple Vision's `VNClassifyImageRequest`, keeping the top-3 candidates
    /// so the UI can show "Bottle / Vase / Cup" rather than a single guess.
    ///
    /// Boxes whose Vision classifier returns nothing trustworthy are dropped
    /// — better to show fewer accurate labels than a wall of "Object".
    static func detectAndLabel(
        imagePath: String,
        area: Rectangle? = nil
    ) async -> [DetectedObjectInfo] {
        guard let original = UIImage(contentsOfFile: imagePath) else {
            return await detectObjects(imagePath: imagePath, area: area)
        }

        #if targetEnvironment(simulator)
        if area == nil {
            let v3Detections = await V3VisionService.detect(imagePath: imagePath)
            if !v3Detections.isEmpty { return v3Detections }
        }
        return await wholeImageFallback(original)
        #else
        let raw = await detectObjects(imagePath: imagePath, area: area)
        var enriched = await enrich(raw, in: original)

        if area == nil, #available(iOS 18.0, *) {
            let masked = await detectForegroundInstances(imagePath: imagePath)
            for candidate in masked where !enriched.contains(where: { iou($0.boundingBox, candidate.boundingBox) > 0.46 }) {
                enriched.append(candidate)
            }
        }

        let merged = mergeOverlaps(enriched)
        if !merged.isEmpty { return Array(merged.prefix(18)) }
        return await wholeImageFallback(original)
        #endif
    }

    private static func enrich(_ raw: [DetectedObjectInfo], in original: UIImage) async -> [DetectedObjectInfo] {
        var enriched: [DetectedObjectInfo] = []
        enriched.reserveCapacity(raw.count)
        for det in raw {
            let labels = await hybridLabels(
                for: original,
                normalizedRect: det.boundingBox,
                detectorLabel: det.label,
                detectorConfidence: det.confidence
            )
            if let top = labels.first {
                let alternates = Array(labels.dropFirst().map(\.text))
                enriched.append(DetectedObjectInfo(
                    boundingBox: det.boundingBox,
                    label: top.text,
                    confidence: max(det.confidence, top.confidence),
                    alternates: alternates,
                    maskPNGData: det.maskPNGData
                ))
            } else {
                let label = isUsefulLabel(det.label) ? displayLabel(det.label) : "Item"
                enriched.append(DetectedObjectInfo(
                    boundingBox: det.boundingBox,
                    label: label,
                    confidence: max(det.confidence, 0.35),
                    alternates: [],
                    maskPNGData: det.maskPNGData
                ))
            }
        }
        return enriched
    }

    private static func wholeImageFallback(_ original: UIImage) async -> [DetectedObjectInfo] {
        let labels = await VisionClassificationService.classifyTop(original, maxResults: 3)
        guard let top = labels.first else { return [] }
        let alternates = Array(labels.dropFirst().map(\.text))
        return [DetectedObjectInfo(
            boundingBox: Rectangle(x: 0.05, y: 0.05, width: 0.9, height: 0.9),
            label: top.text,
            confidence: top.confidence,
            alternates: alternates
        )]
    }

    @available(iOS 18.0, *)
    private static func detectForegroundInstances(imagePath: String) async -> [DetectedObjectInfo] {
        guard let original = UIImage(contentsOfFile: imagePath), let cg = original.cgImage else { return [] }

        let handler = Vision.ImageRequestHandler(cg, orientation: cgOrientation(original))
        let request = Vision.GenerateForegroundInstanceMaskRequest()
        let observation: Vision.InstanceMaskObservation?
        do {
            observation = try await handler.perform(request)
        } catch {
            print("ObjectDetectionService: foreground mask failed: \(error)")
            return []
        }

        guard let observation else { return [] }
        var detections: [DetectedObjectInfo] = []

        for instance in observation.allInstances {
            let instances = IndexSet(integer: instance)
            let maskBuffer: CVPixelBuffer
            do {
                maskBuffer = try observation.generateScaledMask(for: instances, scaledToImageFrom: handler)
            } catch {
                continue
            }
            guard let mask = alphaMaskAndBounds(from: maskBuffer) else { continue }
            let area = mask.boundingBox.width * mask.boundingBox.height
            guard area > 0.012 else { continue }

            let cropped: UIImage
            if let maskedBuffer = try? observation.generateMaskedImage(
                for: instances,
                imageFrom: handler,
                croppedToInstancesExtent: true
            ), let maskedImage = image(from: maskedBuffer) {
                cropped = maskedImage
            } else {
                cropped = cropToNormalizedRect(original, rect: mask.boundingBox) ?? original
            }

            let labels = await labels(for: cropped, detectorLabel: "Item", detectorConfidence: 0.35)
            guard let top = labels.first else { continue }
            guard top.confidence >= 0.24 else { continue }
            detections.append(DetectedObjectInfo(
                boundingBox: mask.boundingBox,
                label: top.text,
                confidence: top.confidence,
                alternates: Array(labels.dropFirst().map(\.text)),
                maskPNGData: mask.pngData
            ))
        }

        return mergeOverlaps(detections)
    }

    /// Crop the source image to the given normalized rect, then merge labels
    /// from Apple's Vision classifier, ML Kit image labeling, and ML Kit object
    /// classification. The expanded crop gives classifiers more visual context
    /// around small objects without drifting too far from the tapped box.
    private static func visionLabels(
        for image: UIImage,
        normalizedRect r: Rectangle
    ) async -> [(text: String, confidence: Float)] {
        guard let cropped = cropToNormalizedRect(image, rect: r) else { return [] }
        return await VisionClassificationService.classifyTop(cropped, maxResults: 3)
    }

    private static func hybridLabels(
        for image: UIImage,
        normalizedRect r: Rectangle,
        detectorLabel: String,
        detectorConfidence: Float
    ) async -> [(text: String, confidence: Float)] {
        let expanded = expand(r, by: 0.08)
        guard let cropped = cropToNormalizedRect(image, rect: expanded) else { return [] }
        return await labels(for: cropped, detectorLabel: detectorLabel, detectorConfidence: detectorConfidence)
    }

    private static func labels(
        for cropped: UIImage,
        detectorLabel: String,
        detectorConfidence: Float
    ) async -> [(text: String, confidence: Float)] {
        var scores: [String: Float] = [:]
        func add(_ raw: String, confidence: Float, weight: Float = 1) {
            let text = displayLabel(raw)
            guard isUsefulLabel(text) else { return }
            scores[text] = max(scores[text] ?? 0, confidence * weight)
        }

        let vision = await VisionClassificationService.classifyTop(
            cropped,
            maxResults: 5,
            minConfidence: 0.16
        )
        for label in vision {
            add(label.text, confidence: label.confidence, weight: 1.0)
        }

        let mlKit = await ImageLabelingService.labelsForCroppedImage(cropped, maxResults: 5)
        for label in mlKit {
            add(label.text, confidence: label.confidence, weight: 0.9)
        }

        if detectorLabel != "Item" {
            add(detectorLabel, confidence: detectorConfidence, weight: 0.68)
        }

        return scores
            .map { (text: $0.key, confidence: min($0.value, 0.99)) }
            .sorted { $0.confidence > $1.confidence }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Helpers

    private static func cropToArea(_ image: UIImage, area: Rectangle) -> UIImage? {
        cropToNormalizedRect(image, rect: area)
    }

    private static func cropToNormalizedRect(_ image: UIImage, rect r: Rectangle) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let x = max(0, CGFloat(r.x) * w)
        let y = max(0, CGFloat(r.y) * h)
        let cropRect = CGRect(
            x: x,
            y: y,
            width: min(w - x, CGFloat(r.width) * w),
            height: min(h - y, CGFloat(r.height) * h)
        )
        guard cropRect.width >= 1, cropRect.height >= 1 else { return nil }
        guard let cropped = cg.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    private static func expand(_ rect: Rectangle, by amount: Float) -> Rectangle {
        let dx = rect.width * amount
        let dy = rect.height * amount
        let x = max(0, rect.x - dx)
        let y = max(0, rect.y - dy)
        let maxX = min(1, rect.x + rect.width + dx)
        let maxY = min(1, rect.y + rect.height + dy)
        return Rectangle(x: x, y: y, width: maxX - x, height: maxY - y)
    }

    private static func displayLabel(_ raw: String) -> String {
        VisionClassificationService.prettifyIdentifier(raw)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isUsefulLabel(_ label: String) -> Bool {
        let normalized = label
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
        let blocked: Set<String> = [
            "object", "objects", "home_goods", "goods", "product", "material",
            "indoor", "room", "furniture", "household", "decoration", "pattern",
            "textile", "tool", "container", "rectangle", "accessory"
        ]
        if blocked.contains(normalized) { return false }
        if normalized.hasPrefix("object_") { return false }
        if VisionClassificationService.isGenericIdentifier(normalized) { return false }
        return label.count >= 3
    }

    private static func mergeOverlaps(_ detections: [DetectedObjectInfo]) -> [DetectedObjectInfo] {
        detections
            .sorted { $0.confidence > $1.confidence }
            .reduce(into: [DetectedObjectInfo]()) { kept, candidate in
                guard !kept.contains(where: { iou($0.boundingBox, candidate.boundingBox) > 0.74 }) else { return }
                kept.append(candidate)
            }
    }

    private static func iou(_ a: Rectangle, _ b: Rectangle) -> Float {
        let ax2 = a.x + a.width, ay2 = a.y + a.height
        let bx2 = b.x + b.width, by2 = b.y + b.height
        let ix = max(0, min(ax2, bx2) - max(a.x, b.x))
        let iy = max(0, min(ay2, by2) - max(a.y, b.y))
        let intersection = ix * iy
        let union = a.width * a.height + b.width * b.height - intersection
        guard union > 0 else { return 0 }
        return intersection / union
    }

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
                rgba[i] = 255
                rgba[i + 1] = 255
                rgba[i + 2] = 255
                rgba[i + 3] = alpha
                if alpha > 24 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let cg = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ),
              let png = UIImage(cgImage: cg).pngData() else {
            return nil
        }

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
