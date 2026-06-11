import SwiftUI

struct V4Walkthrough: View {
    var onFinish: () -> Void

    @State private var step = 0

    private struct Page {
        let icon: String
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(
            icon: "square.grid.2x2.fill",
            title: "Start with rooms",
            body: "Home is your physical map. Add rooms first, then place shelves, drawers, bins, and objects inside them."
        ),
        Page(
            icon: "camera.fill",
            title: "Capture where things live",
            body: "Use the camera button to add a photo to a room. V4 keeps the capture action close to the dock."
        ),
        Page(
            icon: "viewfinder.circle.fill",
            title: "Let vision make boxes",
            body: "Open a photo and run object detection. The app suggests boxes and labels, then you choose what becomes a place."
        ),
        Page(
            icon: "trash.fill",
            title: "Prune the map",
            body: "Delete rooms or places from Home, Find, or inside a room when the real world changes."
        )
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.64)
                .ignoresSafeArea()
                .onTapGesture { }
                .accessibilityIdentifier("v4-walkthrough")

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: pages[step].icon)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color(hex: 0x07101E))
                        .frame(width: 74, height: 74)
                        .background(V4.pollen, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.36), lineWidth: 1))

                    Text(pages[step].title)
                        .font(V4.title(27))
                        .foregroundStyle(V4.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(pages[step].body)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(V4.ink2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 7) {
                        ForEach(pages.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == step ? V4.cyan : V4.line)
                                .frame(width: index == step ? 22 : 7, height: 7)
                                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: step)
                        }
                    }
                    .padding(.top, 2)

                    HStack(spacing: 12) {
                        if step > 0 {
                            Button("Back") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { step -= 1 }
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(V4.ink2)
                            .accessibilityIdentifier("v4-tour-back")
                        }

                        Spacer()

                        Button(step == pages.count - 1 ? "Done" : "Next") {
                            if step == pages.count - 1 {
                                onFinish()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { step += 1 }
                            }
                        }
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Color(hex: 0x07101E))
                        .padding(.horizontal, 24)
                        .frame(height: 46)
                        .background(V4.cyan, in: Capsule())
                        .accessibilityIdentifier("v4-tour-next")
                    }
                    .padding(.top, 4)
                }
                .padding(22)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.32), radius: 26, y: 14)

                Button("Skip") { onFinish() }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 16)
                    .accessibilityIdentifier("v4-tour-skip")

                Spacer()
            }
        }
        .accessibilityIdentifier("v4-walkthrough")
    }
}
