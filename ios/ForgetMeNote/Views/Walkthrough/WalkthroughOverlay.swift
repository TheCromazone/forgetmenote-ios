import SwiftUI

/// Full-screen overlay that walks the user through the app's core concepts.
/// Renders a dark veil with a spotlight cutout for "spotlight" steps, an
/// illustration block for "simulated" steps, and a tooltip card with
/// Next/Back/Skip controls. Port of Android `WalkthroughOverlay.kt`.
struct WalkthroughOverlay: View {
    let viewModel: WalkthroughViewModel

    private let overlayAlpha: Double = 0.78
    private let spotlightPadding: CGFloat = 14
    private let tooltipGap: CGFloat = 16

    var body: some View {
        let step = viewModel.currentStep
        switch step {
        case .welcome:
            WelcomeStep(
                onStart: { viewModel.nextStep() },
                onSkip:  { viewModel.skip() }
            )

        case .spotlight(let target, let tooltip, let isLongPress):
            SpotlightStep(
                target: target,
                tooltip: tooltip,
                isLongPress: isLongPress,
                bounds: viewModel.targetBounds[target],
                stepNum: viewModel.overlayStepNum,
                stepCount: viewModel.overlayStepCount,
                overlayAlpha: overlayAlpha,
                spotlightPadding: spotlightPadding,
                tooltipGap: tooltipGap,
                onNext: { viewModel.nextStep() },
                onBack: viewModel.stepIndex > 1 ? { viewModel.prevStep() } : nil,
                onSkip: { viewModel.skip() }
            )

        case .simulated(let kind, let tooltip):
            SimulatedStep(
                kind: kind,
                tooltip: tooltip,
                stepNum: viewModel.overlayStepNum,
                stepCount: viewModel.overlayStepCount,
                overlayAlpha: overlayAlpha,
                onNext: { viewModel.nextStep() },
                onBack: { viewModel.prevStep() },
                onSkip: { viewModel.skip() }
            )
        }
    }
}

// MARK: - Welcome

private struct WelcomeStep: View {
    let onStart: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.82)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("📝")
                    .font(.system(size: 48))
                Text("Welcome to ForgetMeNote")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Take a quick tour to see how to organize your photos into Rooms and Spaces.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: onStart) {
                    Text("Start Tour")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
                .accessibilityIdentifier("walkthrough-start")

                Button("Skip", action: onSkip)
                    .accessibilityIdentifier("walkthrough-skip")
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Spotlight

private struct SpotlightStep: View {
    let target: WalkthroughTarget
    let tooltip: String
    let isLongPress: Bool
    let bounds: CGRect?
    let stepNum: Int
    let stepCount: Int
    let overlayAlpha: Double
    let spotlightPadding: CGFloat
    let tooltipGap: CGFloat
    let onNext: () -> Void
    let onBack: (() -> Void)?
    let onSkip: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Spotlight cutout via Canvas + destination-out blend mode.
                Canvas { ctx, size in
                    var ctx = ctx
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .color(.black.opacity(overlayAlpha))
                    )
                    if let b = bounds {
                        let rect = b.insetBy(dx: -spotlightPadding, dy: -spotlightPadding)
                        ctx.blendMode = .destinationOut
                        ctx.fill(
                            Path(roundedRect: rect, cornerRadius: 16),
                            with: .color(.black)
                        )
                    }
                }
                .ignoresSafeArea()

                // Tooltip pinned below the spotlight (or 240 pt from top if no bounds).
                let tooltipY: CGFloat = {
                    if let b = bounds {
                        return b.maxY + spotlightPadding + tooltipGap
                    }
                    return 240
                }()

                VStack(alignment: .leading, spacing: 12) {
                    if isLongPress {
                        // Show a fake context-menu floater hinting at the
                        // long-press options.
                        FakeContextMenuFloat()
                    }
                    TooltipCard(
                        text: tooltip,
                        stepNum: stepNum,
                        stepCount: stepCount,
                        onNext: onNext,
                        onBack: onBack,
                        onSkip: onSkip
                    )
                }
                .padding(.horizontal, 20)
                .frame(width: geo.size.width, alignment: .leading)
                .offset(y: min(tooltipY, geo.size.height - 200))
            }
        }
    }
}

