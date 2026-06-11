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
    /// Optional pre-decoded mask images keyed by detection id. When supplied the
    /// overlay reuses these instead of decoding PNG data per render. Any id not
    /// present here falls back to the internal lazy decode cache.
    let maskImages: [UUID: UIImage]

    /// Max number of masks that render with the expensive glow `.shadow`. Beyond
    /// this we keep the silhouette but drop the offscreen blur to protect perf.
    private let shadowedMaskCap = 8

    init(palette: V3Palette,
         detections: [DetectedObjectInfo],
         size: CGSize,
         selectedId: UUID?,
         maskImages: [UUID: UIImage] = [:],
         onSelect: @escaping (UUID) -> Void) {
        self.palette = palette
        self.detections = detections
        self.size = size
        self.selectedId = selectedId
        self.maskImages = maskImages
        self.onSelect = onSelect
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(detections.enumerated()), id: \.element.id) { index, det in
                let selected = det.id == selectedId
                let box = V3DetectionGeometry.displayRect(for: det.boundingBox, in: size)
                // Selected masks always keep their glow; others only within the cap.
                let glows = selected || index < shadowedMaskCap

                // Glowing silhouette from the full-image alpha mask. The mask is a
                // full-image alpha map, so we map it onto `size` with the IDENTICAL
                // normalized→size transform the boxes use (linear stretch to the
                // displayed frame, no aspect-fill crop) so mask, box and label all
                // share one coordinate space and stay aligned on any aspect ratio.
                if let maskImage = maskImage(for: det) {
                    Image(uiImage: maskImage)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: size.width, height: size.height)
                        .foregroundStyle(palette.accent)
                        .opacity(selectedId == nil ? 0.32 : (selected ? 0.6 : 0.12))
                        .shadow(color: glows ? palette.accent.opacity(selected ? 0.7 : 0.35)
                                              : .clear,
                                radius: glows ? (selected ? 14 : 6) : 0)
                        // Rasterize the silhouette + glow once instead of re-blurring
                        // the offscreen shadow every frame.
                        .drawingGroup()
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

    /// Resolve a detection's mask silhouette, preferring a caller-supplied
    /// pre-decoded image, then a lazily-populated per-id decode cache, so the PNG
    /// is decoded at most once rather than on every render/frame.
    private func maskImage(for det: DetectedObjectInfo) -> UIImage? {
        if let pre = maskImages[det.id] { return pre }
        if let cached = Self.cache.object(forKey: det.id.uuidString as NSString) {
            return cached
        }
        guard let data = det.maskPNGData, let image = UIImage(data: data) else { return nil }
        Self.cache.setObject(image, forKey: det.id.uuidString as NSString)
        return image
    }

    /// Process-wide decode cache keyed by detection id. Detection ids are fresh
    /// `UUID`s per detection run, so stale entries naturally fall out under the
    /// NSCache count limit rather than being keyed by content.
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 64
        return c
    }()
}
