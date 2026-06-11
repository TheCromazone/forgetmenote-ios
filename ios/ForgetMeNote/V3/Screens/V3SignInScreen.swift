import SwiftUI

struct V3SignInScreen: View {
    let palette: V3Palette
    let onSignedIn: () -> Void
    let onGoSignUp: () -> Void

    @Environment(AuthStore.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var errors: [String: String] = [:]
    @State private var formError: String?
    @State private var loading = false

    var body: some View {
        V3AuthShell(palette: palette) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        FlowerMark(size: 36, color: palette.accent, pollen: palette.pollen)
                        Text("ForgetMeNote")
                            .font(V3Font.headline(22))
                            .foregroundStyle(palette.ink)
                    }
                    .padding(.bottom, 24)

                    (Text("Welcome ").font(V3Font.display(40)).foregroundStyle(palette.ink) +
                     Text("back.").font(V3Font.display(40, italic: true)).italic().foregroundStyle(palette.accent))
                        .tracking(-0.8)
                        .padding(.bottom, 8)

                    Text("Sign in to pick up where you left off.")
                        .font(.system(size: 15))
                        .foregroundStyle(palette.ink2)
                        .padding(.bottom, 14)

                    Button {
                        email = "demo@fmn.app"
                        password = "forget"
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .bold))
                            (Text("Demo · ").bold() + Text("tap to autofill — demo@fmn.app / forget"))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.accentBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(palette.accentSoft, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("v3-signin-demo")
                    .padding(.bottom, 18)

                    V3TextField(palette: palette, label: "Email", placeholder: "you@example.com",
                                text: $email, icon: "envelope", keyboard: .emailAddress,
                                error: errors["email"], accessibilityID: "v3-signin-email")

                    V3TextField(palette: palette, label: "Password",
                                placeholder: "••••••••",
                                text: $password, icon: "lock", isSecure: !showPassword,
                                error: errors["password"],
                                accessibilityID: "v3-signin-password") {
                        Button { showPassword.toggle() } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .font(.system(size: 16))
                                .foregroundStyle(palette.ink3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("v3-signin-toggle-password")
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

                    Spacer(minLength: 16)

                    V3PrimaryButton(palette: palette, label: "Sign in",
                                    loading: loading,
                                    accessibilityID: "v3-signin-submit") {
                        submit()
                    }
                    .padding(.top, 6)

                    HStack(spacing: 12) {
                        SwiftUI.Rectangle().fill(palette.line).frame(height: 1)
                        Text("OR")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(palette.ink3)
                        SwiftUI.Rectangle().fill(palette.line).frame(height: 1)
                    }
                    .padding(.vertical, 24)

                    VStack(spacing: 10) {
                        V3SocialButton(palette: palette, kind: .apple) { stubSocial() }
                        V3SocialButton(palette: palette, kind: .google) { stubSocial() }
                    }

                    HStack(spacing: 4) {
                        Spacer()
                        Text("New here?")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.ink2)
                        Button("Create an account", action: onGoSignUp)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.accent)
                            .accessibilityIdentifier("v3-signin-go-signup")
                        Spacer()
                    }
                    .padding(.top, 24)
                }
            }
        }
    }

    private func submit() {
        var errs: [String: String] = [:]
        if !email.contains("@") || !email.contains(".") {
            errs["email"] = "That doesn't look like an email."
        }
        if password.isEmpty { errs["password"] = "Need your password." }
        errors = errs
        formError = nil
        if !errs.isEmpty { return }

        loading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let r = auth.signIn(email: email, password: password)
            loading = false
            if r.ok { onSignedIn() } else { formError = r.error }
        }
    }

    private func stubSocial() {
        // For the dev build, social sign-in seeds/uses the demo account.
        let r = auth.signIn(email: "demo@fmn.app", password: "forget")
        if r.ok { onSignedIn() } else {
            // first-run: create the demo user
            _ = auth.signUp(name: "Sam", email: "demo@fmn.app", password: "forget")
            onSignedIn()
        }
    }
}
