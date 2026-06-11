import SwiftUI

/// Capture button styled as a liquid-glass circle so it reads as a sibling of
/// the bottom glass tab bar. ~56pt to match the bar's height; accent-tinted
/// camera icon. Tapping presents the `V3CaptureSheet`.
struct V3CaptureFAB: View {
    let palette: V3Palette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 56, height: 56)
                .background(glass)
                .overlay(Circle().stroke(.white.opacity(0.45), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("v3-capture-fab")
        .accessibilityLabel("Capture new memory")
    }

    @ViewBuilder private var glass: some View {
        if #available(iOS 26.0, *) {
            Circle()
                .fill(.regularMaterial)
                .glassEffect(.regular.tint(palette.accentSoft), in: .circle)
        } else {
            Circle().fill(.regularMaterial)
        }
    }
}
