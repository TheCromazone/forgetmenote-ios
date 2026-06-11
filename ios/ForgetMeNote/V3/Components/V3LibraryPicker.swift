import SwiftUI
import PhotosUI

/// SwiftUI wrapper around `PHPickerViewController` for picking a single
/// existing image from the user's photo library and returning its JPEG
/// representation. Used by the V3 capture flow's "From library" option.
struct V3LibraryPicker: UIViewControllerRepresentable {
    /// Returns nil if the user cancelled or the asset couldn't be loaded.
    var onPick: (Data?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (Data?) -> Void
        init(onPick: @escaping (Data?) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController,
                    didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                onPick(nil)
                return
            }
            provider.loadObject(ofClass: UIImage.self) { [onPick] object, _ in
                let data = (object as? UIImage)?.jpegData(compressionQuality: 0.9)
                DispatchQueue.main.async { onPick(data) }
            }
        }
    }
}
