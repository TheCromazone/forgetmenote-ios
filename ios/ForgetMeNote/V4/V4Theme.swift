import SwiftUI

enum V4 {
    static let void = Color(hex: 0x11110E)
    static let ink = Color(hex: 0xF4EEE2)
    static let ink2 = Color(hex: 0xD2C8B7)
    static let ink3 = Color(hex: 0x918C82)
    static let panel = Color(hex: 0x1A1A16)
    static let panel2 = Color(hex: 0x23241F)
    static let panel3 = Color(hex: 0x2D2D27)
    static let line = Color.white.opacity(0.10)
    static let blue = Color(hex: 0x86A9BE)
    static let cyan = Color(hex: 0x9FB8B1)
    static let pollen = Color(hex: 0xC8A45D)
    static let leaf = Color(hex: 0x8B9478)
    static let coral = Color(hex: 0xB77A5F)
    static let violet = Color(hex: 0x9E9588)
    static let walnut = Color(hex: 0x5A3B29)
    static let paper = Color(hex: 0xE7DDC9)

    static let roomHues: [(bg: Color, fg: Color, name: String)] = [
        (Color(hex: 0x556B78), Color(hex: 0xF4EEE2), "slate"),
        (Color(hex: 0x697158), Color(hex: 0xF5F0E5), "olive"),
        (Color(hex: 0x8B6F4E), Color(hex: 0xFFF5E3), "brass"),
        (Color(hex: 0x7A5848), Color(hex: 0xFFF1E8), "clay"),
        (Color(hex: 0x475C66), Color(hex: 0xF0F7F7), "denim"),
        (Color(hex: 0x5E6252), Color(hex: 0xF3F0DF), "sage")
    ]

    static func hue(for seed: String) -> (bg: Color, fg: Color, name: String) {
        var n = 17
        for scalar in seed.unicodeScalars {
            n = (n &* 33) &+ Int(scalar.value)
        }
        return roomHues[abs(n) % roomHues.count]
    }

    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static var background: some View {
        ZStack {
            void
            Image("V4BackgroundSurface")
                .resizable()
                .scaledToFill()
                .opacity(0.34)
                .saturation(0.82)
                .contrast(0.92)
            RadialGradient(
                colors: [Color(hex: 0x283531).opacity(0.58), .clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 420
            )
            RadialGradient(
                colors: [walnut.opacity(0.22), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 380
            )
            LinearGradient(
                colors: [Color(hex: 0x171814).opacity(0.82), Color(hex: 0x11110E).opacity(0.78), Color(hex: 0x14130F).opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct V4SmallCaps: ViewModifier {
    var color: Color = V4.ink3

    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .bold))
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(color)
    }
}

extension View {
    func v4SmallCaps(_ color: Color = V4.ink3) -> some View {
        modifier(V4SmallCaps(color: color))
    }
}
