import SwiftUI

/// Multi-step guided tour shown over the app. Dimmed backdrop + a caption card
/// with progress dots and Back/Next/Skip. v3-only.
struct V3Walkthrough: View {
    let palette: V3Palette
    var onFinish: () -> Void

    @State private var step = 0

    private struct Page { let icon: String; let title: String; let body: String }
    private let pages: [Page] = [
        Page(icon: "square.grid.2x2.fill", title: "Your places",
             body: "Every room, shelf and drawer lives on the Home tab. Tap one to look inside."),
        Page(icon: "camera.fill", title: "Snap to remember",
             body: "Tap the camera button by the tab bar to photograph a space and add it."),
        Page(icon: "sparkles", title: "Find objects",
             body: "Open a photo and tap “Find objects” — the app outlines what it sees and lets you turn anything into a sub-spot."),
        Page(icon: "hand.tap.fill", title: "Tap to identify",
             body: "Not sure what something is? Tap it in a photo and a label pops up right there."),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { }
                // The walkthrough id lives on the (childless) dimmed backdrop,
                // NOT the outer ZStack — putting it on the container collapsed
                // the tour into one a11y element and hid the Skip/Next buttons.
                .accessibilityIdentifier("v3-walkthrough")

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: pages[step].icon)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 72, height: 72)
                        .background(palette.accentBg, in: Circle())

                    Text(pages[step].title)
                        .font(V3Font.headline(26))
                        .foregroundStyle(palette.ink)
                        .multilineTextAlignment(.center)
                    Text(pages[step].body)
                        .font(.system(size: 15))
                        .foregroundStyle(palette.ink2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        ForEach(pages.indices, id: \.self) { i in
                            Circle()
                                .fill(i == step ? palette.accent : palette.line)
                                .frame(width: 7, height: 7)
                        }
                    }
                    .padding(.top, 2)

                    HStack(spacing: 12) {
                        if step > 0 {
                            Button("Back") { withAnimation { step -= 1 } }
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(palette.ink2)
                                .accessibilityIdentifier("v3-tour-back")
                        }
                        Spacer()
                        Button(step == pages.count - 1 ? "Done" : "Next") {
                            if step == pages.count - 1 { onFinish() }
                            else { withAnimation { step += 1 } }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22).frame(height: 44)
                        .background(palette.accent, in: Capsule())
                        .accessibilityIdentifier("v3-tour-next")
                    }
                    .padding(.top, 4)
                }
                .padding(22)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)

                Button("Skip") { onFinish() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 16)
                    .accessibilityIdentifier("v3-tour-skip")
                Spacer()
            }
        }
        .accessibilityIdentifier("v3-walkthrough")
    }
}
