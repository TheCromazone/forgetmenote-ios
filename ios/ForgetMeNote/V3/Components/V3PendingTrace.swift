import Foundation

/// One-shot hand-off of a freehand `TracePath` from V3SpaceScreen's
/// draw-a-spot tool to `V3CreateSubScreen`. `Route.v3CreateSub` can't carry it:
/// the enum is shared with the read-only v2 `RootView` and v4 `V4RootView`
/// switches, whose exhaustive `.v3CreateSub(let …)` destructures would break
/// if the case grew an associated value. The drawer stashes the trace here
/// right before pushing the route; CreateSub consumes it on appear.
enum V3PendingTrace {
    private static var trace: TracePath?

    static func stash(_ t: TracePath) { trace = t }

    /// Returns the stashed trace and clears it, so a later CreateSub opened
    /// without a fresh trace never inherits a stale outline.
    static func consume() -> TracePath? {
        defer { trace = nil }
        return trace
    }
}
