import XCTest
@testable import ForgetMeNote

/// Unit coverage for `V3Tree` — the pure flatten/ancestry logic that keeps the
/// browse carousel and the hierarchy tree in lock-step. `ImageItem` is a
/// SwiftData `@Model` but has a plain initializer and `V3Tree` only reads stored
/// properties, so these run without a `ModelContainer`.
final class V3TreeTests: XCTestCase {

    /// root A (has child A1 → grandchild A1a) and root B (leaf).
    private func sampleForest() -> [ImageItem] {
        let a   = ImageItem(id: "A",   name: "Living Room", parentId: nil,  createdAt: 1000)
        let a1  = ImageItem(id: "A1",  name: "Shelf",       parentId: "A",  createdAt: 2000)
        let a1a = ImageItem(id: "A1a", name: "Top",         parentId: "A1", createdAt: 3000)
        let b   = ImageItem(id: "B",   name: "Bedroom",     parentId: nil,  createdAt: 4000)
        // Deliberately out of order to prove sibling sort by createdAt.
        return [b, a1a, a, a1]
    }

    func testCollapsedShowsOnlyRoots() {
        let nodes = V3Tree.flatten(items: sampleForest(), expanded: [])
        XCTAssertEqual(nodes.map(\.item.id), ["A", "B"])
        XCTAssertEqual(nodes.map(\.depth), [0, 0])
        XCTAssertTrue(nodes[0].hasChildren)   // A has a child
        XCTAssertFalse(nodes[1].hasChildren)  // B is a leaf
    }

    func testExpandingOneLevelRevealsDirectChildren() {
        let nodes = V3Tree.flatten(items: sampleForest(), expanded: ["A"])
        XCTAssertEqual(nodes.map(\.item.id), ["A", "A1", "B"])
        XCTAssertEqual(nodes.map(\.depth), [0, 1, 0])
        XCTAssertTrue(nodes[1].hasChildren)   // A1 has a grandchild
    }

    func testFullyExpandedIsDepthFirst() {
        let nodes = V3Tree.flatten(items: sampleForest(), expanded: ["A", "A1"])
        XCTAssertEqual(nodes.map(\.item.id), ["A", "A1", "A1a", "B"])
        XCTAssertEqual(nodes.map(\.depth), [0, 1, 2, 0])
    }

    func testAncestryChainRootToItem() {
        let byId = Dictionary(uniqueKeysWithValues: sampleForest().map { ($0.id, $0) })
        let chain = V3Tree.ancestry(of: "A1a", byId: byId)
        XCTAssertEqual(chain.map(\.id), ["A", "A1", "A1a"])
    }

    func testCyclicParentLinksTerminate() {
        // X ↔ Y reference each other; neither is a root, so flatten yields
        // nothing and — crucially — does not loop forever.
        let x = ImageItem(id: "X", name: "X", parentId: "Y", createdAt: 1)
        let y = ImageItem(id: "Y", name: "Y", parentId: "X", createdAt: 2)
        let nodes = V3Tree.flatten(items: [x, y], expanded: ["X", "Y"])
        XCTAssertTrue(nodes.isEmpty)

        // Ancestry on a cycle also terminates (hop cap) rather than hanging.
        let byId = ["X": x, "Y": y]
        let chain = V3Tree.ancestry(of: "X", byId: byId)
        XCTAssertFalse(chain.isEmpty)
    }
}
