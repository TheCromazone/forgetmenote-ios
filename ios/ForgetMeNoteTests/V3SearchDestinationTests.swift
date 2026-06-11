import XCTest
@testable import ForgetMeNote

/// Tests the pure `v3SearchDestination(for:)` free function used by
/// `V3FindScreen` result rows. It must mirror the browse screens' `openItem`:
/// anything with a picture to show (own photo or a traced/cropped region)
/// opens `v3Space` directly; rooms and empty boxes open `v3Room` so the
/// browse lands centered on them.
final class V3SearchDestinationTests: XCTestCase {

    func testRoomRoutesToRoomBrowse() {
        let room = ImageItem(id: "room-1", name: "Living Room")
        XCTAssertEqual(v3SearchDestination(for: room), .v3Room(roomId: "room-1"))
    }

    func testEmptyBoxRoutesToRoomBrowse() {
        // A nested container with no photo and no rect (an "empty box").
        let box = ImageItem(id: "box-1", name: "Drawer", parentId: "room-1")
        XCTAssertEqual(v3SearchDestination(for: box), .v3Room(roomId: "box-1"))
    }

    func testPhotoRoutesToSpace() {
        let photo = ImageItem(id: "photo-1", name: "Bookshelf",
                              filePath: "/tmp/shelf.jpg", parentId: "room-1")
        XCTAssertEqual(v3SearchDestination(for: photo), .v3Space(spaceId: "photo-1"))
    }

    func testSubPictureRoutesToSpace() {
        // A sub-space anchored as a rectangle on its parent photo — must open
        // its own cropped picture, not the room browse.
        let sub = ImageItem(id: "sub-1", name: "Top Shelf",
                            parentId: "photo-1",
                            rectangleOnParent: Rectangle(x: 0.1, y: 0.1,
                                                         width: 0.5, height: 0.3))
        XCTAssertEqual(v3SearchDestination(for: sub), .v3Space(spaceId: "sub-1"))
    }
}
