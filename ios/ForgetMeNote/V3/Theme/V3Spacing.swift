import SwiftUI

/// Spacing + corner-radius design tokens for v3. The screens grew a sprawl of
/// magic numbers (gutters of 16/18/22, radii from 8 to 32); these give a
/// single vocabulary to migrate toward. Values match the most common existing
/// usages so adoption is a drop-in rename, not a visual change.
enum V3Spacing {
    /// Screen side gutter — the canonical horizontal inset for content columns.
    static let gutter: CGFloat = 22
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
    /// Bottom clearance so content clears the tab bar + capture FAB.
    static let tabClearance: CGFloat = 110
}

enum V3Radius {
    static let chip: CGFloat = 10
    static let control: CGFloat = 14
    static let card: CGFloat = 16
    static let panel: CGFloat = 22
    static let hero: CGFloat = 26
    static let sheet: CGFloat = 24
}

/// Shared pressed-state feedback for tappable cards / circles / switcher
/// buttons: a quick scale + opacity dip on press. Pair with a `.selection`
/// haptic at the call site where appropriate.
struct V3PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == V3PressableButtonStyle {
    static var v3Pressable: V3PressableButtonStyle { V3PressableButtonStyle() }
}
