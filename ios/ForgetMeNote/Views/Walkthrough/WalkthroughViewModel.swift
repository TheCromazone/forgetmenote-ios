import SwiftUI
import Observation

/// On-screen targets the walkthrough can highlight via spotlight cutout.
/// `MainScreen` reports the on-screen `CGRect` of each target via
/// `WalkthroughBoundsPreferenceKey` so the overlay knows where to punch its
/// hole.
enum WalkthroughTarget: String, CaseIterable, Hashable {
    case addButton       // toolbar + button (top-right)
    case menuButton      // toolbar ☰ menu (top-left)
    case firstCard       // first card in the root carousel
}

/// One step in the walkthrough flow.
enum WalkthroughStep: Equatable {
    case welcome
    case spotlight(target: WalkthroughTarget, tooltip: String, isLongPress: Bool = false)
    case simulated(kind: SimulatedKind, tooltip: String)

    enum SimulatedKind: String, Equatable {
        case camera
        case cameraSubspace
        case regionDraw
        case subspacePopin
        case swipeDelete
    }
}

/// Drives the walkthrough overlay. Persists "has completed" in `UserDefaults`
/// so we only auto-show on first launch. Exposes `start()` / `nextStep()` /
/// `skip()` for the UI to drive.
///
/// Port of Android `WalkthroughViewModel.kt`.
@Observable
final class WalkthroughViewModel {
    private static let kCompletedKey = "walkthrough_completed_v1"

    /// All steps in order. Index 0 is Welcome; subsequent indices are the
    /// "overlay" steps counted in the progress indicator.
    static let steps: [WalkthroughStep] = [
        .welcome,
        .spotlight(target: .menuButton,
                   tooltip: "Use ☰ for Settings, Help, and to add Rooms (no photo)."),
        .spotlight(target: .addButton,
                   tooltip: "Tap + to add a new Space from camera. Long-press for Gallery."),
        .simulated(kind: .camera,
                   tooltip: "Snap a photo of the area you want to remember — a room, a shelf, a drawer."),
        .simulated(kind: .regionDraw,
                   tooltip: "Inside a parent Space, drag a rectangle to mark a child sub-space."),
        .simulated(kind: .subspacePopin,
                   tooltip: "Your sub-space appears in the tree and overlaid on the parent photo."),
        .spotlight(target: .firstCard,
                   tooltip: "Pull down to search by name, tag, or note. Long-press a row for rename / mark-updated / delete.",
                   isLongPress: true),
    ]

    /// Index into `steps`. 0 = Welcome.
    var stepIndex: Int = 0
    /// Whether the overlay is currently shown.
    var isActive: Bool = false
    /// Bounds map populated by `MainScreen` via PreferenceKey.
    var targetBounds: [WalkthroughTarget: CGRect] = [:]

    /// Total number of overlay steps for the "X / Y" progress label
    /// (excludes the Welcome card).
    var overlayStepCount: Int { Self.steps.count - 1 }

    /// 1-based step number for the progress label, or 0 on Welcome.
    var overlayStepNum: Int { max(stepIndex, 1) }

    /// Convenience accessor for the current step.
    var currentStep: WalkthroughStep { Self.steps[stepIndex] }

    func start() {
        stepIndex = 0
        isActive = true
    }

    func nextStep() {
        if stepIndex < Self.steps.count - 1 {
            stepIndex += 1
        } else {
            finish()
        }
    }

    func prevStep() {
        // Never go back to Welcome (step 0) — minimum reachable step is 1.
        if stepIndex > 1 { stepIndex -= 1 }
    }

    func skip() {
        isActive = false
        markCompleted(true)
    }

    func finish() {
        isActive = false
        markCompleted(true)
    }

    /// Reset completion flag and start over (called from Settings).
    func restart() {
        markCompleted(false)
        start()
    }

    func isCompleted() -> Bool {
        UserDefaults.standard.bool(forKey: Self.kCompletedKey)
    }

    func reportBounds(_ target: WalkthroughTarget, _ rect: CGRect) {
        // Only assign if it actually changed (avoids needless re-renders).
        if targetBounds[target] != rect {
            targetBounds[target] = rect
        }
    }

    private func markCompleted(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Self.kCompletedKey)
    }
}

// MARK: - PreferenceKey for reporting target bounds

/// PreferenceKey carries `(target, rect)` entries up the view hierarchy so the
/// `WalkthroughOverlay` can read them.
struct WalkthroughBoundsPreferenceKey: PreferenceKey {
    static var defaultValue: [WalkthroughTarget: CGRect] = [:]
    static func reduce(value: inout [WalkthroughTarget: CGRect],
                       nextValue: () -> [WalkthroughTarget: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    /// Attach to any view you want the walkthrough to spotlight. Reports the
    /// view's bounds (in global coords) via PreferenceKey.
    func walkthroughTarget(_ target: WalkthroughTarget) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: WalkthroughBoundsPreferenceKey.self,
                    value: [target: geo.frame(in: .global)]
                )
            }
        )
    }
}