private struct FakeContextMenuFloat: View {
    private let items: [(String, String)] = [
        ("pencil",                "Rename"),
        ("exclamationmark.circle","Mark Updated"),
        ("trash",                 "Delete"),
    ]
    var body: some View {
        VStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    Image(systemName: items[i].0)
                    Text(items[i].1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                if i < items.count - 1 { Divider() }
            }
        }
        .frame(width: 200)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 8)
    }
}

// MARK: - Simulated

private struct SimulatedStep: View {
    let kind: WalkthroughStep.SimulatedKind
    let tooltip: String
    let stepNum: Int
    let stepCount: Int
    let overlayAlpha: Double
    let onNext: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(overlayAlpha)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()
                Group {
                    switch kind {
                    case .camera:         CameraViewfinder(content: AnyView(BookshelfPhoto()))
                    case .cameraSubspace: CameraViewfinder(content: AnyView(ThreeBooksPhoto()))
                    case .regionDraw:     RegionDrawSimulation()
                    case .subspacePopin:  SubspacePopinSimulation()
                    case .swipeDelete:    SwipeDeleteSimulation()
                    }
                }
                .frame(maxWidth: .infinity)

                TooltipCard(
                    text: tooltip,
                    stepNum: stepNum,
                    stepCount: stepCount,
                    onNext: onNext,
                    onBack: onBack,
                    onSkip: onSkip
                )
                .padding(.horizontal, 24)
                Spacer()
            }
        }
    }
}

// MARK: - Tooltip card

private struct TooltipCard: View {
    let text: String
    let stepNum: Int
    let stepCount: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text)
                .font(.body)
                .foregroundStyle(.white)

            HStack {
                Button("Skip", action: onSkip)
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityIdentifier("walkthrough-skip")
                Spacer()
                Text("\(stepNum) / \(stepCount)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.trailing, 6)
                if let onBack = onBack {
                    Button("Back", action: onBack)
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .accessibilityIdentifier("walkthrough-back")
                }
                Button(stepNum == stepCount ? "Done" : "Next", action: onNext)
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityIdentifier("walkthrough-next")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.accentColor)
        )
    }
}

// MARK: - Demo illustration helpers

/// 8-book bookshelf canvas — used as the "parent photo" in the camera and
/// region-draw simulations. Books touch each other (no gaps), with thin
/// highlight + shadow lines down each spine so it reads as books, not bars.
private struct BookshelfPhoto: View {
    private let bookColors: [Color] = [
        Color(red: 0.55, green: 0.16, blue: 0.16),  // deep red
        Color(red: 0.20, green: 0.36, blue: 0.55),  // navy
        Color(red: 0.62, green: 0.50, blue: 0.20),  // mustard
        Color(red: 0.40, green: 0.25, blue: 0.55),  // purple
        Color(red: 0.22, green: 0.50, blue: 0.32),  // forest green
        Color(red: 0.74, green: 0.56, blue: 0.37),  // tan
        Color(red: 0.55, green: 0.16, blue: 0.16),  // deep red
        Color(red: 0.30, green: 0.30, blue: 0.30),  // charcoal
    ]
    private let bookHeights: [CGFloat] = [0.85, 0.62, 0.92, 0.55, 0.78, 0.68, 0.88, 0.58]

    var body: some View {
        Canvas { ctx, size in
            // Backboard
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(Color(red: 0.13, green: 0.08, blue: 0.04)))
            let count = bookColors.count
            let bookWidth = size.width / CGFloat(count)
            let shelfY = size.height * 0.88
            for i in 0..<count {
                let bh = size.height * bookHeights[i] * 0.85
                let bx = bookWidth * CGFloat(i)
                // Book body
                let body = CGRect(x: bx, y: shelfY - bh, width: bookWidth, height: bh)
                ctx.fill(Path(body), with: .color(bookColors[i]))
                // Left highlight (1pt) — gives the spine a top edge
                let hi = CGRect(x: bx, y: shelfY - bh, width: 1, height: bh)
                ctx.fill(Path(hi), with: .color(.white.opacity(0.18)))
                // Right shadow (1pt) — separates from the next book
                let sh = CGRect(x: bx + bookWidth - 1, y: shelfY - bh, width: 1, height: bh)
                ctx.fill(Path(sh), with: .color(.black.opacity(0.45)))
                // Title band — a small horizontal stripe near the top of each spine
                let band = CGRect(x: bx + 2, y: shelfY - bh * 0.78,
                                  width: bookWidth - 4, height: 2)
                ctx.fill(Path(band), with: .color(.white.opacity(0.25)))
            }
            // Shelf strip
            let shelfRect = CGRect(x: 0, y: shelfY, width: size.width, height: 6)
            ctx.fill(Path(shelfRect),
                     with: .color(Color(red: 0.36, green: 0.23, blue: 0.12)))
        }
    }
}

