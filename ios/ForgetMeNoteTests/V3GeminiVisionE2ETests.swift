import XCTest
import UIKit
@testable import ForgetMeNote

/// Mocked END-TO-END tests for `V3GeminiVision.detect` — a URLProtocol stub
/// captures the real outgoing request (so a malformed body or wrong header is
/// caught here, not silently in production) and returns a canned Gemini
/// response that must come back parsed into detections.
final class V3GeminiVisionE2ETests: XCTestCase {

    final class StubProtocol: URLProtocol {
        static var lastRequest: URLRequest?
        static var lastBody: Data?
        static var responseBody: Data = Data()
        static var responseStatus: Int = 200
        /// URL-substring → (status, body) overrides, matched before the
        /// defaults; lets one test serve different models different answers.
        static var routes: [(match: String, status: Int, body: Data)] = []
        static var requestedURLs: [String] = []

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            Self.lastRequest = request
            Self.requestedURLs.append(request.url?.absoluteString ?? "")
            // httpBody is nil inside URLProtocol; read the body stream.
            if let stream = request.httpBodyStream {
                stream.open()
                var data = Data()
                let bufSize = 64 * 1024
                let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
                defer { buf.deallocate(); stream.close() }
                while stream.hasBytesAvailable {
                    let n = stream.read(buf, maxLength: bufSize)
                    if n <= 0 { break }
                    data.append(buf, count: n)
                }
                Self.lastBody = data
            }
            let url = request.url?.absoluteString ?? ""
            let matched = Self.routes.first { url.contains($0.match) }
            let status = matched?.status ?? Self.responseStatus
            let body = matched?.body ?? Self.responseBody
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: status,
                                           httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    private var tempImagePath: String!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        V3GeminiVision.session = URLSession(configuration: config)
        UserDefaults.standard.set("TEST-KEY-123", forKey: "v3_gemini_api_key")

        // A real (tiny) JPEG on disk for the downsampler to read.
        let img = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        tempImagePath = NSTemporaryDirectory() + "gemini-e2e-test.jpg"
        try? img.jpegData(compressionQuality: 0.9)?.write(to: URL(fileURLWithPath: tempImagePath))
    }

    override func tearDown() {
        V3GeminiVision.session = .shared
        UserDefaults.standard.removeObject(forKey: "v3_gemini_api_key")
        try? FileManager.default.removeItem(atPath: tempImagePath)
        StubProtocol.lastRequest = nil
        StubProtocol.lastBody = nil
        StubProtocol.routes = []
        StubProtocol.requestedURLs = []
        super.tearDown()
    }

    private func cannedBody(text: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "candidates": [["content": ["parts": [["text": text]]]]]
        ])
    }

    func testDetectSendsWellFormedRequestAndParsesResponse() async throws {
        let canned: [String: Any] = ["candidates": [[
            "content": ["parts": [[
                "text": #"[{"label": "demo mug", "box_2d": [100, 100, 400, 400]}]"#
            ]]]
        ]]]
        StubProtocol.responseBody = try JSONSerialization.data(withJSONObject: canned)
        StubProtocol.responseStatus = 200

        let detections = try await V3GeminiVision.detect(imagePath: tempImagePath)

        // Response parsed end-to-end.
        XCTAssertEqual(detections.count, 1)
        XCTAssertEqual(detections.first?.label, "demo mug")

        // Outgoing request is well-formed.
        let request = try XCTUnwrap(StubProtocol.lastRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url!.absoluteString.contains("gemini-2.5-flash:generateContent"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "TEST-KEY-123")

        let body = try XCTUnwrap(StubProtocol.lastBody)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let contents = try XCTUnwrap(root["contents"] as? [[String: Any]])
        let parts = try XCTUnwrap(contents.first?["parts"] as? [[String: Any]])
        // Image part carries real base64 JPEG data.
        let inline = try XCTUnwrap(parts.first?["inline_data"] as? [String: Any])
        XCTAssertEqual(inline["mime_type"] as? String, "image/jpeg")
        let b64 = try XCTUnwrap(inline["data"] as? String)
        XCTAssertNotNil(Data(base64Encoded: b64), "image payload must be valid base64")
        // Schema forces a bare array reply (the original silent-fallback bug).
        let genConfig = try XCTUnwrap(root["generationConfig"] as? [String: Any])
        XCTAssertEqual(genConfig["responseMimeType"] as? String, "application/json")
        let schema = try XCTUnwrap(genConfig["responseSchema"] as? [String: Any])
        XCTAssertEqual(schema["type"] as? String, "ARRAY")
    }

    func testDetectThrowsTypedErrorWhenAllModelsFail() async {
        StubProtocol.responseBody = Data("{}".utf8)
        StubProtocol.responseStatus = 429

        do {
            _ = try await V3GeminiVision.detect(imagePath: tempImagePath)
            XCTFail("expected http error")
        } catch let error as V3GeminiVision.GeminiError {
            XCTAssertEqual(error.errorDescription, "HTTP 429")
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
        // Every model in the chain was attempted before giving up.
        XCTAssertEqual(StubProtocol.requestedURLs.count,
                       V3GeminiVision.candidateModels.count)
    }

    func testDetectFallsBackToNextModelOn503() async throws {
        // Primary model overloaded (the real free-tier failure the user hit);
        // flash-lite answers — detect() must ride the chain and succeed.
        StubProtocol.routes = [
            (match: "gemini-2.5-flash:", status: 503,
             body: Data(#"{"error": {"code": 503}}"#.utf8)),
            (match: "gemini-2.5-flash-lite:", status: 200,
             body: try cannedBody(text: #"[{"label": "rescued vase", "box_2d": [0, 0, 500, 500]}]"#)),
        ]
        StubProtocol.responseStatus = 503
        StubProtocol.responseBody = Data(#"{"error": {"code": 503}}"#.utf8)

        let detections = try await V3GeminiVision.detect(imagePath: tempImagePath)
        XCTAssertEqual(detections.map(\.label), ["rescued vase"])
        XCTAssertTrue(StubProtocol.requestedURLs.contains {
            $0.contains("gemini-2.5-flash-lite:generateContent")
        })
    }

    func testParseDetectionsUnwrapsObjectWrappedArray() {
        // The model sometimes ignores "bare array" and wraps it — must not
        // silently produce zero detections (the bug behind "it still looks
        // like Apple Vision").
        let wrapped = #"{"objects": [{"label": "vase", "box_2d": [0, 0, 500, 500]}]}"#
        let dets = V3GeminiVision.parseDetections(jsonText: wrapped)
        XCTAssertEqual(dets.map(\.label), ["vase"])
    }
}
