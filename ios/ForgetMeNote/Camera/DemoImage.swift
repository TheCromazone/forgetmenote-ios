import UIKit

/// Generates a deterministic test image for the "Insert demo Space" debug
/// action. Drawn at runtime so we don't ship bundled binary assets just for QA.
enum DemoImage {
    static func make(label: String) -> Data {
        let size = CGSize(width: 1024, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            // Background gradient: same Material 3 primary purple as the app's accent
            let colors = [UIColor(red: 0.40, green: 0.31, blue: 0.64, alpha: 1).cgColor,
                          UIColor(red: 0.25, green: 0.18, blue: 0.50, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: colors as CFArray, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: .zero, end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            // Centered label
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 96, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
            let textRect = CGRect(x: 0, y: size.height / 2 - 60,
                                  width: size.width, height: 120)
            (label as NSString).draw(in: textRect, withAttributes: attrs)
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }
}
