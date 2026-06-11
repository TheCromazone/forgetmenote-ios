import Foundation
import UIKit

/// Cloud "enhanced scan" via the Gemini API (free tier) — sends the photo to a
/// Gemini Flash model and asks for every distinct object with a normalized
/// bounding box. Gemini is trained for spatial output (`box_2d` as
/// [ymin, xmin, ymax, xmax] scaled 0–1000), which maps 1:1 onto the app's
/// `DetectedObjectInfo` boxes, so results render through the existing
/// `V3DetectionOverlay` exactly like on-device ones (box + label; no mask).
///
/// `V3SpaceScreen` prefers this service when a key is configured and falls
/// back to the on-device `V3VisionService` when it's missing, offline, or
/// errors — surfacing WHY in the detection message so a cloud failure is
/// never silently mistaken for "Gemini doesn't help".
enum V3GeminiVision {

    // MARK: - Configuration

    /// Config string lookup: UserDefaults first (covers normal use AND
    /// `-key value` launch args via the argument domain), then a manual scan
    /// of the raw launch arguments ("key value" without the dash) so Maestro
    /// `launchApp: arguments:` injection works regardless of its exact format.
    private static func configString(_ key: String) -> String? {
        if let stored = UserDefaults.standard.string(forKey: key) {
            let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        let args = ProcessInfo.processInfo.arguments
        for (i, arg) in args.enumerated() where arg == key || arg == "-\(key)" {
            if i + 1 < args.count { return args[i + 1] }
        }
        return nil
    }

    /// User-pasted key (saved by the guided setup sheet after live
    /// verification), falling back to an Info.plist `GeminiAPIKey` entry (dev
    /// convenience). Empty/whitespace = not configured.
    static var apiKey: String {
        if let key = configString("v3_gemini_api_key") { return key }
        let plist = Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String ?? ""
        return plist.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Best free-tier model for detection: 2.5 Flash has documented spatial
    /// understanding (boxes + segmentation) and a 1,500 req/day free quota.
    /// Override via UserDefaults `v3_gemini_model` if a newer Flash lands.
    static var model: String {
        configString("v3_gemini_model") ?? "gemini-2.5-flash"
    }

    /// Models tried IN ORDER until one returns objects. The free tier's
    /// popular models intermittently return 503 "overloaded" (Google-side) or
    /// the odd empty array — falling through the Flash family rides that out.
    /// `gemini-flash-latest` is Google's rolling alias for the newest Flash.
    /// A user/QA override goes first; unknown ids just 404 and the chain
    /// moves on.
    static var candidateModels: [String] {
        var chain = [model, "gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-flash-latest"]
        var seen = Set<String>()
        chain = chain.filter { seen.insert($0).inserted }
        return chain
    }

    /// API origin — overridable via `v3_gemini_endpoint` (UserDefaults or
    /// launch argument) so QA can point the FULL in-app pipeline at a local
    /// mock server.
    static var endpointBase: String {
        configString("v3_gemini_endpoint") ?? "https://generativelanguage.googleapis.com"
    }

    /// Injectable for unit tests (URLProtocol mocks).
    static var session: URLSession = .shared

    /// Master switch (Settings → AI scanning). Defaults ON so pasting a key
    /// "just works"; flip OFF to force the on-device Apple Vision scan while
    /// keeping the key saved.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "v3_gemini_enabled") as? Bool ?? true
    }

    static var isConfigured: Bool { !apiKey.isEmpty && isEnabled }

    enum GeminiError: Error, LocalizedError {
        case missingKey
        case badImage
        case http(Int)
        case network
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .missingKey:    return "no key"
            case .badImage:      return "couldn't read the photo"
            case .http(let c):   return "HTTP \(c)"
            case .network:       return "no connection"
            case .emptyResponse: return "empty reply"
            }
        }
    }

    /// Cheap live check that a pasted key actually works: GET the model's
    /// metadata (no tokens consumed, no quota hit). 200 → good key.
    static func validateKey(_ key: String) async -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: "\(endpointBase)/v1beta/models/\(model)") else {
            return false
        }
        var request = URLRequest(url: url)
        request.setValue(trimmed, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 15
        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }

    /// Where users create their free key — opened from the in-app setup sheet.
    static let keyConsoleURL = URL(string: "https://aistudio.google.com/apikey")!

    // MARK: - Detection

    static func detect(imagePath: String) async throws -> [DetectedObjectInfo] {
        let key = apiKey
        guard !key.isEmpty else { throw GeminiError.missingKey }
        // ~1024px keeps the upload small (free-tier friendly) while leaving
        // plenty of pixels for the model to find small objects.
        guard let image = V3ImageDownsampler.downsample(path: imagePath, maxPixelSize: 1024),
              let jpeg = image.jpegData(compressionQuality: 0.8) else {
            throw GeminiError.badImage
        }

        // Walk the Flash family until one model returns objects. 503
        // "overloaded" / 429 / 404 / empty arrays each just advance the
        // chain; only when EVERY model fails do we surface the last error
        // (or "found nothing" if at least one genuinely returned empty).
        var lastError: GeminiError? = nil
        var sawGenuineEmpty = false
        for candidate in candidateModels {
            do {
                let detections = try await detectOnce(jpeg: jpeg, key: key, model: candidate)
                if !detections.isEmpty { return detections }
                sawGenuineEmpty = true
            } catch let error as GeminiError {
                lastError = error
            } catch {
                lastError = .network
            }
        }
        if sawGenuineEmpty { return [] }
        throw lastError ?? .emptyResponse
    }

    private static func detectOnce(jpeg: Data, key: String,
                                   model: String) async throws -> [DetectedObjectInfo] {
        let request = try makeDetectRequest(jpeg: jpeg, key: key, model: model)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GeminiError.network
        }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw GeminiError.http(http.statusCode)
        }
        guard let text = candidateText(from: data) else { throw GeminiError.emptyResponse }
        return parseDetections(jsonText: text)
    }

    /// Build the generateContent request — split out so tests can assert the
    /// exact request shape without network.
    static func makeDetectRequest(jpeg: Data, key: String,
                                  model: String) throws -> URLRequest {
        let prompt = """
        Detect every distinct physical object in this photo of a space in \
        someone's home. Each label is a short specific name (e.g. "blue \
        ceramic mug", never generic like "object"). box_2d is \
        [ymin, xmin, ymax, xmax] normalized to 0-1000. Include at most 20 of \
        the most prominent objects. Do not include walls, floors, or the room \
        itself.
        """

        var generationConfig: [String: Any] = [
            "responseMimeType": "application/json",
            // Forces the reply to be a BARE JSON array of {label, box_2d} —
            // without this, the model often wraps the array in an object
            // ({"objects": [...]}), which previously parsed to zero results
            // and silently fell back to the on-device scan.
            "responseSchema": [
                "type": "ARRAY",
                "items": [
                    "type": "OBJECT",
                    "properties": [
                        "label": ["type": "STRING"],
                        "box_2d": ["type": "ARRAY", "items": ["type": "INTEGER"]],
                    ],
                    "required": ["label", "box_2d"],
                ],
            ],
            "temperature": 0.2,
        ]
        // Spatial tasks are better (and much faster) without thinking; the
        // knob only exists on 2.5-series models.
        if model.hasPrefix("gemini-2.5") {
            generationConfig["thinkingConfig"] = ["thinkingBudget": 0]
        }

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["inline_data": ["mime_type": "image/jpeg",
                                     "data": jpeg.base64EncodedString()]],
                    ["text": prompt],
                ]
            ]],
            "generationConfig": generationConfig,
        ]

        var request = URLRequest(
            url: URL(string: "\(endpointBase)/v1beta/models/\(model):generateContent")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        // Short enough that walking the whole model chain stays tolerable.
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Response parsing (pure, unit-tested)

    /// Pull the first candidate's concatenated text parts out of a
    /// `generateContent` response body.
    static func candidateText(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else { return nil }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        return text.isEmpty ? nil : text
    }

    /// Parse the model's JSON array of {label, box_2d:[ymin,xmin,ymax,xmax]}
    /// (0–1000) into normalized-0..1 `DetectedObjectInfo` boxes. Lenient:
    /// strips markdown code fences, unwraps an object-wrapped array, skips
    /// malformed entries, clamps coordinates, drops degenerate boxes, caps
    /// the count.
    static func parseDetections(jsonText: String) -> [DetectedObjectInfo] {
        var text = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }
        // Accept a bare array, or an object that wraps one (the model
        // sometimes returns {"objects": [...]} despite instructions).
        let array: [[String: Any]]
        if let direct = root as? [[String: Any]] {
            array = direct
        } else if let dict = root as? [String: Any],
                  let wrapped = dict.values.compactMap({ $0 as? [[String: Any]] }).first {
            array = wrapped
        } else {
            return []
        }

        var results: [DetectedObjectInfo] = []
        for entry in array.prefix(25) {
            guard let label = entry["label"] as? String,
                  !label.trimmingCharacters(in: .whitespaces).isEmpty,
                  let box = entry["box_2d"] as? [Any], box.count == 4 else { continue }
            let nums = box.compactMap { ($0 as? NSNumber)?.floatValue }
            guard nums.count == 4 else { continue }
            let yMin = min(max(nums[0] / 1000, 0), 1)
            let xMin = min(max(nums[1] / 1000, 0), 1)
            let yMax = min(max(nums[2] / 1000, 0), 1)
            let xMax = min(max(nums[3] / 1000, 0), 1)
            let w = xMax - xMin, h = yMax - yMin
            guard w > 0.005, h > 0.005 else { continue }
            results.append(DetectedObjectInfo(
                boundingBox: Rectangle(x: xMin, y: yMin, width: w, height: h),
                label: label,
                confidence: 0.99))
        }
        return results
    }
}
