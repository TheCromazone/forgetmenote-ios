import SwiftUI

struct V3SliderRow: View {
    let palette: V3Palette
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var unit: String = ""
    var accessibilityID: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.ink)
                Spacer()
                Text("\(Int(value))\(unit)")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.ink3)
            }
            Slider(value: $value, in: range)
                .tint(palette.accent)
                .accessibilityIdentifier(accessibilityID ?? "v3-slider-\(label.lowercased().replacingOccurrences(of: " ", with: "-"))")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
