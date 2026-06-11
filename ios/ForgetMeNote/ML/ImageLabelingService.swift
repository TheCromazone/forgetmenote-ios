import Foundation
import UIKit

#if !targetEnvironment(simulator)
import MLKitImageLabeling
import MLKitImageLabelingCommon
import MLKitVision
#endif

/// Port of `com.imageorganizer.app.utils.ImageLabelingUtils`.
///
/// Wraps Google ML Kit's iOS Image Labeling SDK with the default model.
/// Used for auto-titling captured photos in CreateChildScreen.
///
/// Same simulator caveat as ObjectDetectionService — returns nil/empty on Sim.
enum ImageLabelingService {

    /// Return the single highest-confidence label for the image, or nil if none.
    static func generateTitle(imagePath: String) async -> String? {
        let labels = await getTopLabels(imagePath: imagePath, maxResults: 1)
        return labels.first?.text
    }

    /// Return the top N labels with confidence scores. Matches Android
    /// `ImageLabelingUtils.getTopLabels`.
    static func getTopLabels(imagePath: String, maxResults: Int = 3) async -> [ImageLabel] {
        #if targetEnvironment(simulator)
        return []
        #else
        guard let image = UIImage(contentsOfFile: imagePath) else { return [] }
        return await labels(for: image, maxResults: maxResults)
        #endif
    }

    /// Run labeling on an in-memory UIImage (used for captured photos before
    /// they're written to disk).
    static func generateTitleFromImage(_ image: UIImage) async -> String? {
        #if targetEnvironment(simulator)
        return nil
        #else
        let results = await labels(for: image, maxResults: 1)
        return results.first?.text
        #endif
    }

    /// Used by `ObjectDetectionService.detectAndLabel` to get a specific
    /// label for a cropped sub-region (the bounding box of a detected object).
    static func labelsForCroppedImage(_ image: UIImage, maxResults: Int) async -> [ImageLabel] {
        #if targetEnvironment(simulator)
        return []
        #else
        return await labels(for: image, maxResults: maxResults)
        #endif
    }

    #if !targetEnvironment(simulator)
    private static func labels(for image: UIImage, maxResults: Int) async -> [ImageLabel] {
        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation

        let options = ImageLabelerOptions()
        let labeler = ImageLabeler.imageLabeler(options: options)

        do {
            let raw = try await labeler.results(in: visionImage)
            return raw.prefix(maxResults).map { label in
                ImageLabel(text: label.text, confidence: Float(label.confidence))
            }
        } catch {
            print("ImageLabelingService: labeling failed: \(error)")
            return []
        }
    }
    #endif
}
