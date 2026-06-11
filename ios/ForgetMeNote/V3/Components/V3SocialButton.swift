import SwiftUI

enum V3SocialKind { case apple, google }

struct V3SocialButton: View {
    let palette: V3Palette
    let kind: V3SocialKind
    var accessibilityID: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Group {
                    switch kind {
                    case .apple:
                        Image(systemName: "applelogo")
                            .foregroundStyle(.white)
                    case .google:
                        Text("G")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(hex: 0x4285F4))
                    }
                }
                Text(kind == .apple ? "Continue with Apple" : "Continue with Google")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(kind == .apple ? .white : palette.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(kind == .apple ? Color.black : palette.surface,
                        in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous)
                        .stroke(kind == .google ? palette.line : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID ?? "v3-social-\(kind == .apple ? "apple" : "google")")
    }
}
