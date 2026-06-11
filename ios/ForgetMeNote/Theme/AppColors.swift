import SwiftUI

/// Color tokens mirroring `app/src/main/java/com/imageorganizer/app/ui/theme/Color.kt`.
///
/// The Android app uses Compose Material 3 with dynamic color on Android 12+,
/// falling back to a fixed Material 3 baseline (purple/grey/pink). iOS does not
/// have dynamic color from wallpaper, so we use the fixed baseline always.
enum AppColors {
    // Material 3 baseline — Light scheme
    static let purple40     = Color(hex: 0x6650A4)
    static let purpleGrey40 = Color(hex: 0x625B71)
    static let pink40       = Color(hex: 0x7D5260)

    // Material 3 baseline — Dark scheme
    static let purple80     = Color(hex: 0xD0BCFF)
    static let purpleGrey80 = Color(hex: 0xCCC2DC)
    static let pink80       = Color(hex: 0xEFB8C8)

    // Defaults referenced by Settings model
    static let defaultRoomBackground = Color(argb: 0xFF6750A4)
    static let defaultRoomText       = Color(argb: 0xFFFFFFFF)
    static let defaultUpdatedHighlight = Color(argb: 0xFFFF9800)
}

extension Color {
    /// Initialize from a 24-bit RGB hex literal (no alpha).
    init(hex: UInt32) {
        let r = Double((hex & 0xFF0000) >> 16) / 255.0
        let g = Double((hex & 0x00FF00) >>  8) / 255.0
        let b = Double((hex & 0x0000FF)       ) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    /// Initialize from a 32-bit ARGB packed value, matching the storage used
    /// in `ImageItem.roomBackgroundColor`, `Settings.updatedHighlightColor`, etc.
    init(argb: Int64) {
        let value = UInt32(truncatingIfNeeded: argb)
        let a = Double((value & 0xFF000000) >> 24) / 255.0
        let r = Double((value & 0x00FF0000) >> 16) / 255.0
        let g = Double((value & 0x0000FF00) >>  8) / 255.0
        let b = Double( value & 0x000000FF       ) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Inverse of `init(argb:)` — pack this color back to ARGB Int64 for storage/export.
    var argbInt64: Int64 {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let ai = UInt32(round(a * 255)) & 0xFF
        let ri = UInt32(round(r * 255)) & 0xFF
        let gi = UInt32(round(g * 255)) & 0xFF
        let bi = UInt32(round(b * 255)) & 0xFF
        return Int64(ai << 24 | ri << 16 | gi << 8 | bi)
        #else
        return 0
        #endif
    }
}
