import SwiftUI

/// V3 chip — small pill used for tags. Port of `Chip` from screens-space.jsx.
/// Renders text with a `#` prefix if not already present, on a paper-edge
/// background.
struct V3Chip: View {
    let palette: V3Palette
    let text: String
    var onTap: (() -> Void)? = nil

    private var displayText: String {
        text.hasPrefix("#") ? text : "#" + text
    }

    var body: some View {
        let label = Text(displayText)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.ink)
            .tracking(-0.1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(palette.paperEdge, in: Capsule())

        if let onTap {
            Button(action: onTap) { label }
                .buttonStyle(.plain)
        } else {
            label
        }
    }
}
