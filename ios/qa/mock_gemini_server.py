#!/usr/bin/env python3
"""Local mock of the Gemini generateContent endpoint for Maestro E2E runs.

The app is pointed here via the `-v3_gemini_endpoint http://127.0.0.1:8765`
launch argument (UserDefaults argument domain), so the FULL in-app pipeline —
request building, HTTP, response parsing, overlay rendering, status message —
runs for real; only Google's server is substituted.

Usage:  python3 qa/mock_gemini_server.py   (listens on 127.0.0.1:8765)
"""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

CANNED = {
    "candidates": [{
        "content": {"parts": [{
            "text": json.dumps([
                {"label": "demo mug",  "box_2d": [120, 120, 420, 420]},
                {"label": "demo book", "box_2d": [500, 480, 900, 880]},
            ])
        }]}
    }]
}


class Handler(BaseHTTPRequestHandler):
    def _reply(self, payload):
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):  # validateKey: GET model metadata -> 200
        self._reply({"name": "models/gemini-2.5-flash"})

    def do_POST(self):  # detect: generateContent -> canned detections
        self.rfile.read(int(self.headers.get("Content-Length", 0)))
        # The PRIMARY model plays "overloaded" (the real free-tier 503 the
        # user hit) so the E2E proves the app's model-fallback chain: it must
        # advance to flash-lite and still render results.
        if "gemini-2.5-flash:" in self.path:
            body = json.dumps({"error": {"code": 503, "status": "UNAVAILABLE",
                                         "message": "The model is overloaded."}}).encode()
            self.send_response(503)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self._reply(CANNED)

    def log_message(self, fmt, *args):
        print(f"[mock-gemini] {fmt % args}", flush=True)


if __name__ == "__main__":
    print("[mock-gemini] listening on 127.0.0.1:8765", flush=True)
    HTTPServer(("127.0.0.1", 8765), Handler).serve_forever()
