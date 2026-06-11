import Foundation

/// Mirrors `com.imageorganizer.app.utils.DetectedObjectInfo`.
/// Produced by `ObjectDetectionService` (ML Kit iOS wrapper).
struct DetectedObjectInfo: Hashable, Identifiable, Sendable {
    let id = UUID()
    let boundingBox: Rectangle   // normalized 0..1, in the FULL image's coordinate space
    let label: String
    let confidence: Float
    /// Alternate candidate labels (top-3) so the UI can show
    /// "Bottle / Vase / Cup" rather than just the top guess. Excludes `label`.
    var alternates: [String] = []
    /// Optional full-image alpha mask for shape-accurate overlays. When present,
    /// the UI can draw a translucent object silhouette instead of only a box.
    var maskPNGData: Data? = nil
}

/// Mirrors the Android `Pair<String, Float>` returned by `ImageLabelingUtils.getTopLabels`.
struct ImageLabel: Hashable, Sendable {
    let text: String
    let confidence: Float
}
