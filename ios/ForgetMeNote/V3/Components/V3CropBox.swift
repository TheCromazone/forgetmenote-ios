import SwiftUI

/// Reusable crop rectangle that fills the whole photo area and owns ONE unified
/// gesture (mirrors the Android `InteractiveRectangleSelector`):
///   • drag a corner handle → resize that corner
///   • drag inside the box   → move it
///   • drag on empty space   → draw a brand-new box
///   • pinch                 → expand / contract around the center
///
/// Operates in normalized (0..1) coords bound to `rect`. Because it spans the
/// full area with its own `contentShape`, it must be the TOP layer of the photo
/// ZStack — and the photo must NOT sit inside a ScrollView, or the scroll steals
/// the vertical drags (that was the "resize doesn't work" bug).
struct V3CropBox: View {
    let palette: V3Palette
    @Binding var rect: Rectangle
    let size: CGSize

    private let minSize: Float = 0.06
    private let cornerHitRadius: CGFloat = 30   // generous grab zone, in points

    enum Corner: CaseIterable { case tl, tr, bl, br }
    private enum Mode: Equatable { case resize(Corner), move, create }

    @State private var mode: Mode?
    @State private var base: Rectangle?          // rect latched at gesture start
    @State private var pinchBase: Rectangle?

    var body: some View {
        let w = size.width, h = size.height
        let rx = CGFloat(rect.x) * w, ry = CGFloat(rect.y) * h
        let rw = CGFloat(rect.width) * w, rh = CGFloat(rect.height) * h

        ZStack(alignment: .topLeading) {
            // The bright selection frame.
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(palette.accent, lineWidth: 2.5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.accent.opacity(0.08))
                )
                .frame(width: rw, height: rh)
                .offset(x: rx, y: ry)

            // Rule-of-thirds guides while actively dragging (nice polish, cheap).
            if mode != nil {
                thirds(rx: rx, ry: ry, rw: rw, rh: rh)
            }

            // Four corner handles (visual only — hit-testing is the unified
            // gesture below, so they can't fight each other).
            handle(at: CGPoint(x: rx, y: ry))
            handle(at: CGPoint(x: rx + rw, y: ry))
            handle(at: CGPoint(x: rx, y: ry + rh))
            handle(at: CGPoint(x: rx + rw, y: ry + rh))
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .contentShape(SwiftUI.Rectangle())
        .gesture(dragGesture(w: w, h: h))
        .simultaneousGesture(pinchGesture)
        .accessibilityIdentifier("v3-cropbox")
    }

    // MARK: - Visuals

    private func handle(at p: CGPoint) -> some View {
        Circle()
            .fill(.white)
            .overlay(Circle().strokeBorder(palette.accent, lineWidth: 2.5))
            .frame(width: 22, height: 22)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .position(x: p.x, y: p.y)
            .allowsHitTesting(false)
    }

    private func thirds(rx: CGFloat, ry: CGFloat, rw: CGFloat, rh: CGFloat) -> some View {
        ZStack {
            ForEach(1..<3) { i in
                let f = CGFloat(i) / 3
                Path { p in
                    p.move(to: CGPoint(x: rx + rw * f, y: ry))
                    p.addLine(to: CGPoint(x: rx + rw * f, y: ry + rh))
                }
                .stroke(.white.opacity(0.55), lineWidth: 0.75)
                Path { p in
                    p.move(to: CGPoint(x: rx, y: ry + rh * f))
                    p.addLine(to: CGPoint(x: rx + rw, y: ry + rh * f))
                }
                .stroke(.white.opacity(0.55), lineWidth: 0.75)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Unified drag (resize / move / create)

    private func dragGesture(w: CGFloat, h: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                if mode == nil {
                    base = rect
                    mode = detectMode(at: v.startLocation, w: w, h: h)
                    V3Haptics.selection()
                }
                guard let base, let mode else { return }
                let dx = Float(v.translation.width / w)
                let dy = Float(v.translation.height / h)
                switch mode {
                case .move:
                    rect = moved(base, dx: dx, dy: dy)
                case .resize(let corner):
                    rect = resized(base, corner: corner, dx: dx, dy: dy)
                case .create:
                    let sx = Float(v.startLocation.x / w)
                    let sy = Float(v.startLocation.y / h)
                    let cx = Float(v.location.x / w)
                    let cy = Float(v.location.y / h)
                    rect = rectBetween(sx, sy, cx, cy)
                }
            }
            .onEnded { _ in mode = nil; base = nil }
    }

    private func detectMode(at p: CGPoint, w: CGFloat, h: CGFloat) -> Mode {
        let rx = CGFloat(rect.x) * w, ry = CGFloat(rect.y) * h
        let rw = CGFloat(rect.width) * w, rh = CGFloat(rect.height) * h
        let corners: [(Corner, CGPoint)] = [
            (.tl, CGPoint(x: rx, y: ry)),
            (.tr, CGPoint(x: rx + rw, y: ry)),
            (.bl, CGPoint(x: rx, y: ry + rh)),
            (.br, CGPoint(x: rx + rw, y: ry + rh)),
        ]
        if let near = corners.min(by: { dist(p, $0.1) < dist(p, $1.1) }),
           dist(p, near.1) <= cornerHitRadius {
            return .resize(near.0)
        }
        let inside = p.x >= rx && p.x <= rx + rw && p.y >= ry && p.y <= ry + rh
        return inside ? .move : .create
    }

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func moved(_ b: Rectangle, dx: Float, dy: Float) -> Rectangle {
        let nx = max(0, min(1 - b.width, b.x + dx))
        let ny = max(0, min(1 - b.height, b.y + dy))
        return Rectangle(x: nx, y: ny, width: b.width, height: b.height)
    }

    private func resized(_ b: Rectangle, corner: Corner, dx: Float, dy: Float) -> Rectangle {
        var r = b
        let isLeft = corner == .tl || corner == .bl
        let isTop = corner == .tl || corner == .tr
        if isLeft {
            let nx = max(0, min(b.x + b.width - minSize, b.x + dx))
            r.x = nx; r.width = b.width - (nx - b.x)
        } else {
            r.width = max(minSize, min(1 - b.x, b.width + dx))
        }
        if isTop {
            let ny = max(0, min(b.y + b.height - minSize, b.y + dy))
            r.y = ny; r.height = b.height - (ny - b.y)
        } else {
            r.height = max(minSize, min(1 - b.y, b.height + dy))
        }
        return r
    }

    private func rectBetween(_ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float) -> Rectangle {
        let x = max(0, min(x1, x2)), y = max(0, min(y1, y2))
        let mx = min(1, max(x1, x2)), my = min(1, max(y1, y2))
        return Rectangle(x: x, y: y,
                         width: max(minSize, mx - x),
                         height: max(minSize, my - y))
    }

    // MARK: - Pinch (expand / contract around center)

    private var pinchGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { v in
                if pinchBase == nil { pinchBase = rect }
                guard let b = pinchBase else { return }
                let s = Float(v.magnification)
                let cx = b.x + b.width / 2, cy = b.y + b.height / 2
                let nw = min(1, max(minSize, b.width * s))
                let nh = min(1, max(minSize, b.height * s))
                let nx = max(0, min(1 - nw, cx - nw / 2))
                let ny = max(0, min(1 - nh, cy - nh / 2))
                rect = Rectangle(x: nx, y: ny, width: nw, height: nh)
            }
            .onEnded { _ in pinchBase = nil }
    }
}
