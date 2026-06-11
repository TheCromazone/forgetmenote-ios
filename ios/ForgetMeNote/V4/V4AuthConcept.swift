import SwiftUI

struct V4AuthGate: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .create
    @State private var name = "Sam"
    @State private var email = ""
    @State private var password = ""
    @State private var keepSignedIn = true
    @State private var error: String?
    @State private var isSubmitting = false

    private enum Mode: String, CaseIterable, Identifiable {
        case create = "Create"
        case signIn = "Login"

        var id: String { rawValue }
    }

    private var isCreate: Bool { mode == .create }
    private var primaryTitle: String { isCreate ? "Create memory vault" : "Unlock memory vault" }
    private var subtitle: String {
        isCreate
        ? "A private map of your rooms, shelves, boxes, and the exact places things live."
        : "Return to your personal map without making the app feel like a bank login."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                modePicker
                form
                primaryButton
                demoButton
                trustRow
            }
            .padding(22)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(V4.background)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("V4HeroDrawer")
                .resizable()
                .scaledToFill()
                .frame(height: 212)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.76)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(isCreate ? "ForgetMeNote account" : "Welcome back")
                    .v4SmallCaps(V4.cyan)
                Text(isCreate ? "Start with the places you actually touch." : "Your house, remembered.")
                    .font(V4.title(32))
                    .foregroundStyle(V4.ink)
                    .lineSpacing(-1)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(V4.ink2)
                    .lineLimit(3)
            }
            .padding(18)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.32), radius: 24, y: 14)
        .accessibilityIdentifier("v4-auth-hero")
    }

    private var modePicker: some View {
        HStack(spacing: 6) {
            ForEach(Mode.allCases) { item in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        mode = item
                        error = nil
                    }
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(mode == item ? Color(hex: 0x11110E) : V4.ink2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(mode == item ? V4.paper : .white.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.13), lineWidth: 1))
        .accessibilityIdentifier("v4-auth-mode")
    }

    private var form: some View {
        VStack(spacing: 10) {
            if isCreate {
                V4AuthField(title: "Name", text: $name, systemName: "person.fill", contentType: .name)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            V4AuthField(title: "Email", text: $email, systemName: "envelope.fill", contentType: .emailAddress)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            V4SecureAuthField(title: "Password", text: $password)
            Toggle(isOn: $keepSignedIn) {
                Text("Keep me signed in on this iPhone")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x4D473D))
            }
            .toggleStyle(.switch)
            .tint(V4.cyan)
            .padding(.horizontal, 4)
            if let error {
                Text(error)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x8B3F31))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(V4.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: 0xFFF6E5).opacity(0.78), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.24), radius: 22, y: 12)
    }

    private var primaryButton: some View {
        Button(action: submit) {
            HStack {
                Text(primaryTitle)
                Spacer()
                Image(systemName: "arrow.right")
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color(hex: 0x10110E))
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(
                LinearGradient(colors: [V4.paper, V4.pollen],
                               startPoint: .leading,
                               endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("v4-auth-primary")
    }

    private var demoButton: some View {
        Button(action: useDemo) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(V4.pollen)
                Text("Try the demo account")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: 0xF7F0E4))
                Spacer()
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color(hex: 0xF7F0E4))
                }
            }
            .padding(15)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(Color(hex: 0x25251F).opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(V4.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
        .accessibilityIdentifier("v4-demo-account")
    }

    private var trustRow: some View {
        HStack(spacing: 10) {
            trustChip("Private first", "lock.fill")
            trustChip("Local photos", "iphone")
        }
    }

    private func trustChip(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(V4.ink2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.white.opacity(0.06), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private func submit() {
        guard !isSubmitting else { return }
        error = nil
        isSubmitting = true
        defer { isSubmitting = false }
        let result = isCreate
            ? auth.signUp(name: name, email: email, password: password)
            : auth.signIn(email: email, password: password)
        if result.ok {
            dismiss()
        } else {
            error = result.error
        }
    }

    private func useDemo() {
        guard !isSubmitting else { return }
        error = nil
        isSubmitting = true
        let result = auth.useDemoAccount()
        if result.ok {
            dismiss()
        } else {
            error = result.error
        }
        isSubmitting = false
    }
}

private struct V4AuthField: View {
    let title: String
    @Binding var text: String
    let systemName: String
    var contentType: UITextContentType?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .foregroundStyle(Color(hex: 0x596653))
                .frame(width: 30, height: 30)
            TextField(text: $text, prompt: Text(title).foregroundStyle(Color(hex: 0x756D60))) {
                Text(title)
            }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: 0x151510))
                .textContentType(contentType)
                .submitLabel(.next)
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(Color(hex: 0xFBF3E3), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color(hex: 0xB8A987).opacity(0.72), lineWidth: 1)
        )
    }
}

private struct V4SecureAuthField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .foregroundStyle(Color(hex: 0x8B6D2D))
                .frame(width: 30, height: 30)
            SecureField(text: $text, prompt: Text(title).foregroundStyle(Color(hex: 0x756D60))) {
                Text(title)
            }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: 0x151510))
                .textContentType(.password)
                .submitLabel(.done)
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(Color(hex: 0xFBF3E3), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color(hex: 0xB8A987).opacity(0.72), lineWidth: 1)
        )
    }
}
