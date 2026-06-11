import SwiftUI

struct V3PrimaryButton: View {
    let palette: V3Palette
    let label: String
    var loading: Bool = false
    var disabled: Bool = false
    var accessibilityID: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: { if !loading && !disabled { action() } }) {
            ZStack {
                if loading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(disabled ? palette.line : palette.accent,
                        in: Capsule(style: .continuous))
            .shadow(color: disabled ? .clear : palette.accent.opacity(0.33),
                    radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(disabled || loading)
        .accessibilityIdentifier(accessibilityID ?? "v3-primary-\(label.lowercased())")
    }
}
