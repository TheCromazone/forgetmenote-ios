import SwiftUI

/// V3 design system — port of theme.jsx (forget-me-not palette).
///
/// The v3 aesthetic is editorial-feel: warm cream paper background, deep
/// cornflower-blue accent, pollen-yellow micro-accent, Instrument Serif
/// headlines with italic emphasis on key words ("welcome *back*").
///
/// Three palette variants are supported (forget / forest / clay), matching
/// the JS prototype's TweaksPanel. The default is `.forget`.
enum V3Palette: String, CaseIterable {
    case forget, forest, clay

    var name: String {
        switch self {
        case .forget: return "Forget-me-not"
        case .forest: return "Forest"
        case .clay:   return "Clay"
        }
    }

    var accent: Color {
        switch self {
        case .forget: return Color(hex: 0x5B7FE0)
        case .forest: return Color(hex: 0x3F7D5E)
        case .clay:   return Color(hex: 0xC2543F)
        }
    }
    var accentSoft: Color {
        switch self {
        case .forget: return Color(hex: 0xA9BCF0)
        case .forest: return Color(hex: 0xA6C8B5)
        case .clay:   return Color(hex: 0xE8B5A8)
        }
    }
    var accentBg: Color {
        switch self {
        case .forget: return Color(hex: 0xE8EEFB)
        case .forest: return Color(hex: 0xE5EFE9)
        case .clay:   return Color(hex: 0xF8E8E2)
        }
    }
    var pollen: Color {
        switch self {
        case .forget: return Color(hex: 0xF5C76E)
        case .forest: return Color(hex: 0xE8B86A)
        case .clay:   return Color(hex: 0xF0C25A)
        }
    }
    var paper: Color {
        switch self {
        case .forget: return Color(hex: 0xF7F2E8)
        case .forest: return Color(hex: 0xF4F1EA)
        case .clay:   return Color(hex: 0xF8F2E8)
        }
    }
    var paperEdge: Color {
        switch self {
        case .forget: return Color(hex: 0xEFE7D6)
        case .forest: return Color(hex: 0xEAE5DA)
        case .clay:   return Color(hex: 0xF0E5D2)
        }
    }
    var ink: Color {
        switch self {
        case .forget: return Color(hex: 0x1A1D26)
        case .forest: return Color(hex: 0x1A1D1A)
        case .clay:   return Color(hex: 0x2A1A14)
        }
    }
    var ink2: Color {
        switch self {
        case .forget: return Color(hex: 0x5C5F6B)
        case .forest: return Color(hex: 0x555A55)
        case .clay:   return Color(hex: 0x5C4940)
        }
    }
    var ink3: Color {
        switch self {
        case .forget: return Color(hex: 0x9B9EA9)
        case .forest: return Color(hex: 0x959994)
        case .clay:   return Color(hex: 0x998779)
        }
    }
    var line: Color { ink.opacity(0.08) }
    var surface: Color { .white }
    var danger: Color {
        switch self {
        case .forget: return Color(hex: 0xD9594C)
        case .forest: return Color(hex: 0xC2543F)
        case .clay:   return Color(hex: 0xA6391E)
        }
    }

    /// Six room hues (deterministic by name). Mirrors theme.jsx `hues`.
    var hues: [V3Hue] {
        switch self {
        case .forget: return [
            V3Hue(bg: Color(hex: 0x5B7FE0), fg: .white,                    name: "sky"),
            V3Hue(bg: Color(hex: 0xE8B86A), fg: Color(hex: 0x3D2A0E),      name: "honey"),
            V3Hue(bg: Color(hex: 0xA89BC9), fg: .white,                    name: "mauve"),
            V3Hue(bg: Color(hex: 0x7FA88C), fg: .white,                    name: "sage"),
            V3Hue(bg: Color(hex: 0xE89A8E), fg: Color(hex: 0x5A2218),      name: "peach"),
            V3Hue(bg: Color(hex: 0xD4C5A3), fg: Color(hex: 0x3D2F12),      name: "wheat"),
        ]
        case .forest: return [
            V3Hue(bg: Color(hex: 0x3F7D5E), fg: .white,                    name: "forest"),
            V3Hue(bg: Color(hex: 0xA65A38), fg: .white,                    name: "rust"),
            V3Hue(bg: Color(hex: 0x7A8A4D), fg: .white,                    name: "moss"),
            V3Hue(bg: Color(hex: 0xC9A961), fg: Color(hex: 0x3D2A0E),      name: "mustard"),
            V3Hue(bg: Color(hex: 0x5C8088), fg: .white,                    name: "lake"),
            V3Hue(bg: Color(hex: 0xB89A7B), fg: Color(hex: 0x3D2F12),      name: "birch"),
        ]
        case .clay: return [
            V3Hue(bg: Color(hex: 0xC2543F), fg: .white,                    name: "clay"),
            V3Hue(bg: Color(hex: 0x6B7FAE), fg: .white,                    name: "denim"),
            V3Hue(bg: Color(hex: 0xD4A155), fg: Color(hex: 0x3D2A0E),      name: "ochre"),
            V3Hue(bg: Color(hex: 0x7A6B8C), fg: .white,                    name: "plum"),
            V3Hue(bg: Color(hex: 0x6B8C7A), fg: .white,                    name: "sage"),
            V3Hue(bg: Color(hex: 0xC9A88E), fg: Color(hex: 0x3D2F12),      name: "sand"),
        ]
        }
    }

    /// Deterministic hue picker. Same string always returns the same color
    /// across launches. Mirrors `hueFor(seed, palette)` from theme.jsx.
    func hue(for seed: String) -> V3Hue {
        var n: Int = 0
        for ch in seed.unicodeScalars {
            n = (n &* 31) &+ Int(ch.value)
        }
        return hues[abs(n) % hues.count]
    }

    /// Prefer a room's user-chosen color (stored on ImageItem) over the
    /// deterministic id-based hue. Falls back to the deterministic picker
    /// if the room has no stored color (e.g., seeded default rooms).
    func hue(for item: ImageItem) -> V3Hue {
        if let bgARGB = item.roomBackgroundColor,
           let fgARGB = item.roomTextColor {
            return V3Hue(
                bg: Color(argb: bgARGB),
                fg: Color(argb: fgARGB),
                name: "custom"
            )
        }
        return hue(for: item.id)
    }
}

struct V3Hue: Hashable {
    let bg: Color
    let fg: Color
    let name: String
}

/// Environment key so any view can read the current palette.
private struct V3PaletteKey: EnvironmentKey {
    static let defaultValue: V3Palette = .forget
}
extension EnvironmentValues {
    var v3Palette: V3Palette {
        get { self[V3PaletteKey.self] }
        set { self[V3PaletteKey.self] = newValue }
    }
}
