import UIKit

/// Tiny imperative haptics helper for v3. SwiftUI's `.sensoryFeedback`
/// (iOS 17) is preferred for declarative, state-driven feedback; this exists
/// for imperative call sites (inside `Task`/completion handlers) where a
/// view-state trigger is awkward. All calls hop to the main actor — UIKit
/// feedback generators must be used from the main thread.
enum V3Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        runOnMain {
            let gen = UIImpactFeedbackGenerator(style: style)
            gen.prepare()
            gen.impactOccurred()
        }
    }

    static func selection() {
        runOnMain {
            let gen = UISelectionFeedbackGenerator()
            gen.prepare()
            gen.selectionChanged()
        }
    }

    static func success() { notify(.success) }
    static func warning() { notify(.warning) }
    static func error()   { notify(.error) }

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        runOnMain {
            let gen = UINotificationFeedbackGenerator()
            gen.prepare()
            gen.notificationOccurred(type)
        }
    }

    private static func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() }
        else { DispatchQueue.main.async(execute: work) }
    }
}
