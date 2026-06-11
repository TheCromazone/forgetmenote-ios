import XCTest
@testable import ForgetMeNote

/// Tests the one-shot `V3PendingTrace` hand-off used to pass a freehand
/// outline from V3SpaceScreen's draw-a-spot tool into V3CreateSubScreen
/// (the shared Route enum can't carry a TracePath).
final class V3PendingTraceTests: XCTestCase {

    func testConsumeReturnsStashedTraceOnce() {
        let t = TracePath(points: [TracePoint(x: 0.1, y: 0.1),
                                   TracePoint(x: 0.5, y: 0.2),
                                   TracePoint(x: 0.3, y: 0.6)])
        V3PendingTrace.stash(t)
        XCTAssertEqual(V3PendingTrace.consume()?.points.count, 3)
        // Second consume must be empty — a stale outline must never leak into
        // a later CreateSub.
        XCTAssertNil(V3PendingTrace.consume())
    }

    func testBoundingBoxCoversTracedPoints() {
        let t = TracePath(points: [TracePoint(x: 0.1, y: 0.2),
                                   TracePoint(x: 0.5, y: 0.4),
                                   TracePoint(x: 0.3, y: 0.7)])
        let box = t.boundingBox
        XCTAssertEqual(box.x, 0.1, accuracy: 0.001)
        XCTAssertEqual(box.y, 0.2, accuracy: 0.001)
        XCTAssertEqual(box.width, 0.4, accuracy: 0.001)
        XCTAssertEqual(box.height, 0.5, accuracy: 0.001)
    }
}