/// 3-book zoomed-in shelf segment — used as the "sub-space photo".
private struct ThreeBooksPhoto: View {
    private let bookColors: [Color] = [
        Color(red: 0.55, green: 0.16, blue: 0.16),
        Color(red: 0.20, green: 0.36, blue: 0.55),
        Color(red: 0.62, green: 0.50, blue: 0.20),
    ]
    private let bookHeights: [CGFloat] = [0.85, 0.62, 0.92]

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(Color(red: 0.13, green: 0.08, blue: 0.04)))
            let count = bookColors.count
            let bookWidth = size.width / CGFloat(count)
            let shelfY = size.height * 0.88
            for i in 0..<count {
                let bh = size.height * bookHeights[i] * 0.85
                let bx = bookWidth * CGFloat(i)
                let body = CGRect(x: bx, y: shelfY - bh, width: bookWidth, height: bh)
                ctx.fill(Path(body), with: .color(bookColors[i]))
                let hi = CGRect(x: bx, y: shelfY - bh, width: 1, height: bh)
                ctx.fill(Path(hi), with: .color(.white.opacity(0.18)))
                let sh = CGRect(x: bx + bookWidth - 1, y: shelfY - bh, width: 1, height: bh)
                ctx.fill(Path(sh), with: .color(.black.opacity(0.45)))
                let band = CGRect(x: bx + 2, y: shelfY - bh * 0.78,
                                  width: bookWidth - 4, height: 2)
                ctx.fill(Path(band), with: .color(.white.opacity(0.25)))
            }
            let shelfRect = CGRect(x: 0, y: shelfY, width: size.width, height: 6)
            ctx.fill(Path(shelfRect),
                     with: .color(Color(red: 0.36, green: 0.23, blue: 0.12)))
        }
    }
}

/// Camera viewfinder frame: corner brackets + center focus reticle, with a
/// shutter flash animation, wrapped around `content`.
private struct CameraViewfinder: View {
    let content: AnyView

    @State private var focusAlpha: Double = 1.0
    @State private var shutterAlpha: Double = 1.0

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                content
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(shutterAlpha)

                // Corner brackets
                ForEach(0..<4, id: \.self) { idx in
                    CornerBracket(corner: idx)
                }

                // Center focus reticle (pulses)
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(red: 1.0, green: 0.8, blue: 0.27).opacity(focusAlpha), lineWidth: 2)
                    .frame(width: 40, height: 40)
            }
            .frame(height: 180)

            // Shutter button
            ZStack {
                Circle().fill(Color.white.opacity(0.9))
                Circle().stroke(Color.gray.opacity(0.3), lineWidth: 3).padding(4)
            }
            .frame(width: 48, height: 48)
        }
        .padding(.horizontal, 16)
        .onAppear {
            // Focus pulse
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                focusAlpha = 0.25
            }
            // Shutter flash on a 2.4 s loop
            Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    withAnimation(.easeOut(duration: 0.2)) { shutterAlpha = 0.05 }
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    withAnimation(.easeIn(duration: 0.3)) { shutterAlpha = 1.0 }
                    try? await Task.sleep(nanoseconds: 850_000_000)
                }
            }
        }
    }
}

private struct CornerBracket: View {
    let corner: Int   // 0=TL, 1=TR, 2=BL, 3=BR

