import SwiftUI

/// Guided setup for the free Gemini enhanced scan. Walks the user through the
/// whole thing in-app: opens Google AI Studio's key page in the browser,
/// offers one-tap paste from the clipboard, verifies the key LIVE against the
/// API (cheap metadata GET, no quota), and only saves once it actually works.
/// The on-device Apple Vision scan always remains the no-setup default.
struct V3GeminiKeySheet: View {
    @Environment(\.v3Palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @AppStorage("v3_gemini_api_key") private var savedKey: String = ""
    @AppStorage("v3_gemini_enabled") private var geminiEnabled: Bool = true

    @State private var draftKey: String = ""
    @State private var phase: Phase = .idle
    @FocusState private var keyFocused: Bool

    enum Phase: Equatable { case idle, verifying, success, failed }

    private var hasWorkingKey: Bool { !savedKey.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                handle
                header
                explainer
                steps
                keyField
                verifyButton
                statusLine
                if hasWorkingKey { removeButton }
                Spacer(minLength: 28)
            }
            .padding(.horizontal, 22)
        }
        .background(palette.paper.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(palette.paper)
        .presentationCornerRadius(24)
        .onAppear { draftKey = savedKey }
    }

    // MARK: - Pieces

    @ViewBuilder private var handle: some View {
        HStack {
            Spacer()
            Capsule().fill(palette.line).frame(width: 44, height: 5)
            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    @ViewBuilder private var header: some View {
        HStack {
            (Text("Better scans")
                .font(V3Font.headline(30)).foregroundStyle(palette.ink) +
             Text(" ✦")
                .font(V3Font.headline(30)).foregroundStyle(palette.accent))
                .tracking(-0.5)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.ink2)
                    .frame(width: 34, height: 34)
                    .background(palette.surface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("v3-gemini-close")
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder private var explainer: some View {
        Text("Your phone already finds objects on its own — free and private. Add a free Gemini API key from Google AI Studio and scans get noticeably smarter: more objects, better names. Takes about two minutes, no credit card, no billing setup.")
            .font(.system(size: 14))
            .foregroundStyle(palette.ink2)
            .lineSpacing(3)
            .padding(.bottom, 18)
    }

    @ViewBuilder private var steps: some View {
        VStack(spacing: 10) {
            stepRow(number: 1,
                    title: "Get your free key",
                    detail: "Opens aistudio.google.com/apikey — sign in with any Google account and tap “Create API key”. It starts with “AIza”.") {
                Button {
                    V3Haptics.impact(.light)
                    openURL(V3GeminiVision.keyConsoleURL)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 13, weight: .bold))
                        Text("Open")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(palette.paper)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(palette.ink, in: Capsule())
                }
                .buttonStyle(.v3Pressable)
                .accessibilityIdentifier("v3-gemini-get-key")
            }
            stepRow(number: 2,
                    title: "Copy the key",
                    detail: "Tap the copy button next to your new key.") { EmptyView() }
            stepRow(number: 3,
                    title: "Paste it below",
                    detail: "We'll check it works before saving.") {
                Button {
                    if let clip = UIPasteboard.general.string {
                        V3Haptics.impact(.light)
                        draftKey = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                        phase = .idle
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 13, weight: .bold))
                        Text("Paste")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(palette.accentBg, in: Capsule())
                }
                .buttonStyle(.v3Pressable)
                .accessibilityIdentifier("v3-gemini-paste")
            }
        }
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func stepRow(number: Int, title: String, detail: String,
                         @ViewBuilder action: () -> some View) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(V3Font.headline(17))
                .foregroundStyle(palette.accent)
                .frame(width: 30, height: 30)
                .background(palette.accentBg, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.ink)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.ink3)
            }
            Spacer()
            action()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    @ViewBuilder private var keyField: some View {
        TextField("AIza…", text: $draftKey)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(palette.ink)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($keyFocused)
            .onChange(of: draftKey) { _, _ in phase = .idle }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(phase == .failed ? palette.danger.opacity(0.5) : palette.line,
                            lineWidth: 1)
            )
            .accessibilityIdentifier("v3-gemini-key-field")
            .padding(.bottom, 10)
    }

    @ViewBuilder private var verifyButton: some View {
        let draft = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
        Button(action: verifyAndSave) {
            HStack(spacing: 8) {
                if phase == .verifying {
                    ProgressView().controlSize(.small).tint(.white)
                    Text("Checking…")
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Verify & turn on ✦")
                }
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(palette.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.v3Pressable)
        .disabled(draft.isEmpty || phase == .verifying)
        .opacity(draft.isEmpty ? 0.5 : 1)
        .accessibilityIdentifier("v3-gemini-verify")
    }

    @ViewBuilder private var statusLine: some View {
        Group {
            switch phase {
            case .failed:
                Label("That key didn't work — check it was copied fully, then try again.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(palette.danger)
            case .success:
                Label("Enhanced scans are on. “Find objects” now uses Gemini ✦",
                      systemImage: "checkmark.circle.fill")
                    .foregroundStyle(palette.accent)
            case .idle, .verifying:
                if hasWorkingKey {
                    Label("A key is saved — enhanced scans are \(geminiEnabled ? "on" : "off").",
                          systemImage: "key.fill")
                        .foregroundStyle(palette.ink3)
                } else {
                    EmptyView()
                }
            }
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.top, 10)
        .accessibilityIdentifier("v3-gemini-status")
    }

    @ViewBuilder private var removeButton: some View {
        Button {
            V3Haptics.warning()
            savedKey = ""
            draftKey = ""
            phase = .idle
        } label: {
            Text("Remove key & use on-device only")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.danger)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .accessibilityIdentifier("v3-gemini-remove")
    }

    // MARK: - Actions

    private func verifyAndSave() {
        let candidate = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, phase != .verifying else { return }
        keyFocused = false
        phase = .verifying
        Task {
            let ok = await V3GeminiVision.validateKey(candidate)
            await MainActor.run {
                if ok {
                    savedKey = candidate
                    geminiEnabled = true
                    phase = .success
                    V3Haptics.success()
                    // Let the success state land, then close.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
                } else {
                    phase = .failed
                    V3Haptics.warning()
                }
            }
        }
    }
}
