import Foundation

/// Single source of truth for the time-of-day greeting used by both
/// `V3HomeScreen` ("Good {evening}") and `V3YouScreen` (which previously
/// hardcoded "Good evening"). Returns just the period word; callers prefix
/// "Good ".
enum V3Greeting {
    /// e.g. "morning", "afternoon", "evening". `still up?` for the small hours.
    static func period(at date: Date = Date()) -> String {
        let h = Calendar.current.component(.hour, from: date)
        switch h {
        case ..<5:  return "still up?"
        case ..<12: return "morning"
        case ..<18: return "afternoon"
        default:    return "evening"
        }
    }

    /// Full "Good evening" style phrase (capitalized period for the small hours
    /// reads oddly, so only prefix "Good " for the day periods).
    static func phrase(at date: Date = Date()) -> String {
        let p = period(at: date)
        return p == "still up?" ? "still up?" : "Good \(p)"
    }
}
