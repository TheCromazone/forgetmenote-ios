import SwiftUI

/// Full-screen pinch-to-zoom + drag-to-pan viewer. Presented modally over
/// `ImageDetailScreen` when the user wants to inspect a photo in detail.
///
/// Gesture composite mirrors the Android `ZoomableImageOverlay`:
/// - `MagnificationGesture` for pinch-zoom (1×..6×, clamped)
/// - `DragGesture` for pan (only effective when zoomed in)
/// - Double-tap to toggle 1× ↔ 2.5×
/// - Tap once to dismiss
/// - Close button (top-trailing)
struct ZoomableImageOverlay: View {
    let image: UIImage
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 6.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            // Pinch
                            MagnificationGesture()
                                .onChanged { value in
                                    let proposed = lastScale * value
                                    scale = max(minScale, min(maxScale, proposed))
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale <= minScale {
                                        // Snap back to centered/identity if
                                        // they fully zoomed back out.
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            scale = minScale
                                            lastScale = minScale
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                },
                            // Pan (only meaningful when scale > 1)
                            DragGesture()
                                .onChanged { value in
                                    guard scale > minScale else { return }
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if scale > minScale + 0.01 {
                                scale = minScale
                                lastScale = minScale
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }
                    .onTapGesture(count: 1) {
                        // Single tap dismisses only if not zoomed in
                        // (otherwise it'd be too easy to dismiss while
                        // exploring a zoomed photo).
                        if scale <= minScale + 0.01 { onDismiss() }
                    }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.85),
                                             Color.black.opacity(0.4))
                            .padding(16)
                    }
                    .accessibilityIdentifier("zoom-close")
                }
                Spacer()
            }
        }
        .statusBarHidden(true)
        .accessibilityIdentifier("zoom-overlay")
    }
}
