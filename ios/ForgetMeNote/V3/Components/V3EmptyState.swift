import SwiftUI

/// V3 empty state — paper card with dashed border, flower mark, title, body,
/// and optional CTA. Port of `EmptyState` from screens-space.jsx.
struct V3EmptyState: View {
    let palette: V3Palette
    let kind: Kind
    var onAdd: (() -> Void)? = nil

    enum Kind {
        case room    // "No places yet"
        case subs    // "No spots marked yet"
        case notes   // "No notes yet"
        case generic // "Nothing yet"

        var title: String {
            switch self {
            case .room:    return "No places yet"
            case .subs:    return "No spots marked yet"
            case .notes:   return "No notes yet"
            case .generic: return "Nothing yet"
            }
        }
        var body: String {
            switch self {
            case .room:    return "Tap \"Add a place\" to snap your first photo. We'll remember it for you."
            case .subs:    return "Draw a box on the photo to mark a spot. Sub-spaces help you remember the small things."
            case .notes:   return "Anything to remember? Tap to jot it down."
            case .generic: return "Add your first one."
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            FlowerMark(size: 32, color: palette.accentSoft, pollen: palette.pollen)
                .opacity(0.7)
            Text(kind.title)
                .font(V3Font.headline(20))
                .foregroundStyle(palette.ink)
                .tracking(-0.2)
                .padding(.top, 10)
            Text(kind.body)
                .font(.system(size: 13))
                .foregroundStyle(palette.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 260)
                .padding(.top, 4)
            if let onAdd {
                Button(action: onAdd) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add now")
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(-0.1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(palette.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 22)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(palette.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }
}
