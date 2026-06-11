import XCTest
import SwiftData
@testable import ForgetMeNote

/// Verifies `ImageRepository.delete(itemId:strategy:.deleteAllChildren)` removes
/// an entire subtree with no dangling rows. `ImageRepository` is a `@ModelActor`,
/// so it is built from an in-memory `ModelContainer` and driven via `await`.
final class CascadeDeleteTests: XCTestCase {

    /// In-memory container holding the model types the repository touches.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: ImageItem.self, AppSettings.self,
            configurations: config
        )
    }

    /// Count rows whose `parentId` is the given value (nil for roots).
    private func childCount(of parentId: String, in repo: ImageRepository) async -> Int {
        await repo.children(of: parentId).count
    }

    func testDeleteRootRemovesNestedSubtree() async throws {
        let container = try makeContainer()
        let repo = ImageRepository(modelContainer: container)

        // root → place → spot  (3 levels deep, all rooms / sub-spaces)
        let rootId = try await repo.createRoom(name: "Living Room")
        let placeId = try await repo.createRoom(name: "Bookshelf", parentId: rootId)
        let spotId = try await repo.createSubSpace(
            name: "Top Shelf", parentId: placeId, rectangleOnParent: nil
        )

        // Sanity: all three exist.
        let allBefore = await repo.allImages()
        XCTAssertEqual(allBefore.count, 3)

        // Delete the ROOT with full cascade.
        try await repo.delete(itemId: rootId, strategy: .deleteAllChildren)

        // Nothing left — no root, no place, no spot.
        let allAfter = await repo.allImages()
        XCTAssertTrue(allAfter.isEmpty, "expected no rows after cascade delete, got \(allAfter.count)")

        // No dangling children referencing the removed ancestors.
        let placeChildren = await childCount(of: placeId, in: repo)
        let rootChildren = await childCount(of: rootId, in: repo)
        XCTAssertEqual(placeChildren, 0)
        XCTAssertEqual(rootChildren, 0)
        // `repo.image(id:)` is actor-isolated, so await it into a local rather
        // than inside an XCTAssert autoclosure (which is not async).
        let spot = await repo.image(id: spotId)
        XCTAssertNil(spot)
    }

    func testDeleteNonRootSubtreeLeavesSiblingsIntact() async throws {
        let container = try makeContainer()
        let repo = ImageRepository(modelContainer: container)

        // root → [ branchA → leafA ],  root → branchB
        let rootId = try await repo.createRoom(name: "Garage")
        let branchAId = try await repo.createRoom(name: "Workbench", parentId: rootId)
        let leafAId = try await repo.createSubSpace(
            name: "Drawer", parentId: branchAId, rectangleOnParent: nil
        )
        let branchBId = try await repo.createRoom(name: "Pegboard", parentId: rootId)

        let allBefore = await repo.allImages()
        XCTAssertEqual(allBefore.count, 4)

        // Delete the NON-root subtree rooted at branchA.
        try await repo.delete(itemId: branchAId, strategy: .deleteAllChildren)

        // branchA + leafA gone; root + branchB remain.
        let branchA = await repo.image(id: branchAId)
        let leafA = await repo.image(id: leafAId)
        let rootStill = await repo.image(id: rootId)
        let branchBStill = await repo.image(id: branchBId)
        XCTAssertNil(branchA)
        XCTAssertNil(leafA)
        XCTAssertNotNil(rootStill)
        XCTAssertNotNil(branchBStill)

        // No dangling children under the removed branch.
        let branchAChildren = await childCount(of: branchAId, in: repo)
        XCTAssertEqual(branchAChildren, 0)

        // root no longer lists branchA among its childIds — only branchB survives.
        let rootOpt = await repo.image(id: rootId)
        let root = try XCTUnwrap(rootOpt)
        XCTAssertFalse(root.childIds.contains(branchAId), "root still references deleted branchA")
        XCTAssertTrue(root.childIds.contains(branchBId))

        let allAfter = await repo.allImages()
        XCTAssertEqual(allAfter.count, 2)
    }
}