    var body: some View {
        GeometryReader { geo in
            let size: CGFloat = 18
            let x: CGFloat = (corner == 1 || corner == 3) ? geo.size.width - size - 8 : 8
            let y: CGFloat = (corner == 2 || corner == 3) ? geo.size.height - size - 8 : 8
            Canvas { ctx, _ in
                var path = Path()
                let isLeft = corner == 0 || corner == 2
                let isTop  = corner == 0 || corner == 1
                let x0: CGFloat = isLeft ? 0 : size
                let x1: CGFloat = size * 0.5
                let y0: CGFloat = isTop ? 0 : size
                let y1: CGFloat = size * 0.5
                path.move(to: CGPoint(x: x0, y: y0))
                path.addLine(to: CGPoint(x: x1, y: y0))
                path.move(to: CGPoint(x: x0, y: y0))
                path.addLine(to: CGPoint(x: x0, y: y1))
                ctx.stroke(path, with: .color(.white), lineWidth: 2)
            }
            .frame(width: size, height: size)
            .offset(x: x, y: y)
        }
    }
}

/// Animated dashed rectangle that grows over the bookshelf, mimicking the user
/// dragging out a sub-space region.
private struct RegionDrawSimulation: View {
    @State private var progress: CGFloat = 0
    private let subspaceColor = Color(red: 0.49, green: 0.42, blue: 0.97)

    var body: some View {
        ZStack(alignment: .topLeading) {
            BookshelfPhoto()
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            GeometryReader { geo in
                let left = geo.size.width * 0.03
                let top = geo.size.height * 0.18
                let maxW = geo.size.width * 0.37
                let maxH = geo.size.height * 0.50
                let w = maxW * progress
                let h = maxH * progress
                if w > 0 && h > 0 {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [12, 6]))
                        .foregroundStyle(subspaceColor)
                        .frame(width: w, height: h)
                        .offset(x: left, y: top)
                }
            }
            .frame(height: 180)

            Text("Sub-space region")
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(subspaceColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .offset(x: 8, y: 25)
        }
        .padding(.horizontal, 16)
        .onAppear { runLoop() }
    }

    private func runLoop() {
        Task { @MainActor in
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 1.2)) { progress = 1 }
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                withAnimation(.easeIn(duration: 0.4)) { progress = 0 }
                try? await Task.sleep(nanoseconds: 600_000_000)
            }
        }
    }
}

/// Bookshelf with a fixed sub-space rectangle, plus a card that pops in below
/// to represent the newly-created sub-space appearing in the tree.
private struct SubspacePopinSimulation: View {
    @State private var visible: Bool = false
    private let subspaceColor = Color(red: 0.49, green: 0.42, blue: 0.97)

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                BookshelfPhoto()
                    .frame(height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(subspaceColor, lineWidth: 2)
                        .frame(width: geo.size.width * 0.37,
                               height: geo.size.height * 0.50)
                        .offset(x: geo.size.width * 0.03, y: geo.size.height * 0.18)
                }
                .frame(height: 110)
            }

            if visible {
                HStack(spacing: 10) {
                    ThreeBooksPhoto()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    VStack(alignment: .leading) {
                        Text("Left shelf")
                            .font(.body.weight(.semibold))
                        Text("✓ Sub-space created")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .onAppear { runLoop() }
    }

    private func runLoop() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(.spring()) { visible = true }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation(.easeOut(duration: 0.3)) { visible = false }
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }
}

/// Animated row that swipes left to reveal a red Delete button.
private struct SwipeDeleteSimulation: View {
    @State private var offsetX: CGFloat = 0
    private let deleteWidth: CGFloat = 72

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button behind the row
            SwiftUI.Rectangle()
                .fill(Color.red)
                .frame(width: deleteWidth)
                .overlay(
                    Image(systemName: "trash")
                        .foregroundStyle(.white)
                        .font(.title2)
                )

            // Card sliding left
            HStack(spacing: 12) {
                BookshelfPhoto()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading) {
                    Text("Bookshelf")
                        .font(.body.weight(.semibold))
                    Text("3 sub-spaces")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 72)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .offset(x: offsetX)
        }
        .frame(height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .onAppear { runLoop() }
    }

    private func runLoop() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(.easeInOut(duration: 0.5)) { offsetX = -deleteWidth }
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                withAnimation(.easeInOut(duration: 0.35)) { offsetX = 0 }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }
}
