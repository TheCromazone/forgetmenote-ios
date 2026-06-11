import Foundation
import UIKit
import Vision

/// Apple Vision–based image classifier. Replaces ML Kit's ImageLabeler for
/// per-box specific labels. Vision's built-in `VNClassifyImageRequest` ships
/// with a ~1300-label set hierarchical taxonomy.
///
/// To get useful "what's in this photo" results out of it, we:
/// 1. Filter to observations meeting a precision floor (so the label is
///    trustworthy when it fires).
/// 2. Drop generic taxonomy ancestors ("indoor", "object", "scene", "place")
///    that are technically correct but useless.
/// 3. Prefer leaf-of-hierarchy labels (most specific).
/// 4. Pretty-print underscored identifiers.
///
/// Returns up to 3 candidate labels per call so the UI can show
/// "Bottle / Vase / Cup" rather than a single guess.
enum VisionClassificationService {

    /// Words that always describe a category/scene rather than an object.
    /// We strip these from the result list — they're noise for our
    /// "what specific thing is this?" use case.
    private static let genericLabels: Set<String> = [
        "indoor", "outdoor", "object", "scene", "place", "natural",
        "structure", "decoration", "material", "abstract", "background",
        "art", "graphic", "pattern", "texture", "indoor_scene",
        "outdoor_scene", "scenery", "still_life", "monochrome", "color",
        "horizontal", "vertical", "geometric", "shape", "single_object",
        "multiple_objects", "indoor_setting", "outdoor_setting",
        "natural_environment", "built_environment", "general",
    ]

    /// Single top label above floor. Returns nil if nothing meets quality bar.
    static func classify(_ image: UIImage, minConfidence: Float = 0.30) async -> (text: String, confidence: Float)? {
        let labels = await classifyTop(image, maxResults: 1, minConfidence: minConfidence)
        return labels.first
    }

    /// Top-N labels above floor. Used to surface multiple candidates per box
    /// (e.g. "Bottle / Vase / Cup") so the user can pick the right one.
    static func classifyTop(
        _ image: UIImage,
        maxResults: Int = 3,
        minConfidence: Float = 0.30
    ) async -> [(text: String, confidence: Float)] {
        guard let cg = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { req, err in
                if let err = err {
                    print("VisionClassificationService: request failed: \(err)")
                    continuation.resume(returning: [])
                    return
                }
                guard let observations = req.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                // Step 1: drop obviously generic / ancestor labels by identifier.
                let nonGeneric = observations.filter { obs in
                    !isGeneric(obs.identifier)
                }

                // Step 2: keep only observations meeting a meaningful precision
                // bar — when this label fires it's at least usually right.
                // 0.7 precision at 0.01 recall is a strong "trustworthy fire".
                let trustworthy = nonGeneric.filter {
                    $0.hasMinimumRecall(0.01, forPrecision: 0.7)
                }
                let pool = trustworthy.isEmpty ? nonGeneric : trustworthy

                // Step 3: dedupe by pretty-printed display text (the hierarchy
                // can return both "Persian Cat" and "Cat"; the leaf wins).
                var seen: Set<String> = []
                var picked: [(text: String, confidence: Float)] = []
                for obs in pool.sorted(by: { $0.confidence > $1.confidence }) {
                    let text = prettify(obs.identifier)
                    if seen.contains(text) { continue }
                    guard obs.confidence >= minConfidence else { continue }
                    seen.insert(text)
                    picked.append((text: text, confidence: obs.confidence))
                    if picked.count >= maxResults { break }
                }
                continuation.resume(returning: picked)
            }
            let handler = VNImageRequestHandler(cgImage: cg, orientation: cgOrientation(image), options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("VisionClassificationService: perform failed: \(error)")
                continuation.resume(returning: [])
            }
        }
    }

    static func isGenericIdentifier(_ identifier: String) -> Bool {
        isGeneric(identifier)
    }

    static func prettifyIdentifier(_ identifier: String) -> String {
        prettify(identifier)
    }

    /// True if the identifier is a top-level/ancestor category we want to drop.
    private static func isGeneric(_ identifier: String) -> Bool {
        let id = identifier.lowercased()
        if genericLabels.contains(id) { return true }
        // Anything containing these substrings is almost always too generic.
        let badSubstrings = ["scene", "background", "environment", "_general", "abstract"]
        return badSubstrings.contains { id.contains($0) }
    }

    /// VNClassifyImageRequest returns identifiers like "espresso_maker" or
    /// "domestic_cat". Make them presentable.
    private static func prettify(_ identifier: String) -> String {
        identifier
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
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
