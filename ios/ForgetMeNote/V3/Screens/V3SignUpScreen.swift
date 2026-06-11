import SwiftUI

struct V3SignUpScreen: View {
    let palette: V3Palette
    let onSignedUp: () -> Void
    let onGoSignIn: () -> Void

    @Environment(AuthStore.self) private var auth
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var errors: [String: String] = [:]
    @State private var formError: String?
    @State private var loading = false

    private var strength: Int {
        guard !password.isEmpty else { return 0 }
        var s = 0
        if password.count >= 6 { s += 1 }
        if password.count >= 10 { s += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil &&
           password.range(of: "[a-z]", options: .regularExpression) != nil { s += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil ||
           password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { s += 1 }
        return s
    }
    private var strengthLabel: String {
        ["", "Weak", "Okay", "Good", "Strong"][min(strength, 4)]
    }
    private var strengthColor: Color {
        let opts: [Color] = [palette.line, Color(hex: 0xE89A8E), palette.pollen,
                             Color(hex: 0x7FA88C), palette.accent]
        return opts[min(strength, 4)]
    }

    var body: some View {
        V3AuthShell(palette: palette) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button(action: onGoSignIn) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(palette.ink)
                                .frame(width: 38, height: 38)
                                .background(palette.surface, in: Circle())
                                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                                .frame(width: 44, height: 44)
                                .contentShape(SwiftUI.Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back to sign in")
                        .accessibilityIdentifier("v3-signup-back")
                        Spacer()
                        FlowerMark(size: 28, color: palette.accent, pollen: palette.pollen)
                    }
                    .padding(.bottom, 24)

                    (Text("Make a place\nto ").font(V3Font.display(38)).foregroundStyle(palette.ink) +
                     Text("remember.").font(V3Font.display(38, italic: true)).italic().foregroundStyle(palette.accent))
                        .tracking(-0.8)
                        .lineSpacing(0)
                        .padding(.bottom, 8)

                    Text("Free forever for up to 50 places.")
                        .font(.system(size: 15))
                        .foregroundStyle(palette.ink2)
                        .padding(.bottom, 24)

                    V3TextField(palette: palette, label: "Your name", placeholder: "Sam",
                                text: $name, icon: "person",
                                autocapitalize: .words,
                                error: errors["name"], accessibilityID: "v3-signup-name")

                    V3TextField(palette: palette, label: "Email", placeholder: "you@example.com",
                                text: $email, icon: "envelope", keyboard: .emailAddress,
                                error: errors["email"], accessibilityID: "v3-signup-email")

                    V3TextField(palette: palette, label: "Password",
                                placeholder: "at least 6 characters",
                                text: $password, icon: "lock", isSecure: !showPassword,
                                error: errors["password"],
                                accessibilityID: "v3-signup-password") {
                        Button { showPassword.toggle() } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .font(.system(size: 16))
                                .foregroundStyle(palette.ink3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("v3-signup-toggle-password")
                    }

                    if !password.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                ForEach(1...4, id: \.self) { i in
                                    SwiftUI.Rectangle()
                                        .fill(i <= strength ? strengthColor : palette.line)
                                        .frame(height: 3)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(strength > 0 ? "Password strength · \(strengthLabel)" : "Choose a strong password")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(palette.ink3)
                        }
                        .padding(.top, -4).padding(.bottom, 14).padding(.horizontal, 2)
                    }

                    if let formError {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                            Text(formError).font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(palette.danger)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(palette.danger.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 6)
                    }

                    V3PrimaryButton(palette: palette, label: "Create account",
                                    loading: loading,
                                    accessibilityID: "v3-signup-submit") {
                        submit()
                    }
                    .padding(.top, 4)

                    Text("By continuing, you agree to our Terms and Privacy.")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.ink3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)

                    HStack(spacing: 12) {
                        SwiftUI.Rectangle().fill(palette.line).frame(height: 1)
                        Text("OR")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(palette.ink3)
                        SwiftUI.Rectangle().fill(palette.line).frame(height: 1)
                    }
                    .padding(.vertical, 20)

                    VStack(spacing: 10) {
                        V3SocialButton(palette: palette, kind: .apple) { stubSocial() }
                        V3SocialButton(palette: palette, kind: .google) { stubSocial() }
                    }

                    HStack(spacing: 4) {
                        Spacer()
                        Text("Have an account?")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.ink2)
                        Button("Sign in", action: onGoSignIn)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.accent)
                            .accessibilityIdentifier("v3-signup-go-signin")
                        Spacer()
                    }
                    .padding(.top, 20)
                }
            }
            // Keyboard accessory "Done" — on the iOS 26.5 Sim the keyboard
            // occludes the Create-account button and Maestro's hideKeyboard is
            // unreliable, so give it an explicit, id'd dismiss affordance.
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .accessibilityIdentifier("v3-keyboard-done")
                }
            }
        }
    }

    private func submit() {
        var errs: [String: String] = [:]
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            errs["name"] = "What should we call you?"
        }
        if !email.contains("@") || !email.contains(".") {
            errs["email"] = "That doesn't look like an email."
        }
        if password.count < 6 { errs["password"] = "Use at least 6 characters." }
        errors = errs
        formError = nil
        if !errs.isEmpty { return }

        loading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let r = auth.signUp(name: name, email: email, password: password)
            loading = false
            if r.ok { onSignedUp() } else { formError = r.error }
        }
    }

    private func stubSocial() {
        let r = auth.signUp(name: name.isEmpty ? "Friend" : name,
                            email: "social_\(UUID().uuidString.prefix(6))@fmn.app",
                            password: UUID().uuidString)
        if r.ok { onSignedUp() }
    }
}
