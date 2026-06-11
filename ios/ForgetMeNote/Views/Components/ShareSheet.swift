import SwiftUI
import UIKit

/// SwiftUI wrapper around UIActivityViewController for presenting the
/// system share sheet — used to hand a freshly written export zip to AirDrop,
/// Files, Messages, etc.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController,
                                context: Context) { }
}
