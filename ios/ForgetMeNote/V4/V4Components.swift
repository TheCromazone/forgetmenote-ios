import SwiftUI
import SwiftData

struct V4Route: Hashable {
    enum Kind: Hashable {
        case room(String)
        case imageDetail(String)
        case createChild(String, String?, Rectangle?, String?)
        case settings
        case help
    }

    let kind: Kind
}

struct V4DeleteRequest: Identifiable, Equatable {
    let itemId: String
    let name: String
    let isRoom: Bool
    let descendantCount: Int

    var id: String { itemId }

    var title: String {
        isRoom ? "Delete \(name)?" : "Delete \(name)?"
    }

    var message: String {
        if descendantCount == 0 {
            return isRoom ? "This room will be removed." : "This place will be removed."
        }
        let childLabel = descendantCount == 1 ? "nested place" : "nested places"
        return "\(name) and \(descendantCount) \(childLabel) inside it will be permanently removed."
    }

    var actionTitle: String {
        isRoom ? "Delete room" : "Delete place"
    }
}

struct V4SignalMark: View {
    var size: CGFloat = 54
    var color: Color = V4.blue

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.22), lineWidth: size * 0.08)
                .frame(width: size, height: size)
            Circle()
                .stroke(color.opacity(0.35), lineWidth: size * 0.035)
                .frame(width: size * 0.66, height: size * 0.66)
            Image(systemName: "camera.macro")
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(V4.pollen)
                .shadow(color: V4.pollen.opacity(0.5), radius: 8)
        }
    }
}

struct V4GlassButton: View {
    let systemName: String
    var tint: Color = V4.ink
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.10), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct V4RoomCard: View {
    let room: ImageItem
    let childCount: Int
    let previewPaths: [String]
    var accessibilityIdentifier: String? = nil
    var deleteAccessibilityIdentifier: String? = nil
    var action: () -> Void
    var onDelete: (() -> Void)? = nil

    private var hue: (bg: Color, fg: Color, name: String) {
        if let bg = room.roomBackgroundColor {
            return (Color(argb: bg), Color(argb: room.roomTextColor ?? 0xFFFFFFFF), "custom")
        }
        return V4.hue(for: room.id)
    }
    private var initial: String { String(room.name.prefix(1)).uppercased() }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                ZStack(alignment: .bottomLeading) {
                    hue.bg
                    LinearGradient(
                        colors: [.white.opacity(0.18), .clear, .black.opacity(0.20)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Circle()
                        .fill(hue.fg.opacity(0.10))
                        .frame(width: 122, height: 122)
                        .offset(x: 70, y: -70)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top) {
                            Text(initial)
                                .font(V4.title(54))
                                .foregroundStyle(hue.fg)
                            Spacer()
                            if !previewPaths.isEmpty {
                                previewStack
                            } else {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(hue.fg.opacity(0.75))
                                    .padding(.top, onDelete == nil ? 0 : 44)
                            }
                        }
                        Spacer()
                        Text(room.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(hue.fg)
                            .lineLimit(1)
                        Text("\(childCount) \(childCount == 1 ? "place" : "places")")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(hue.fg.opacity(0.72))
                            .padding(.top, 3)
                    }
                    .padding(16)
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: hue.bg.opacity(0.34), radius: 18, y: 9)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(accessibilityIdentifier ?? "v4-room-\(room.id)")

            if let onDelete {
                V4DeleteBadgeButton(
                    accessibilityIdentifier: deleteAccessibilityIdentifier,
                    action: onDelete
                )
                    .padding(10)
            }
        }
    }

    @ViewBuilder private var previewStack: some View {
        HStack(spacing: -9) {
            ForEach(Array(previewPaths.prefix(3).enumerated()), id: \.offset) { _, path in
                if let image = UIImage(contentsOfFile: path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(hue.bg, lineWidth: 2)
                        )
                }
            }
        }
    }
}

struct V4PlaceCard: View {
    let item: ImageItem
    let childCount: Int
    var accessibilityIdentifier: String? = nil
    var deleteAccessibilityIdentifier: String? = nil
    var action: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        if let path = item.filePath, let image = UIImage(contentsOfFile: path) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            LinearGradient(
                                colors: [V4.panel2, V4.panel],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Text(item.name.prefix(1).uppercased())
                                .font(V4.title(46))
                                .foregroundStyle(V4.blue)
                        }
                        if item.isUpdated {
                            Image(systemName: "sparkle")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: 0x261A05))
                                .frame(width: 26, height: 26)
                                .background(V4.pollen, in: Circle())
                                .padding(8)
                                .padding(.trailing, onDelete == nil ? 0 : 42)
                        }
                        if childCount > 0 {
                            Label("\(childCount)", systemImage: "square.grid.2x2")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(.black.opacity(0.46), in: Capsule())
                                .padding(8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        }
                    }
                    .frame(height: 148)
                    .clipped()

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(V4.ink)
                            .lineLimit(1)
                        Text(item.tags.prefix(2).map { "#\($0)" }.joined(separator: " "))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(V4.ink3)
                            .lineLimit(1)
                    }
                    .padding(12)
                }
                .background(V4.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(V4.line, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(accessibilityIdentifier ?? "v4-place-\(item.id)")

            if let onDelete {
                V4DeleteBadgeButton(
                    accessibilityIdentifier: deleteAccessibilityIdentifier,
                    action: onDelete
                )
                    .padding(8)
            }
        }
    }
}

struct V4DeleteBadgeButton: View {
    var accessibilityIdentifier: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: 0xFFF4EC))
                .frame(width: 34, height: 34)
                .background(V4.coral.opacity(0.96), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 1))
                .shadow(color: .black.opacity(0.28), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete")
        .accessibilityIdentifier(accessibilityIdentifier ?? "v4-delete-item")
    }
}

struct V4EmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            V4SignalMark(size: 56, color: V4.ink3)
                .opacity(0.75)
            Text(title)
                .font(V4.title(24))
                .foregroundStyle(V4.ink)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(V4.ink3)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }
}
