import SwiftUI

/// Freehand "trace an object" tool — drag your finger around the object and it
/// captures a closed outline (normalized points) bound to `trace`. The
/// companion to `V3CropBox`: where the crop box is a rectangle, this follows the
/// real shape. Its `boundingBox` feeds the same region/nesting pipeline, so a
/// traced object nests and crops exactly like a rectangle one.
struct V3TraceBox: View {
    let palette: V3Palette
    @Binding var trace: TracePath
    let size: CGSize

    @State private var live: [TracePoint] = []
    @State private var isDrawing = false

    var body: some View {
        let pts = isDrawing ? live : trace.points
        ZStack(alignment: .topLeading) {
            tracePath(pts, closed: !isDrawing)
                .fill(palette.accent.opacity(0.14))
            tracePath(pts, closed: !isDrawing)
                .stroke(palette.accent,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            if let first = pts.first {
                Circle()
                    .fill(.white)
                    .overlay(Circle().strokeBorder(palette.accent, lineWidth: 2))
                    .frame(width: 14, height: 14)
                    .position(x: CGFloat(first.x) * size.width, y: CGFloat(first.y) * size.height)
            }
            if pts.isEmpty {
                Text("Draw around the object ✦")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.black.opacity(0.45), in: Capsule())
                    .frame(width: size.width, height: size.height)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .contentShape(SwiftUI.Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if !isDrawing { isDrawing = true; live = []; V3Haptics.selection() }
                    let p = TracePoint(
                        x: Float(max(0, min(1, v.location.x / size.width))),
                        y: Float(max(0, min(1, v.location.y / size.height)))
                    )
                    if let last = live.last {
                        let dx = last.x - p.x, dy = last.y - p.y
                        if dx * dx + dy * dy > 0.0002 { live.append(p) }   // ~1.4% sample step
                    } else {
                        live.append(p)
                    }
                }
                .onEnded { _ in
                    isDrawing = false
                    if live.count >= 3 { trace = TracePath(points: live) }
                    live = []
                }
        )
        .accessibilityIdentifier("v3-tracebox")
    }

    private func tracePath(_ pts: [TracePoint], closed: Bool) -> Path {
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: point(first))
        for p in pts.dropFirst() { path.addLine(to: point(p)) }
        if closed { path.closeSubpath() }
        return path
    }

    private func point(_ p: TracePoint) -> CGPoint {
        CGPoint(x: CGFloat(p.x) * size.width, y: CGFloat(p.y) * size.height)
    }
}
