import SwiftUI

struct V3SettingsSection<Content: View>: View {
    let palette: V3Palette
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(palette.ink3)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content()
            }
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        }
        .padding(.top, 26)
    }
}
