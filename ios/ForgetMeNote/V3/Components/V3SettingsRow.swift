import SwiftUI

struct V3SettingsRow: View {
    let palette: V3Palette
    let icon: String
    let label: String
    var detail: String? = nil
    var accent: Bool = false
    var destructive: Bool = false
    var showsChevron: Bool = true
    var accessibilityID: String? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(destructive ? palette.danger :
                                       (accent ? palette.accent : palette.ink2))
                    .frame(width: 28, height: 28)
                    .background(destructive ? palette.danger.opacity(0.1) :
                                  (accent ? palette.accentBg : palette.paperEdge),
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(label)
                    .font(.system(size: 15, weight: accent || destructive ? .semibold : .medium))
                    .foregroundStyle(destructive ? palette.danger :
                                       (accent ? palette.accent : palette.ink))
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(palette.ink3)
                }
                if showsChevron && !destructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.ink3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(SwiftUI.Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .accessibilityIdentifier(accessibilityID ?? "v3-settings-row-\(label.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }
}
