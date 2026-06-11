import XCTest
@testable import ForgetMeNote

/// Tests the pure `v3FilterItems(_:query:)` free function used by
/// `V3FindScreen.results`. The function lives in `V3/Screens/V3FindScreen.swift`
/// and matches `query` (case-insensitive) against name, notes, or any tag,
/// returning an empty array for an empty/whitespace query.
final class SearchFilterTests: XCTestCase {

    private func makeItems() -> [ImageItem] {
        let charger = ImageItem(name: "USB-C Charger", tags: ["cables", "electronics"])
        let leaves = ImageItem(name: "Bay Leaves")
        leaves.notes = "Top shelf of the spice rack"
        let book = ImageItem(name: "Cookbook", tags: ["kitchen"])
        return [charger, leaves, book]
    }

    func testEmptyQueryReturnsEmpty() {
        let items = makeItems()
        XCTAssertTrue(v3FilterItems(items, query: "").isEmpty)
        XCTAssertTrue(v3FilterItems(items, query: "   ").isEmpty)
    }

    func testMatchByNameCaseInsensitive() {
        let items = makeItems()
        let results = v3FilterItems(items, query: "charger")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "USB-C Charger")
    }

    func testMatchByTag() {
        let items = makeItems()
        let results = v3FilterItems(items, query: "cables")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "USB-C Charger")
    }

    func testMatchByNotes() {
        let items = makeItems()
        let results = v3FilterItems(items, query: "spice")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Bay Leaves")
    }

    func testNoMatchReturnsEmpty() {
        let items = makeItems()
        XCTAssertTrue(v3FilterItems(items, query: "telescope").isEmpty)
    }
}
