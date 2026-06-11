import SwiftUI
import SwiftData

/// Half-modal bottom sheet presented when the user taps the capture FAB.
/// Mirrors the `CaptureSheet` component in screens-secondary.jsx — serif
/// headline, two big quick-option tiles ("Snap a photo" / "From library"),
/// and a horizontal scroll of room pills as a shortcut to skip straight to
/// adding to a known parent.
struct V3CaptureSheet: View {
    let palette: V3Palette
    var onSnap: () -> Void
    var onLibrary: () -> Void
    var onPickRoom: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ImageItem.createdAt) private var allItems: [ImageItem]

    /// Top-level rooms (no parent, no photo). These are the suggested
    /// containers for "Or add to a room".
    private var rooms: [ImageItem] {
        allItems.filter { $0.isRoom && $0.parentId == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drag handle pill
            HStack {
                Spacer()
                Capsule()
                    .fill(palette.line)
                    .frame(width: 44, height: 5)
                Spacer()
            }
            .padding(.top, 10)
            .padding(.bottom, 14)

            // Serif headline
            (Text("Capture ")
                .font(V3Font.headline(28))
                .foregroundStyle(palette.ink) +
             Text("something.")
                .font(V3Font.headline(28, italic: true))
                .italic()
                .foregroundStyle(palette.accent))
                .tracking(-0.5)
                .padding(.horizontal, 18)

            Text("Where should this new memory live?")
                .font(.system(size: 13))
                .foregroundStyle(palette.ink2)
                .padding(.horizontal, 18)
                .padding(.top, 4)

            // Two big quick-option tiles
            HStack(spacing: 10) {
                captureOption(
                    title: "Snap a photo",
                    subtitle: "Use the camera",
                    icon: "camera",
                    bg: palette.ink,
                    fg: palette.paper,
                    accessibilityID: "v3-capture-snap",
                    action: onSnap
                )
                captureOption(
                    title: "From library",
                    subtitle: "Pick existing",
                    icon: "photo.on.rectangle",
                    bg: palette.surface,
                    fg: palette.ink,
                    iconColor: palette.accent,
                    accessibilityID: "v3-capture-library",
                    action: onLibrary
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)

            // Or add to a room
            if !rooms.isEmpty {
                Text("Or add to a room")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.ink3)
                    .padding(.horizontal, 18)
                    .padding(.top, 22)
                    .padding(.bottom, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(rooms, id: \.id) { room in
                            roomPill(room: room) { onPickRoom(room.id) }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.paper)
        .presentationDetents([.fraction(0.55), .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(palette.paper)
        .presentationCornerRadius(24)
    }

    // MARK: - Pieces

    private func captureOption(
        title: String,
        subtitle: String,
        icon: String,
        bg: Color,
        fg: Color,
        iconColor: Color? = nil,
        accessibilityID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(iconColor ?? fg)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(fg)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(fg.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(bg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }

    private func roomPill(room: ImageItem, action: @escaping () -> Void) -> some View {
        let hue = palette.hue(for: room)
        return Button(action: action) {
            HStack(spacing: 8) {
                Text(String((room.name.first ?? "?")).uppercased())
                    .font(V3Font.headline(18))
                    .foregroundStyle(hue.fg)
                    .frame(width: 28, height: 28)
                    .background(hue.bg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(room.name)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.1)
                    .foregroundStyle(palette.ink)
            }
            .padding(.leading, 8)
            .padding(.trailing, 14)
            .padding(.vertical, 8)
            .background(palette.surface, in: Capsule(style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("v3-capture-pick-room-\(room.id)")
    }
}
