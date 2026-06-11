import SwiftUI

/// Vertical, top-to-bottom indented hierarchy — the v3 take on the Android
/// `ImageTreeView`. Rooms are roots; each child is indented one step. A node
/// with children shows a disclosure chevron (tap to expand/collapse); the row
/// body selects the node (which scrolls the carousel above to it). Tapping a
/// leaf row opens it directly.
///
/// Driven entirely by the parent screen's `nodes` (the shared flattened list)
/// + `selectedId` + `expanded`, so it never holds navigation state of its own.
struct V3HierarchyTree: View {
    let palette: V3Palette
    let nodes: [V3TreeNode]
    let selectedId: String?
    let expanded: Set<String>
    /// childParentId → count, so each row can show "(3)" without re-scanning.
    let childCounts: [String: Int]
    /// id → the photo slice an item displays (own photo or cropped region).
    let regions: [String: V3Region]
    var onSelect: (String) -> Void
    var onToggleExpand: (String) -> Void
    var onOpen: (ImageItem) -> Void
    /// Inline "+" on a row → add a spot inside that node (quick add into any room).
    var onAdd: (String) -> Void = { _ in }
    /// Long-press a row → Delete. The parent screen owns the confirmation +
    /// repository delete. nil hides the menu entry.
    var onDelete: ((ImageItem) -> Void)? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(nodes) { node in
                        row(node)
                            .id(node.item.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 120)   // tab-bar + FAB clearance
            }
            .onChange(of: selectedId) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder private func row(_ node: V3TreeNode) -> some View {
        let item = node.item
        let isSelected = item.id == selectedId
        let isExpanded = expanded.contains(item.id)
        let count = childCounts[item.id] ?? 0

        HStack(spacing: 8) {
            // Indentation rail.
            if node.depth > 0 {
                Color.clear.frame(width: CGFloat(node.depth) * 18, height: 1)
                SwiftUI.Rectangle()
                    .fill(palette.line)
                    .frame(width: 1.5, height: 22)
                    .padding(.trailing, 2)
            }

            // Disclosure chevron (only for nodes with children).
            if node.hasChildren {
                Button {
                    V3Haptics.selection()
                    onToggleExpand(item.id)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.ink2)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 26, height: 26)
                        .background(palette.paperEdge, in: Circle())
                        .contentShape(SwiftUI.Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("v3-tree-chevron-\(item.id)")
                .accessibilityLabel(isExpanded ? "Collapse" : "Expand")
            } else {
                // Leaf marker dot keeps alignment tidy.
                Circle()
                    .fill(palette.ink3.opacity(0.4))
                    .frame(width: 5, height: 5)
                    .frame(width: 26, height: 26)
            }

            // Color swatch / serif initial for rooms, doc glyph for spaces.
            marker(for: item)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name.isEmpty ? "Untitled" : item.name)
                    .font(.system(size: 15, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? palette.accent : palette.ink)
                    .tracking(-0.1)
                    .lineLimit(1)
                if count > 0 {
                    Text("\(count) inside")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.ink3)
                }
            }

            Spacer(minLength: 4)

            if item.isUpdated {
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(palette.accent)
            }

            // Inline quick-add: drop a new spot straight into this node.
            Button {
                V3Haptics.impact(.light)
                onAdd(item.id)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 30, height: 30)
                    .background(palette.accentBg, in: Circle())
                    .contentShape(SwiftUI.Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("v3-tree-add-\(item.id)")
            .accessibilityLabel("Add inside \(item.name)")
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? palette.accentBg : Color.clear)
        )
        .contentShape(SwiftUI.Rectangle())
        .onTapGesture {
            if node.hasChildren {
                onSelect(item.id)
            } else {
                onSelect(item.id)
                onOpen(item)
            }
        }
        .contextMenu {
            Button {
                onSelect(item.id)
                onOpen(item)
            } label: { Label("Open", systemImage: "arrow.up.right") }
            if let onDelete {
                Button(role: .destructive) {
                    onDelete(item)
                } label: { Label("Delete", systemImage: "trash") }
            }
        }
        .accessibilityIdentifier("v3-tree-row-\(item.id)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder private func marker(for item: ImageItem) -> some View {
        if let region = regions[item.id] {
            V3TreeThumb(region: region, corner: 9)
                .frame(width: 28, height: 28)
        } else {
            let hue = palette.hue(for: item)
            Text(String(item.name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                .font(V3Font.headline(15))
                .foregroundStyle(hue.fg)
                .frame(width: 28, height: 28)
                .background(hue.bg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }
}

/// Tiny cropped-region thumbnail for a tree row, decoded off-main once.
private struct V3TreeThumb: View {
    let region: V3Region
    var corner: CGFloat = 9
    @State private var img: UIImage?

    var body: some View {
        ZStack {
            if let img {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color(.secondarySystemBackground)
                Image(systemName: "photo")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .task(id: region) {
            if img == nil { img = V3RegionImage.cached(region, maxPixelSize: 120) }
            img = await V3RegionImage.load(region, maxPixelSize: 120)
        }
    }
}
