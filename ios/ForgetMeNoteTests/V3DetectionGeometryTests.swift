import XCTest
@testable import ForgetMeNote

final class V3DetectionGeometryTests: XCTestCase {

    func testDisplayRectMapsNormalizedToContainer() {
        let r = Rectangle(x: 0.25, y: 0.5, width: 0.5, height: 0.25)
        let rect = V3DetectionGeometry.displayRect(for: r, in: CGSize(width: 200, height: 400))
        XCTAssertEqual(rect.origin.x, 50, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 200, accuracy: 0.001)
        XCTAssertEqual(rect.size.width, 100, accuracy: 0.001)
        XCTAssertEqual(rect.size.height, 100, accuracy: 0.001)
    }

    func testIoUIdenticalRectsIsOne() {
        let a = Rectangle(x: 0.1, y: 0.1, width: 0.4, height: 0.4)
        XCTAssertEqual(V3DetectionGeometry.iou(a, a), 1.0, accuracy: 0.0001)
    }

    func testIoUDisjointRectsIsZero() {
        let a = Rectangle(x: 0.0, y: 0.0, width: 0.2, height: 0.2)
        let b = Rectangle(x: 0.5, y: 0.5, width: 0.2, height: 0.2)
        XCTAssertEqual(V3DetectionGeometry.iou(a, b), 0.0, accuracy: 0.0001)
    }
}
