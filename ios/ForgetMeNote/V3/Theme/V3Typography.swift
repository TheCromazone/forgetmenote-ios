import SwiftUI

/// V3 typography helpers. The design uses Instrument Serif for big editorial
/// headlines with italic emphasis on accent words, and the system font for
/// body. Instrument Serif is an open-source Google Font — we use the iOS
/// fallback chain "Instrument Serif" → "Source Serif Pro" → Georgia until
/// the font is actually bundled in the app target.
enum V3Font {
    /// Big serif headline ("Hi Sam, welcome back.")
    /// Routes through `relativeTo:` so it scales with Dynamic Type. Font.custom
    /// falls back to the system font when "Instrument Serif" isn't bundled.
    static func headline(_ size: CGFloat = 34, italic: Bool = false) -> Font {
        let name = italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular"
        return Font.custom(name, size: size, relativeTo: .title)
    }

    /// Display-size serif ("Remember where things live.")
    /// Routes through `relativeTo:` so it scales with Dynamic Type. Font.custom
    /// falls back to the system font when "Instrument Serif" isn't bundled.
    static func display(_ size: CGFloat = 48, italic: Bool = false) -> Font {
        let name = italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular"
        return Font.custom(name, size: size, relativeTo: .largeTitle)
    }
}

/// Convenience modifiers for the recurring "GOOD EVENING" small caps label.
struct V3SmallCaps: ViewModifier {
    let color: Color
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .semibold))
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}
extension View {
    func v3SmallCaps(_ color: Color) -> some View {
        modifier(V3SmallCaps(color: color))
    }
}
