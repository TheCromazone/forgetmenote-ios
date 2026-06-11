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
