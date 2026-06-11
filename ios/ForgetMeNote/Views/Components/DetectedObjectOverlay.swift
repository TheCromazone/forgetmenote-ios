import SwiftUI

/// Draws green dashed bounding boxes with labels over an image for the
/// "Detect Objects" feature on ImageDetailScreen. Mirrors Android FR-IO-001/002.
///
/// Tapping a detected object calls `onTap` with that object's info — wired by
/// ImageDetailScreen to navigate into CreateChildScreen with the detected
/// rectangle + label as the suggested title.
struct DetectedObjectOverlay: View {
    let image: UIImage
    let detections: [DetectedObjectInfo]
    var selectedDetection: DetectedObjectInfo?
    var onSelect: (DetectedObjectInfo) -> Void = { _ in }
    var onCreate: (DetectedObjectInfo) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let frame = aspectFitFrame(imageSize: image.size, in: geo.size)
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)

                ForEach(Array(detections.enumerated()), id: \.offset) { _, det in
                    if let maskImage = maskImage(for: det) {
                        let isSelected = det.id == selectedDetection?.id
                        Color(hex: isSelected ? 0xE7DDC9 : 0xA9BBA8)
                            .opacity(isSelected ? 0.32 : 0.18)
                            .frame(width: frame.width, height: frame.height)
                            .mask(
                                Image(uiImage: maskImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: frame.width, height: frame.height)
                            )
                            .position(x: frame.midX, y: frame.midY)
                            .shadow(color: Color(hex: isSelected ? 0xC8A45D : 0xE7DDC9).opacity(isSelected ? 0.82 : 0.38),
                                    radius: isSelected ? 3 : 1)
                            .allowsHitTesting(false)
                    }
                }

                Canvas { ctx, _ in
                    for detection in detections {
                        let r = denormalize(detection.boundingBox, in: frame)
                        let isSelected = detection.id == selectedDetection?.id
                        if detection.maskPNGData == nil {
                            let path = Path(roundedRect: r, cornerSize: CGSize(width: 6, height: 6))
                            ctx.stroke(path,
                                       with: .color(isSelected ? Color(hex: 0xE7DDC9) : Color(hex: 0xA9BBA8)),
                                       style: StrokeStyle(lineWidth: isSelected ? 4 : 2.5,
                                                          dash: isSelected ? [] : [7, 5]))
                        }

                        var underline = Path()
                        let inset = max(6, r.width * 0.08)
                        underline.move(to: CGPoint(x: r.minX + inset, y: r.maxY + 5))
                        underline.addLine(to: CGPoint(x: r.maxX - inset, y: r.maxY + 5))
                        ctx.stroke(
                            underline,
                            with: .color(isSelected ? Color(hex: 0xC8A45D) : Color(hex: 0xE7DDC9).opacity(0.62)),
                            style: StrokeStyle(lineWidth: isSelected ? 5 : 3, lineCap: .round)
                        )
                    }
                }
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .allowsHitTesting(false)

                // SwiftUI label chips per detection — supports multi-line
                // alternate labels and respects accessibility text sizing.
                ForEach(Array(detections.enumerated()), id: \.offset) { _, det in
                    let r = denormalize(det.boundingBox, in: frame)
                    let isSelected = det.id == selectedDetection?.id
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(det.label) · \(Int(det.confidence * 100))%")
                            .font(.caption2.bold())
                            .foregroundStyle(isSelected ? Color(hex: 0x171814) : .white)
                        if !det.alternates.isEmpty {
                            Text("or " + det.alternates.joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(isSelected ? Color(hex: 0x171814).opacity(0.72) : .white.opacity(0.85))
                        }
                        if isSelected {
                            Text("Tap again to save as sub-space")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color(hex: 0x171814).opacity(0.76))
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? Color(hex: 0xE7DDC9).opacity(0.96) : Color(hex: 0x3F4A3D).opacity(0.88))
                    )
                    .position(x: min(max(r.minX + 70, 74), frame.maxX - 74), y: max(r.minY + 18, frame.minY + 18))
                    .allowsHitTesting(false)
                }

                // Tap targets: one Color.clear per detection, sized to the
                // bounding box. We layer these over the Canvas so onTap fires.
                ForEach(Array(detections.enumerated()), id: \.offset) { _, det in
                    let r = denormalize(det.boundingBox, in: frame)
                    Color.clear
                        .contentShape(SwiftUI.Rectangle())
                        .frame(width: r.width, height: r.height)
                        .position(x: r.midX, y: r.midY)
                        .onTapGesture(count: 2) { onCreate(det) }
                        .onTapGesture { onSelect(det) }
                }
            }
        }
    }

    private func denormalize(_ r: Rectangle, in frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX + CGFloat(r.x) * frame.width,
            y: frame.minY + CGFloat(r.y) * frame.height,
            width: CGFloat(r.width) * frame.width,
            height: CGFloat(r.height) * frame.height
        )
    }

    private func maskImage(for detection: DetectedObjectInfo) -> UIImage? {
        guard let data = detection.maskPNGData else { return nil }
        return UIImage(data: data)
    }

    private func aspectFitFrame(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let scale = min(containerSize.width / imageSize.width,
                        containerSize.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(x: (containerSize.width - w) / 2,
                      y: (containerSize.height - h) / 2,
                      width: w, height: h)
    }
}
