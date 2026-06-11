import SwiftUI

struct V3NavHeader<Right: View>: View {
    let palette: V3Palette
    let title: String
    var subtitle: String? = nil
    var onBack: (() -> Void)? = nil
    @ViewBuilder var right: () -> Right

    var body: some View {
        HStack(alignment: .center) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.ink)
                        .frame(width: 38, height: 38)
                        .background(palette.surface, in: Circle())
                        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                        .frame(width: 44, height: 44)
                        .contentShape(SwiftUI.Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .accessibilityIdentifier("v3-nav-back")
            } else {
                Spacer().frame(width: 44)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.ink3)
                }
            }
            Spacer()
            right()
                .frame(minWidth: 38, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
        .padding(.bottom, 12)
    }
}

extension V3NavHeader where Right == EmptyView {
    init(palette: V3Palette, title: String, subtitle: String? = nil, onBack: (() -> Void)? = nil) {
        self.init(palette: palette, title: title, subtitle: subtitle, onBack: onBack,
                  right: { EmptyView() })
    }
}
