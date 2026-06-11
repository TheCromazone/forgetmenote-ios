import SwiftUI

/// V3 first-launch Welcome — port of WelcomeScreen in screens-home.jsx.
///
/// Cream-to-accent-bg gradient, scattered flower marks at varying opacities
/// and sizes, big serif "Remember where things *live*." headline, pill
/// CTA buttons.
struct V3WelcomeScreen: View {
    let palette: V3Palette
    var onStart: () -> Void
    var onSkip: () -> Void

    // Scatter positions matching the JSX original (relative coords).
    private let scatter: [(x: Double, y: Double, size: CGFloat, opacity: Double)] = [
        (0.14, 0.12, 22, 0.5),
        (0.82, 0.08, 16, 0.4),
        (0.70, 0.22, 28, 0.6),
        (0.08, 0.34, 18, 0.5),
        (0.88, 0.46, 14, 0.4),
        (0.20, 0.70, 20, 0.4),
        (0.76, 0.78, 24, 0.5),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [palette.paper, palette.accentBg],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    ForEach(scatter.indices, id: \.self) { i in
                        FlowerMark(size: scatter[i].size,
                                   color: palette.accent,
                                   pollen: palette.pollen)
                            .opacity(scatter[i].opacity)
                            .position(
                                x: geo.size.width * scatter[i].x,
                                y: geo.size.height * scatter[i].y
                            )
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()
                FlowerMark(size: 84, color: palette.accent, pollen: palette.pollen)
                    .padding(.bottom, 32)

                VStack(spacing: 0) {
                    Text("Remember")
                        .font(V3Font.display(48))
                        .foregroundStyle(palette.ink)
                        .tracking(-1.0)
                    HStack(spacing: 0) {
                        Text("where things ")
                            .font(V3Font.display(48))
                            .foregroundStyle(palette.ink)
                            .tracking(-1.0)
                        Text("live")
                            .font(V3Font.display(48, italic: true))
                            .italic()
                            .foregroundStyle(palette.accent)
                            .tracking(-1.0)
                        Text(".")
                            .font(V3Font.display(48))
                            .foregroundStyle(palette.ink)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 18)

                Text("Snap a photo, draw a circle. ForgetMeNote keeps track so you don't have to.")
                    .font(.system(size: 16))
                    .foregroundStyle(palette.ink2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 44)
                Spacer()

                VStack(spacing: 10) {
                    Button(action: onStart) {
                        Text("Start remembering")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(palette.accent, in: Capsule())
                            .shadow(color: palette.accent.opacity(0.33), radius: 12, y: 6)
                    }
                    .accessibilityIdentifier("v3-welcome-start")
                    Button(action: onSkip) {
                        Text("I've used it before")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(palette.ink2)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .accessibilityIdentifier("v3-welcome-skip")
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
            .padding(.top, 80)
        }
    }
}
