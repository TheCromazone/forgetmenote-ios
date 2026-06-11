import Foundation

/// One flattened row of the hierarchy: an item plus its nesting depth and
/// whether it has children (so the tree/carousel can draw a disclosure chevron
/// and the carousel can offer "tap to open the shelf").
struct V3TreeNode: Hashable, Identifiable {
    let item: ImageItem
    let depth: Int
    let hasChildren: Bool
    var id: String { item.id }

    static func == (lhs: V3TreeNode, rhs: V3TreeNode) -> Bool {
        lhs.item.id == rhs.item.id && lhs.depth == rhs.depth && lhs.hasChildren == rhs.hasChildren
    }
    func hash(into hasher: inout Hasher) { hasher.combine(item.id) }
}

/// Pure tree helpers — the same flattened list feeds BOTH the horizontal
/// carousel and the vertical hierarchy tree, so their indices stay in lock-step
/// (this is what keeps "swipe the photo" and "tap the tree row" synchronized,
/// the way the Android `MainScreen` keeps its pager + `ImageTreeView` in sync).
enum V3Tree {
    /// Depth-first flatten of the whole forest rooted at the `parentId == nil`
    /// items. A node's children are included only when its id is in `expanded`,
    /// so collapsing a room hides (but never loses) its sub-tree.
    /// Siblings are ordered by `createdAt` to match the rest of v3.
    static func flatten(items: [ImageItem], expanded: Set<String>) -> [V3TreeNode] {
        var childrenByParent: [String: [ImageItem]] = [:]
        var roots: [ImageItem] = []
        for item in items {
            if let pid = item.parentId {
                childrenByParent[pid, default: []].append(item)
            } else {
                roots.append(item)
            }
        }
        for key in childrenByParent.keys {
            childrenByParent[key]?.sort { $0.createdAt < $1.createdAt }
        }
        roots.sort { $0.createdAt < $1.createdAt }

        var result: [V3TreeNode] = []
        // Guard against cyclic parent links (corrupt data) so we never recurse
        // forever — each id is visited at most once.
        var visited = Set<String>()
        func visit(_ item: ImageItem, _ depth: Int) {
            guard !visited.contains(item.id) else { return }
            visited.insert(item.id)
            let kids = childrenByParent[item.id] ?? []
            result.append(V3TreeNode(item: item, depth: depth, hasChildren: !kids.isEmpty))
            if expanded.contains(item.id) {
                for kid in kids { visit(kid, depth + 1) }
            }
        }
        for root in roots { visit(root, 0) }
        return result
    }

    /// The ancestor chain root → item (inclusive), used for the breadcrumb.
    static func ancestry(of id: String, byId: [String: ImageItem]) -> [ImageItem] {
        guard var cur = byId[id] else { return [] }
        var chain: [ImageItem] = [cur]
        var hops = 0
        while let pid = cur.parentId, let parent = byId[pid], hops < 64 {
            chain.insert(parent, at: 0)
            cur = parent
            hops += 1
        }
        return chain
    }
}
