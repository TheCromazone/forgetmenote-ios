import SwiftUI

/// 5-petal forget-me-not flower mark — port of `FlowerMark` from theme.jsx.
/// Used in:
///   - Welcome screen scatter (decorative)
///   - Home greeting stat row (small inline)
///   - Empty-search placeholder
///
/// Petals are ellipses positioned at 5 evenly-spaced angles, each rotated to
/// point outward from the center. A pollen dot + dimmer inner dot finish it.
struct FlowerMark: View {
    let size: CGFloat
    var color: Color = Color(hex: 0x5B7FE0)
    var pollen: Color = Color(hex: 0xF5C76E)

    var body: some View {
        Canvas { ctx, _ in
            let r = size / 2
            for i in 0..<5 {
                let angle = (Double(i) * 72 - 90) * .pi / 180
                let cx = r + CGFloat(cos(angle)) * size * 0.27
                let cy = r + CGFloat(sin(angle)) * size * 0.27
                let petalSize = CGSize(width: size * 0.42, height: size * 0.54)
                let rect = CGRect(
                    x: cx - petalSize.width / 2,
                    y: cy - petalSize.height / 2,
                    width: petalSize.width,
                    height: petalSize.height
                )
                let petalPath = Path(ellipseIn: rect)
                // Rotate around the petal's center to point outward.
                var transform = CGAffineTransform.identity
                transform = transform.translatedBy(x: cx, y: cy)
                transform = transform.rotated(by: CGFloat(Double(i) * 72 * .pi / 180))
                transform = transform.translatedBy(x: -cx, y: -cy)
                let rotated = petalPath.applying(transform)
                ctx.fill(rotated, with: .color(color))
            }
            // Pollen dot
            let pollenRect = CGRect(
                x: r - size * 0.13, y: r - size * 0.13,
                width: size * 0.26, height: size * 0.26
            )
            ctx.fill(Path(ellipseIn: pollenRect), with: .color(pollen))
            // Dimmer inner dot
            let innerRect = CGRect(
                x: r - size * 0.06, y: r - size * 0.06,
                width: size * 0.12, height: size * 0.12
            )
            ctx.fill(Path(ellipseIn: innerRect),
                     with: .color(color.opacity(0.4)))
        }
        .frame(width: size, height: size)
    }
}
