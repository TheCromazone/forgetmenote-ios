import SwiftUI
import UIKit

/// SwiftUI wrapper around `UIImagePickerController` for camera capture.
///
/// Chose `UIImagePickerController` over a full `AVCaptureSession` build-out for
/// Phase 2 because we want Apple's stock capture UI (flash toggle, retake, use-photo
/// confirmation) for free. A custom `AVCaptureSession`-backed view can replace this
/// in a later phase if we need on-screen object-detection overlays during capture.
///
/// Not available in the iOS Simulator — Simulator has no camera hardware.
struct CameraImagePicker: UIViewControllerRepresentable {
    /// JPEG-encoded photo data passed back when the user taps "Use Photo".
    var onPick: (Data) -> Void
    /// Called when the user cancels or capture fails.
    var onCancel: () -> Void

    static var isAvailable: Bool {
        // iOS Simulator reports `.camera` as available (it shows a fake
        // placeholder UI) but cannot actually capture a useful photo. Force
        // the gallery path on Simulator so the flow is testable.
        #if targetEnvironment(simulator)
        return false
        #else
        return UIImagePickerController.isSourceTypeAvailable(.camera)
        #endif
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (Data) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.9) else {
                onCancel()
                return
            }
            onPick(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onCancel()
        }
    }
}
