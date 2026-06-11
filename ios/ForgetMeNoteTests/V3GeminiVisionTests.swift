import XCTest
@testable import ForgetMeNote

/// Tests the pure parsing half of `V3GeminiVision` — extracting candidate text
/// from a generateContent response and converting the model's 0–1000
/// `box_2d` JSON into normalized `DetectedObjectInfo` boxes.
final class V3GeminiVisionTests: XCTestCase {

    func testParseDetectionsConvertsBox2dToNormalizedRect() {
        let json = """
        [{"label": "blue ceramic mug", "box_2d": [100, 200, 500, 600]}]
        """
        let dets = V3GeminiVision.parseDetections(jsonText: json)
        XCTAssertEqual(dets.count, 1)
        XCTAssertEqual(dets[0].label, "blue ceramic mug")
        // box_2d is [ymin, xmin, ymax, xmax] / 1000.
        XCTAssertEqual(dets[0].boundingBox.x, 0.2, accuracy: 0.001)
        XCTAssertEqual(dets[0].boundingBox.y, 0.1, accuracy: 0.001)
        XCTAssertEqual(dets[0].boundingBox.width, 0.4, accuracy: 0.001)
        XCTAssertEqual(dets[0].boundingBox.height, 0.4, accuracy: 0.001)
    }

    func testParseDetectionsStripsMarkdownFences() {
        let fenced = """
        ```json
        [{"label": "book", "box_2d": [0, 0, 1000, 1000]}]
        ```
        """
        XCTAssertEqual(V3GeminiVision.parseDetections(jsonText: fenced).count, 1)
    }

    func testParseDetectionsSkipsMalformedAndDegenerate() {
        let json = """
        [{"label": "ok", "box_2d": [0, 0, 500, 500]},
         {"label": "", "box_2d": [0, 0, 500, 500]},
         {"label": "missing box"},
         {"label": "short box", "box_2d": [0, 0, 500]},
         {"label": "zero area", "box_2d": [100, 100, 100, 100]},
         {"label": "clamped", "box_2d": [-50, -50, 2000, 2000]}]
        """
        let dets = V3GeminiVision.parseDetections(jsonText: json)
        XCTAssertEqual(dets.map(\.label), ["ok", "clamped"])
        // Out-of-range coords clamp into 0..1.
        XCTAssertEqual(dets[1].boundingBox.x, 0, accuracy: 0.001)
        XCTAssertEqual(dets[1].boundingBox.width, 1, accuracy: 0.001)
    }

    func testParseDetectionsGarbageReturnsEmpty() {
        XCTAssertTrue(V3GeminiVision.parseDetections(jsonText: "not json at all").isEmpty)
        XCTAssertTrue(V3GeminiVision.parseDetections(jsonText: "{\"label\": \"obj\"}").isEmpty)
    }

    func testCandidateTextExtractsFirstCandidateParts() {
        let body = """
        {"candidates": [{"content": {"parts": [{"text": "[{\\"label\\""},
                                               {"text": ": \\"x\\"}]"}]}}]}
        """.data(using: .utf8)!
        XCTAssertEqual(V3GeminiVision.candidateText(from: body), "[{\"label\": \"x\"}]")
    }

    func testCandidateTextEmptyOnMissingCandidates() {
        let body = "{\"candidates\": []}".data(using: .utf8)!
        XCTAssertNil(V3GeminiVision.candidateText(from: body))
    }
}
