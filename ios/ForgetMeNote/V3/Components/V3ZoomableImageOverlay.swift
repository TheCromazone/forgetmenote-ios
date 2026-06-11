import SwiftUI

/// Full-screen pinch-to-zoom / drag-to-pan photo viewer — the v3 take on the
/// Android `ZoomableImageOverlay`. Double-tap toggles between fit and 2.5×;
/// pinch zooms freely (1×…5×); drag pans while zoomed; tap the backdrop or the
/// close button to dismiss.
struct V3ZoomableImageOverlay: View {
    let image: UIImage
    var title: String? = nil
    var onClose: () -> Void

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 5

    var body: some View {
        ZStack {
            Color.black.opacity(0.96).ignoresSafeArea()
                .onTapGesture { onClose() }

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(magnify.simultaneously(with: pan))
                .onTapGesture(count: 2) { toggleZoom() }
                .accessibilityIdentifier("v3-zoom-image")

            VStack {
                HStack {
                    if let title {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityIdentifier("v3-zoom-close")
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)
                Spacer()
                Text("Pinch or double-tap to zoom")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 40)
            }
        }
        .transition(.opacity)
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                scale = min(maxScale, max(minScale * 0.6, baseScale * v.magnification))
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    scale = min(maxScale, max(minScale, scale))
                    if scale <= minScale { offset = .zero; baseOffset = .zero }
                }
                baseScale = scale
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { v in
                guard scale > minScale else { return }
                offset = CGSize(width: baseOffset.width + v.translation.width,
                                height: baseOffset.height + v.translation.height)
            }
            .onEnded { _ in baseOffset = offset }
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if scale > minScale {
                scale = 1; baseScale = 1; offset = .zero; baseOffset = .zero
            } else {
                scale = 2.5; baseScale = 2.5
            }
        }
    }
}
