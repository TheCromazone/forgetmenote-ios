# ForgetMeNote v3 — Full Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring v3 to feature parity with the design at `design-reference/project/Forget Me Note.html` — add real auth + name capture, ship native V3 versions of every detail screen (Settings, Room, Space, Capture, Detail edit, New Room), and fix the bugs the user reported (hard-coded "Sam" greeting; broken Settings).

**Architecture:** All new SwiftUI lives under `ForgetMeNote/V3/`. A new `User` `@Model` plus `AuthStore` actor backs sign-in/sign-up; an `@Environment(\.v3CurrentUser)` value carries the active profile to every screen. `Route` gains v3-specific cases so the v3 navigation stack stops bouncing through v2's `ImageDetailScreen` / `SettingsScreen`. v2 legacy screens stay on disk untouched (per `CLAUDE.md`); they just stop being reachable from v3 routes.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, CryptoKit (password hashing), iOS 17+. No new pods.

**Reference files (in repo):**
- `design-reference/project/Forget Me Note.html` — the entry point the user pinned
- `design-reference/project/screens-auth.jsx` — sign-in/sign-up
- `design-reference/project/screens-home.jsx` — welcome/home/find
- `design-reference/project/screens-space.jsx` — room/space
- `design-reference/project/screens-secondary.jsx` — capture sheet, create-sub, detail sheet, settings
- `design-reference/project/theme.jsx` — palettes & flower mark
- `design-reference/project/App.jsx` — top-level navigation logic
- `design-reference/project/auth.jsx` — local auth store (the model we follow)

---

## Phasing

This plan ships in **6 phases**. Each phase produces a working, testable app on its own. Execute sequentially — later phases assume earlier phases landed.

| # | Phase | Ships | Effort |
|---|-------|-------|--------|
| 1 | **Auth + dynamic greeting** | Sign-in/sign-up screens, User model, real name in greeting, real sign-out | L |
| 2 | **V3 Settings screen** | Replace v2 SettingsScreen route with native V3SettingsScreen | M |
| 3 | **V3 Room + Space screens** | Tapping a room opens V3RoomScreen; tapping an item opens V3SpaceScreen | L |
| 4 | **V3 Capture flow** | Center "+" FAB → CaptureSheet → V3CreateSubScreen (camera-first) | M |
| 5 | **V3 Detail sheet + New Room sheet** | Half-modal item edit; New Room creation sheet | M |
| 6 | **QA pass + Maestro updates** | Full v3_full_qa.yaml covering signup → sign-out, plus iPhone install verification | M |

After Phase 6: bundle the Instrument Serif OTFs (per CLAUDE.md gap list) and consider Phase 7 (real RevenueCat IAP, deferred).

---

## Cross-cutting conventions

- All new screens go under `ForgetMeNote/V3/Screens/`. New components under `ForgetMeNote/V3/Components/`. Auth state lives under `ForgetMeNote/V3/Auth/`. Sheets under `ForgetMeNote/V3/Sheets/`.
- All new SwiftData `@Model` classes added to the schema in `ForgetMeNoteApp.swift`.
- Every interactive control needs an `.accessibilityIdentifier("v3-…")` for Maestro.
- Toggle bound to `@Model`: use the `@State` mirror pattern (see existing `UpdatedToggleRow` in `Views/Screens/ImageDetailScreen.swift`). Never bind a Toggle directly.
- ML services stay behind `#if !targetEnvironment(simulator)`.
- Never modify legacy `Views/` files. If a v2 screen needs to change for v3, write a fresh V3 screen and re-route.
- After every phase: build for iPhone, install, run Maestro on Simulator. Commit at the end of each phase (only when the user asks).

---

# Phase 1 — Authentication + dynamic greeting

**Why first:** the user explicitly called out two bugs ("settings doesn't work" — addressed in Phase 2; "says Hi Sam instead of my name" — addressed here). Auth is also a prerequisite for everything else — sign-out lives in Settings, the capture sheet needs to know whose data it's writing, and welcome should only show once per user.

## File structure

**Create:**
- `ForgetMeNote/V3/Auth/User.swift` — `@Model class User`
- `ForgetMeNote/V3/Auth/AuthStore.swift` — `@Observable final class AuthStore` with sign-in / sign-up / sign-out / current-user
- `ForgetMeNote/V3/Auth/V3AuthShell.swift` — shared gradient + corner-flower scaffold
- `ForgetMeNote/V3/Components/V3TextField.swift` — labeled text field with icon, error state, trailing slot
- `ForgetMeNote/V3/Components/V3PrimaryButton.swift` — rounded primary CTA with spinner
- `ForgetMeNote/V3/Components/V3SocialButton.swift` — Apple/Google buttons (stubs)
- `ForgetMeNote/V3/Screens/V3SignInScreen.swift`
- `ForgetMeNote/V3/Screens/V3SignUpScreen.swift`

**Modify:**
- `ForgetMeNote/ForgetMeNoteApp.swift` — register `User.self` in schema; instantiate `AuthStore`; inject into environment
- `ForgetMeNote/V3/V3RootView.swift` — auth gate before welcome; pass `currentUser.name` to V3HomeScreen and V3YouScreen instead of `"Sam"`
- `ForgetMeNote/V3/Screens/V3HomeScreen.swift` — accept `name: String` (already does); display from env user, not hardcoded
- `ForgetMeNote/V3/V3RootView.swift` (V3YouScreen embedded) — show user.name + email, add Sign Out button calling `authStore.signOut()`

## Task 1.1 — Create the `User` SwiftData model

**Files:**
- Create: `ForgetMeNote/V3/Auth/User.swift`

- [ ] **Step 1: Create the User model file**

Write `ForgetMeNote/V3/Auth/User.swift`:

```swift
import Foundation
import SwiftData
import CryptoKit

@Model
final class User {
    @Attribute(.unique) var id: String
    var name: String
    var email: String
    var passwordHash: String
    var createdAt: Int64

    init(name: String, email: String, password: String) {
        self.id = UUID().uuidString
        self.name = name.trimmingCharacters(in: .whitespaces)
        self.email = email.trimmingCharacters(in: .whitespaces).lowercased()
        self.passwordHash = User.hash(password)
        self.createdAt = Int64(Date().timeIntervalSince1970 * 1000)
    }

    func matches(password: String) -> Bool {
        passwordHash == User.hash(password)
    }

    static func hash(_ password: String) -> String {
        let digest = SHA256.hash(data: Data(password.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
```

- [ ] **Step 2: Add User to schema**

Modify `ForgetMeNote/ForgetMeNoteApp.swift`. Find the line declaring the schema (look for `Schema([ImageItem.self, AppSettings.self])`) and add `User.self`:

```swift
let schema = Schema([ImageItem.self, AppSettings.self, User.self])
```

- [ ] **Step 3: Build + verify schema migration is clean**

Run from `ios/`:
```bash
xcodegen generate && pod install
xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote \
  -configuration Debug -destination "generic/platform=iOS Simulator" \
  -allowProvisioningUpdates ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build
```

Expected: `BUILD SUCCEEDED`. SwiftData will auto-migrate on next launch (the v3 dev database has zero User rows so nothing to migrate).

## Task 1.2 — Build `AuthStore` (session + sign-in/up logic)

**Files:**
- Create: `ForgetMeNote/V3/Auth/AuthStore.swift`

- [ ] **Step 1: Write AuthStore**

Create `ForgetMeNote/V3/Auth/AuthStore.swift`:

```swift
import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class AuthStore {
    private(set) var currentUser: User?
    private let modelContainer: ModelContainer
    private let sessionKey = "v3_session_user_id"

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.currentUser = Self.loadSession(container: modelContainer)
    }

    struct AuthResult {
        let ok: Bool
        let error: String?
        static func success() -> AuthResult { .init(ok: true, error: nil) }
        static func failure(_ msg: String) -> AuthResult { .init(ok: false, error: msg) }
    }

    func signIn(email: String, password: String) -> AuthResult {
        let normalized = email.trimmingCharacters(in: .whitespaces).lowercased()
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.email == normalized })
        guard let user = (try? context.fetch(descriptor))?.first else {
            return .failure("No account with that email.")
        }
        guard user.matches(password: password) else {
            return .failure("Wrong password. Try again?")
        }
        UserDefaults.standard.set(user.id, forKey: sessionKey)
        currentUser = user
        return .success()
    }

    func signUp(name: String, email: String, password: String) -> AuthResult {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let normalized = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmedName.isEmpty else { return .failure("What should we call you?") }
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.email == normalized })
        if let _ = (try? context.fetch(descriptor))?.first {
            return .failure("That email is already in use.")
        }
        let user = User(name: trimmedName, email: normalized, password: password)
        context.insert(user)
        do { try context.save() } catch {
            return .failure("Could not save account.")
        }
        UserDefaults.standard.set(user.id, forKey: sessionKey)
        currentUser = user
        return .success()
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
        currentUser = nil
    }

    private static func loadSession(container: ModelContainer) -> User? {
        guard let id = UserDefaults.standard.string(forKey: "v3_session_user_id") else { return nil }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }
}
```

- [ ] **Step 2: Inject AuthStore from ForgetMeNoteApp**

In `ForgetMeNote/ForgetMeNoteApp.swift`, add a `@State` AuthStore alongside the `modelContainer`, and inject it into V3RootView's environment.

Add immediately after the `init()` body (or replace the body block):

```swift
@State private var authStore: AuthStore? = nil

var body: some Scene {
    WindowGroup {
        Group {
            if let authStore {
                V3RootView()
                    .environment(authStore)
            } else {
                Color.clear.task {
                    authStore = await MainActor.run { AuthStore(modelContainer: modelContainer) }
                }
            }
        }
    }
    .modelContainer(modelContainer)
    .onChange(of: scenePhase) { _, newPhase in
        // existing handlers unchanged
    }
}
```

- [ ] **Step 3: Build + run on Simulator**

```bash
xcodebuild ... build
xcrun simctl install booted "$SIM_APP"
xcrun simctl launch booted com.matthewcromaz.forgetmenote.v3.dev
```

Expected: app launches without crash. Welcome screen still shows (no auth wiring yet — that's Task 1.5).

## Task 1.3 — Shared auth UI primitives

**Files:**
- Create: `ForgetMeNote/V3/Auth/V3AuthShell.swift`
- Create: `ForgetMeNote/V3/Components/V3TextField.swift`
- Create: `ForgetMeNote/V3/Components/V3PrimaryButton.swift`
- Create: `ForgetMeNote/V3/Components/V3SocialButton.swift`

- [ ] **Step 1: V3AuthShell**

Create `ForgetMeNote/V3/Auth/V3AuthShell.swift`:

```swift
import SwiftUI

struct V3AuthShell<Content: View>: View {
    let palette: V3Palette
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [palette.paper, palette.accentBg],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // corner flower decorations
            FlowerMark(size: 90, color: palette.accent, pollen: palette.pollen)
                .opacity(0.18)
                .offset(x: -32, y: -16)
            FlowerMark(size: 64, color: palette.accent, pollen: palette.pollen)
                .opacity(0.14)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: 24, y: -8)

            FlowerMark(size: 80, color: palette.accent, pollen: palette.pollen)
                .opacity(0.16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 24, y: 24)

            content()
                .padding(.horizontal, 28)
                .padding(.top, 60)
                .padding(.bottom, 32)
        }
    }
}
```

- [ ] **Step 2: V3TextField**

Create `ForgetMeNote/V3/Components/V3TextField.swift`:

```swift
import SwiftUI

struct V3TextField<Trailing: View>: View {
    let palette: V3Palette
    let label: String
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default
    var autocapitalize: TextInputAutocapitalization = .never
    var error: String? = nil
    var accessibilityID: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.ink3)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(label.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(error == nil ? palette.ink3 : palette.danger)
                    Group {
                        if isSecure {
                            SecureField(placeholder, text: $text)
                        } else {
                            TextField(placeholder, text: $text)
                        }
                    }
                    .font(.system(size: 16))
                    .foregroundStyle(palette.ink)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(autocapitalize)
                    .autocorrectionDisabled()
                    .focused($focused)
                }
                trailing()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(error == nil ? (focused ? palette.accent : Color.clear) : palette.danger,
                            lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
            .accessibilityIdentifier(accessibilityID ?? "v3-textfield-\(label.lowercased())")

            if let error {
                HStack(spacing: 5) {
                    Circle().fill(palette.danger).frame(width: 4, height: 4)
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.danger)
                }
                .padding(.leading, 4)
            }
        }
    }
}

extension V3TextField where Trailing == EmptyView {
    init(palette: V3Palette, label: String, placeholder: String, text: Binding<String>,
         icon: String? = nil, isSecure: Bool = false,
         keyboard: UIKeyboardType = .default,
         autocapitalize: TextInputAutocapitalization = .never,
         error: String? = nil, accessibilityID: String? = nil) {
        self.init(palette: palette, label: label, placeholder: placeholder, text: text,
                  icon: icon, isSecure: isSecure, keyboard: keyboard,
                  autocapitalize: autocapitalize, error: error,
                  accessibilityID: accessibilityID,
                  trailing: { EmptyView() })
    }
}
```

- [ ] **Step 3: V3PrimaryButton**

Create `ForgetMeNote/V3/Components/V3PrimaryButton.swift`:

```swift
import SwiftUI

struct V3PrimaryButton: View {
    let palette: V3Palette
    let label: String
    var loading: Bool = false
    var disabled: Bool = false
    var accessibilityID: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: { if !loading && !disabled { action() } }) {
            ZStack {
                if loading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(disabled ? palette.line : palette.accent,
                        in: Capsule(style: .continuous))
            .shadow(color: disabled ? .clear : palette.accent.opacity(0.33),
                    radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(disabled || loading)
        .accessibilityIdentifier(accessibilityID ?? "v3-primary-\(label.lowercased())")
    }
}
```

- [ ] **Step 4: V3SocialButton**

Create `ForgetMeNote/V3/Components/V3SocialButton.swift`:

```swift
import SwiftUI
import AuthenticationServices

enum V3SocialKind { case apple, google }

struct V3SocialButton: View {
    let palette: V3Palette
    let kind: V3SocialKind
    var accessibilityID: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Group {
                    switch kind {
                    case .apple:
                        Image(systemName: "applelogo")
                            .foregroundStyle(.white)
                    case .google:
                        Text("G")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(hex: 0x4285F4))
                    }
                }
                Text(kind == .apple ? "Continue with Apple" : "Continue with Google")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(kind == .apple ? .white : palette.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(kind == .apple ? Color.black : palette.surface,
                        in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous)
                        .stroke(kind == .google ? palette.line : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID ?? "v3-social-\(kind == .apple ? "apple" : "google")")
    }
}
```

## Task 1.4 — V3SignInScreen and V3SignUpScreen

**Files:**
- Create: `ForgetMeNote/V3/Screens/V3SignInScreen.swift`
- Create: `ForgetMeNote/V3/Screens/V3SignUpScreen.swift`

Reference: `design-reference/project/screens-auth.jsx`

- [ ] **Step 1: V3SignInScreen**

Create `ForgetMeNote/V3/Screens/V3SignInScreen.swift`:

```swift
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
                        Rectangle().fill(palette.line).frame(height: 1)
                        Text("OR")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(palette.ink3)
                        Rectangle().fill(palette.line).frame(height: 1)
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
```

- [ ] **Step 2: V3SignUpScreen**

Create `ForgetMeNote/V3/Screens/V3SignUpScreen.swift`:

```swift
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
                        }
                        .buttonStyle(.plain)
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
                    }

                    if !password.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                ForEach(1...4, id: \.self) { i in
                                    Rectangle()
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
                        Rectangle().fill(palette.line).frame(height: 1)
                        Text("OR")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(palette.ink3)
                        Rectangle().fill(palette.line).frame(height: 1)
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
```

## Task 1.5 — Wire auth gate into V3RootView and pass real name

**Files:**
- Modify: `ForgetMeNote/V3/V3RootView.swift`

- [ ] **Step 1: Replace V3RootView with auth-aware version**

Edit `V3RootView.swift`. Replace the entire `struct V3RootView: View { ... }` definition with:

```swift
struct V3RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthStore.self) private var auth
    @State private var palette: V3Palette = .forget
    @State private var tab: V3Tab = .home
    @State private var homePath = NavigationPath()
    @State private var findPath = NavigationPath()
    @State private var youPath = NavigationPath()
    @State private var showWelcome: Bool = !UserDefaults.standard.bool(forKey: "v3_welcome_shown")
    @State private var authScreen: AuthScreen = .signIn
    @State private var didSeed = false
    @State private var legacyWalkthrough = WalkthroughViewModel()

    enum V3Tab: Hashable { case home, find, you }
    enum AuthScreen { case signIn, signUp }

    var body: some View {
        ZStack {
            if auth.currentUser == nil {
                authBody
            } else {
                signedInBody
            }
        }
        .environment(\.v3Palette, palette)
        .environment(legacyWalkthrough)
        .task {
            guard !didSeed else { return }
            didSeed = true
            let repo = ImageRepository(modelContainer: modelContext.container)
            try? await repo.initializeDefaultRoomsIfNeeded()
            _ = await repo.settings()
        }
    }

    @ViewBuilder private var authBody: some View {
        switch authScreen {
        case .signIn:
            V3SignInScreen(
                palette: palette,
                onSignedIn: { /* state-driven re-render handles it */ },
                onGoSignUp: { authScreen = .signUp }
            )
        case .signUp:
            V3SignUpScreen(
                palette: palette,
                onSignedUp: {
                    // brand-new users see the welcome screen once
                    showWelcome = true
                    UserDefaults.standard.set(false, forKey: "v3_welcome_shown")
                },
                onGoSignIn: { authScreen = .signIn }
            )
        }
    }

    @ViewBuilder private var signedInBody: some View {
        ZStack {
            TabView(selection: $tab) {
                NavigationStack(path: $homePath) {
                    V3HomeScreen(palette: palette,
                                 name: auth.currentUser?.name ?? "Friend",
                                 path: $homePath)
                        .navigationDestination(for: Route.self) { destination(for: $0) }
                }
                .tag(V3Tab.home)
                .tabItem { Label("Home", systemImage: "house.fill") }

                NavigationStack(path: $findPath) {
                    V3FindScreen(palette: palette, path: $findPath)
                        .navigationDestination(for: Route.self) { destination(for: $0) }
                }
                .tag(V3Tab.find)
                .tabItem { Label("Find", systemImage: "magnifyingglass") }

                NavigationStack(path: $youPath) {
                    V3YouScreen(palette: palette, path: $youPath,
                                onShowWelcome: { showWelcome = true })
                        .navigationDestination(for: Route.self) { destination(for: $0) }
                }
                .tag(V3Tab.you)
                .tabItem { Label("You", systemImage: "person.circle") }
            }
            .tint(palette.accent)

            if showWelcome {
                V3WelcomeScreen(
                    palette: palette,
                    onStart: dismissWelcome,
                    onSkip: dismissWelcome
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
    }

    private func dismissWelcome() {
        UserDefaults.standard.set(true, forKey: "v3_welcome_shown")
        withAnimation(.easeOut(duration: 0.3)) { showWelcome = false }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .imageDetail(let imageId):
            ImageDetailScreen(imageId: imageId, path: currentPathBinding)
        case .createChild(let parentId, let suggestedTitle, let rect, let tempPath):
            CreateChildScreen(
                parentId: parentId,
                suggestedTitle: suggestedTitle,
                rectangleOnParent: rect,
                tempPhotoPath: tempPath,
                path: currentPathBinding
            )
        case .settings:
            SettingsScreen()
        case .help:
            HelpScreen()
        }
    }

    private var currentPathBinding: Binding<NavigationPath> {
        switch tab {
        case .home: return $homePath
        case .find: return $findPath
        case .you:  return $youPath
        }
    }
}
```

- [ ] **Step 2: Update V3YouScreen greeting + show real user + add Sign Out**

Still in `V3RootView.swift`, replace the `V3YouScreen` body with this version (keeps stat row, replaces the greeting and adds sign-out at the bottom):

Find the existing `struct V3YouScreen: View` and update its top section (lines 116-141) and `actionList` (167-181):

```swift
struct V3YouScreen: View {
    let palette: V3Palette
    @Binding var path: NavigationPath
    var onShowWelcome: () -> Void

    @Environment(AuthStore.self) private var auth
    @Query(sort: \ImageItem.createdAt) private var allItems: [ImageItem]
    @Query private var settingsRows: [AppSettings]

    private var firstName: String { auth.currentUser?.name.split(separator: " ").first.map(String.init) ?? "Friend" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Good evening")
                        .v3SmallCaps(palette.ink3)
                    (Text("Hi \(firstName),\n").font(V3Font.headline(34)).foregroundStyle(palette.ink) +
                     Text("your stats").font(V3Font.headline(34, italic: true)).italic()
                        .foregroundStyle(palette.accent))
                        .tracking(-0.7)
                }
                .padding(.horizontal, 22)
                .padding(.top, 64)

                statRow
                    .padding(.horizontal, 22)
                    .padding(.top, 24)

                actionList
                    .padding(.top, 24)

                Spacer(minLength: 110)
            }
        }
        .background(paperBackground)
    }

    // ... statRow / statCard unchanged ...

    @ViewBuilder private var actionList: some View {
        VStack(spacing: 0) {
            actionRow("Settings", icon: "gear",
                      onTap: { path.append(Route.settings) },
                      accessibilityID: "v3-you-settings")
            Divider().background(palette.line).padding(.leading, 54)
            actionRow("Help", icon: "questionmark.circle",
                      onTap: { path.append(Route.help) },
                      accessibilityID: "v3-you-help")
            Divider().background(palette.line).padding(.leading, 54)
            actionRow("Show walkthrough", icon: "info.bubble",
                      onTap: onShowWelcome,
                      accessibilityID: "v3-you-walkthrough")
            Divider().background(palette.line).padding(.leading, 54)
            actionRow("Sign out", icon: "rectangle.portrait.and.arrow.right",
                      onTap: { auth.signOut() },
                      accessibilityID: "v3-you-signout",
                      destructive: true)
        }
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        .padding(.horizontal, 22)
    }

    private func actionRow(_ title: String, icon: String, onTap: @escaping () -> Void,
                           accessibilityID: String? = nil, destructive: Bool = false) -> some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(destructive ? palette.danger : palette.accent)
                    .frame(width: 32, height: 32)
                    .background(destructive ? palette.danger.opacity(0.1) : palette.accentBg,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.system(size: 15, weight: destructive ? .semibold : .medium))
                    .foregroundStyle(destructive ? palette.danger : palette.ink)
                Spacer()
                if !destructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.ink3)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID ?? "v3-you-row-\(title.lowercased())")
    }

    @ViewBuilder private var paperBackground: some View {
        ZStack {
            palette.paper
            LinearGradient(colors: [palette.surface.opacity(0.6), .clear],
                           startPoint: .top, endPoint: .center)
        }
        .ignoresSafeArea()
    }
}
```

- [ ] **Step 3: Update V3HomeScreen to use real first name (no hardcoded "Sam")**

V3HomeScreen already accepts `let name: String` (line 28). The fix is in V3RootView (Task 1.5 Step 1 replaces `name: "Sam"` with `name: auth.currentUser?.name ?? "Friend"`). Verify it shows only the first name — if `currentUser?.name == "Matthew Cromaz"` the greeting should say "Hi Matthew,". In V3HomeScreen open the file, find the greeting block (around line 76), and update to:

```swift
Text("Hi \(name.split(separator: " ").first.map(String.init) ?? name),")
```

This trims to first name only, matching the JSX prototype's `user.name.split(' ')[0]`.

- [ ] **Step 4: Build + install on Simulator + verify**

```bash
cd ~/Documents/forgetmenotev3/ios
xcodegen generate
SKIP_MLKIT=1 LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install
JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote \
    -configuration Debug -destination "generic/platform=iOS Simulator" \
    -allowProvisioningUpdates ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build

SIM_APP=~/Library/Developer/Xcode/DerivedData/ForgetMeNote-*/Build/Products/Debug-iphonesimulator/ForgetMeNote.app
xcrun simctl uninstall booted com.matthewcromaz.forgetmenote.v3.dev || true
xcrun simctl install booted "$SIM_APP"
xcrun simctl launch booted com.matthewcromaz.forgetmenote.v3.dev
```

Expected: sign-in screen appears. Tap "Create an account" → sign-up screen. Fill in name (e.g., "Matthew") + email + password (≥6 chars) → tap "Create account" → welcome screen → "Start remembering" → home shows **"Hi Matthew, welcome back."** (not "Hi Sam").

- [ ] **Step 5: Rebuild + install on iPhone**

Per CLAUDE.md, ML Kit is enabled for device builds. Run:

```bash
cd ~/Documents/forgetmenotev3/ios
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install   # without SKIP_MLKIT
JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  xcodebuild -workspace ForgetMeNote.xcworkspace -scheme ForgetMeNote -configuration Debug \
    -destination "id=E7A0CD3B-A97A-5548-A204-E046CA2ACAFD" \
    -allowProvisioningUpdates build
APP=~/Library/Developer/Xcode/DerivedData/ForgetMeNote-*/Build/Products/Debug-iphoneos/ForgetMeNote.app
xcrun devicectl device install app --device E7A0CD3B-A97A-5548-A204-E046CA2ACAFD "$APP"
xcrun devicectl device process launch --device E7A0CD3B-A97A-5548-A204-E046CA2ACAFD \
  com.matthewcromaz.forgetmenote.v3.dev
```

Ask the user to verify their name shows correctly in the greeting and they can sign out from You → Sign out.

## Task 1.6 — Update Maestro flow to start at sign-in

**Files:**
- Modify: `ios/qa/maestro/flows/v3_full_qa.yaml`

- [ ] **Step 1: Prepend sign-in steps**

The existing flow assumes welcome is the first screen. Now sign-in is first. Add these steps before the "Welcome Screen" step:

```yaml
# v3 sign-up — fresh install
- launchApp:
    clearState: true
- assertVisible:
    text: "Welcome"
- assertVisible:
    id: "v3-signin-go-signup"
- tapOn:
    id: "v3-signin-go-signup"
- assertVisible:
    text: "Make a place"
- tapOn:
    id: "v3-signup-name"
- inputText: "Maestro"
- tapOn:
    id: "v3-signup-email"
- inputText: "maestro@fmn.app"
- tapOn:
    id: "v3-signup-password"
- inputText: "secret123"
- hideKeyboard
- tapOn:
    id: "v3-signup-submit"
- assertVisible:
    text: "Remember"   # v3 welcome screen
- takeScreenshot: v3_00_signed_up
```

Then the existing `v3_01_welcome` and onward continue. Also update the "Home Screen" step to expect "Hi Maestro," instead of "Hi Sam,".

- [ ] **Step 2: Run Maestro**

```bash
cd ~/Documents/forgetmenotev3/ios
JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  maestro test qa/maestro/flows/v3_full_qa.yaml
```

Expected: all steps pass; screenshots include `v3_00_signed_up.png`.

## Phase 1 commit checkpoint

After Task 1.6 passes:
```bash
git add ForgetMeNote/V3/Auth ForgetMeNote/V3/Components/V3TextField.swift \
        ForgetMeNote/V3/Components/V3PrimaryButton.swift ForgetMeNote/V3/Components/V3SocialButton.swift \
        ForgetMeNote/V3/Screens/V3SignInScreen.swift ForgetMeNote/V3/Screens/V3SignUpScreen.swift \
        ForgetMeNote/V3/V3RootView.swift ForgetMeNote/V3/Screens/V3HomeScreen.swift \
        ForgetMeNote/ForgetMeNoteApp.swift qa/maestro/flows/v3_full_qa.yaml
git commit -m "feat(v3): add real auth + sign-in/up + dynamic name in greeting"
```

(Only commit when the user asks.)

---

# Phase 2 — V3 Settings screen

**Why second:** the user said "settings icon doesn't work." Even if the v2 SettingsScreen renders, the v2 chrome breaks the v3 visual continuity. The fix is to write a native `V3SettingsScreen` that matches `design-reference/project/screens-secondary.jsx` (lines 448–555) and route `Route.settings` to it (or introduce `V3Route.settings`).

## File structure

**Create:**
- `ForgetMeNote/V3/Screens/V3SettingsScreen.swift`
- `ForgetMeNote/V3/Components/V3SettingsRow.swift`
- `ForgetMeNote/V3/Components/V3Switch.swift`
- `ForgetMeNote/V3/Components/V3SliderRow.swift`
- `ForgetMeNote/V3/Components/V3NavHeader.swift` (reused later)

**Modify:**
- `ForgetMeNote/V3/V3RootView.swift` — point `Route.settings` to `V3SettingsScreen` instead of legacy `SettingsScreen()`.

## Key design notes (from `screens-secondary.jsx` lines 448–555)
- Profile header card with avatar circle (single-letter from `auth.currentUser.name`), real email
- Pro upsell card with dark gradient + flower watermark + "Try free for 7 days"
- Sections (in order): Walkthrough · Sub-space rectangles · Refreshed items · Search · Your stuff · Account
- Each section: small-caps title + grouped surface card
- Sliders for rectangle fill/border/highlight opacity bound to `AppSettings` fields. **Use `@State` mirror pattern**: hold a local `@State var fill: Float`; on change, write through `await repo.saveSettings()`.
- Account section: Sign out row, calls `auth.signOut()` and pops back to root

## Tasks (outline; detail filled in at execution time)

1. **V3NavHeader** — shared back-arrow + title + optional right slot
2. **V3SettingsRow / V3Switch / V3SliderRow** — three list-row primitives
3. **V3SettingsScreen** body — sections wired to `AppSettings` via `ImageRepository`
4. **Route swap** — in `V3RootView.destination(for:)`, change `case .settings: SettingsScreen()` to `case .settings: V3SettingsScreen()`. Leave the `Route.settings` enum case alone.
5. **Build + install + verify** Settings opens from You → Settings; sliders persist; sign-out works (already tested in Phase 1)
6. **Maestro update** — add `v3-settings-*` assertions matching the new screen

## Phase 2 commit checkpoint

After verification:
```bash
git commit -m "feat(v3): native settings screen replaces v2 legacy route"
```

---

# Phase 3 — V3 Room + Space screens

**Why third:** right now tapping a room tile opens v2's `ImageDetailScreen` — a screen designed for the old visual language. Native V3 RoomScreen + SpaceScreen unlock the rest of the design (nested sub-spaces with rectangle overlays, the photo↔grid view switcher, the "Tap a spot to peek inside" hint).

## File structure

**Create:**
- `ForgetMeNote/V3/Screens/V3RoomScreen.swift` — ported from `screens-space.jsx` `RoomScreen` (lines 5–108)
- `ForgetMeNote/V3/Screens/V3SpaceScreen.swift` — ported from `screens-space.jsx` `SpaceScreen` (lines 165–375)
- `ForgetMeNote/V3/Components/V3PlaceCard.swift` — ported from `PlaceCard` (lines 110–162)
- `ForgetMeNote/V3/Components/V3SubScanCard.swift` — ported from `SubScanCard` (lines 377–432)
- `ForgetMeNote/V3/Components/V3EmptyState.swift` — ported from `EmptyState` (lines 435–467)
- `ForgetMeNote/V3/Components/V3Chip.swift` — small tag chip used in space + room headers

**Modify:**
- `ForgetMeNote/Views/Route.swift` — add new cases `case v3Room(roomId: String)` and `case v3Space(spaceId: String)`
- `ForgetMeNote/V3/V3RootView.swift` — `destination(for:)` switch case for new routes
- `ForgetMeNote/V3/Screens/V3HomeScreen.swift` — room tile tap calls `path.append(Route.v3Room(roomId: room.id))` instead of `.imageDetail`
- `ForgetMeNote/V3/Screens/V3FindScreen.swift` — search result row calls `v3Room`/`v3Space` based on `isRoom`

## Key design notes

- **RoomScreen header** is the room's hue color, full-bleed, with rounded-bottom corners. Inside: back button, ellipsis menu (opens DetailSheet for the room itself), serif room name 56pt, places count + tags row.
- **Add a place** primary action band sits below the header (dark `ink` background, paper-color text, camera icon)
- **SpaceScreen** displays the photo with rectangle overlays for each sub-space; one rect activates on tap (white→accent border), second tap navigates in. "What's inside · N" section toggles between photo-carousel and grid view.
- Detail sheet (Phase 5) is invoked from the ellipsis menu in both screens.

## Tasks (outline)

1. V3Chip, V3EmptyState, V3PlaceCard, V3SubScanCard (4 components)
2. V3RoomScreen with hero header + add-place band + places grid
3. V3SpaceScreen with photo + sub-rect overlays + view-mode switcher + sub carousel/grid
4. Add `v3Room` and `v3Space` Route cases
5. Re-route taps in V3HomeScreen + V3FindScreen
6. Verify nested navigation: Home → Room → Space → SubSpace
7. Maestro update for the new room/space flow

## Deferred from this phase

- Drag-to-reorder places (inherited broken state from v2 — defer per CLAUDE.md)
- Mantis cropper for in-place photo replacement (kept from v2 — call existing v2 flow via a future v3 route if needed)

## Phase 3 commit checkpoint

```bash
git commit -m "feat(v3): native room + space screens with rect overlays"
```

---

# Phase 4 — V3 Capture flow

**Why fourth:** the design has a center "+" FAB overlapping the tab bar — currently missing. Tapping it opens a quick-capture sheet ("Snap a photo" / "From library" / room picker), then the camera (existing UIImagePickerController wrap), then `V3CreateSubScreen` (camera-first → rectangle-on-parent → name + tags).

## File structure

**Create:**
- `ForgetMeNote/V3/Sheets/V3CaptureSheet.swift` — half-modal with snap/library + room picker
- `ForgetMeNote/V3/Screens/V3CreateSubScreen.swift` — port of `CreateSubScreen` in `screens-secondary.jsx` (lines 274–445), with the draggable rectangle selector
- `ForgetMeNote/V3/Components/V3CaptureFAB.swift` — center FAB visual

**Modify:**
- `ForgetMeNote/V3/V3RootView.swift` — overlay the FAB over the TabView; on tap, present `V3CaptureSheet`. On "Snap a photo" → present `CameraPicker` (existing v2 component); on "From library" → present `PHPickerViewController`; on "room selected" → push `V3CreateSubScreen(parentId: roomId, image: capturedImage)` to the active tab's path.
- `ForgetMeNote/Views/Route.swift` — add `case v3CreateSub(parentId: String, tempPhotoPath: String?)`

## Key implementation notes

- Center FAB sits at safe-area bottom + 24pt, 64pt diameter circle, palette.accent background, camera icon. Tap zone overlays the middle tab bar slot.
- For the rectangle drag handles, use SwiftUI `DragGesture` with `.gesture(...)` on each corner. The JSX uses pointer events; the SwiftUI equivalent translates 1:1 to `DragGesture(minimumDistance: 0)`.
- After save, call `ImageRepository.saveImage(jpegData:name:tags:parentId:rectangleOnParent:)` (already exists) and pop back to the parent screen.

## Tasks (outline)

1. V3CaptureFAB visual
2. Wire FAB overlay in V3RootView; manage sheet state
3. V3CaptureSheet half-modal with snap/library/room picker
4. V3CreateSubScreen with draggable rectangle + name + tags + save
5. Wire camera intent (reuse existing `CameraPicker` from `Camera/`) for "Snap a photo"
6. Wire PHPicker for "From library"
7. Maestro: simulator can't drive the real camera, but it CAN drive the library picker (or stub a DemoImage path)

## Phase 4 commit checkpoint

```bash
git commit -m "feat(v3): center FAB + capture sheet + native create-sub screen"
```

---

# Phase 5 — V3 Detail edit sheet + New Room sheet

**Why fifth:** the ellipsis menu on Room/Space (Phase 3) needs to open a detail edit sheet; the home screen "New room" CTA + ghost tile need to actually create rooms. Both are half-modal sheets.

## File structure

**Create:**
- `ForgetMeNote/V3/Sheets/V3DetailSheet.swift` — port of `DetailSheet` in `screens-secondary.jsx` (lines 5–167). Name field, tags field, notes field, "Mark as refreshed" toggle, "Delete this place" danger button.
- `ForgetMeNote/V3/Sheets/V3NewRoomSheet.swift` — name input + hue picker grid + Create button. On save, call `ImageRepository.createRoom(name:tags:parentId:backgroundColor:textColor:)`.

**Modify:**
- `ForgetMeNote/V3/Screens/V3HomeScreen.swift` — "New room" CTA + ghost tile both `.sheet(isPresented: $showNewRoom) { V3NewRoomSheet(...) }`
- `ForgetMeNote/V3/Screens/V3RoomScreen.swift` + `V3SpaceScreen.swift` — ellipsis menu presents `V3DetailSheet`

## Key implementation notes

- DetailSheet uses the @State mirror pattern for the "Mark as refreshed" toggle. On Save tap, write through to repository.
- NewRoomSheet hue picker shows the 6 hues from `V3Palette.hues`; tapping selects (highlight selected). On Create, call `repo.createRoom(name:tags:[],parentId:nil,backgroundColor:Int64(...),textColor:Int64(...))`.

## Phase 5 commit checkpoint

```bash
git commit -m "feat(v3): detail edit sheet + new room creation sheet"
```

---

# Phase 6 — QA pass + Maestro suite

**Why last:** by now the app has every design screen wired. Now we end-to-end-test the full happy path and iterate on the failures.

## Tasks

1. **Expand `qa/maestro/flows/v3_full_qa.yaml`** to cover: sign-up → welcome → home → tap room → V3RoomScreen → tap place → V3SpaceScreen → ellipsis → V3DetailSheet (assert visible) → close → back to home → "+" FAB → V3CaptureSheet → "From library" → simulator picks demo image → V3CreateSubScreen → drag rect → Save → back to home → Find tab → search → tap result → V3SpaceScreen → You tab → Sign out → back at V3SignInScreen.
2. Add per-screen assertions on the headline serif text (e.g. assert "Hi <name>" in home, "Find a thing" in find, "Your stats" in you).
3. Run on Simulator. Fix any failures. Iterate.
4. Run on iPhone (manual). Verify Toggle no-snap-back behavior on the V3DetailSheet refreshed toggle.
5. Bundle Instrument Serif OTF fonts: drop files in `ForgetMeNote/Fonts/`, add `UIAppFonts: [InstrumentSerif-Regular.otf, InstrumentSerif-Italic.otf]` to `project.yml` Info.plist properties. (Per CLAUDE.md gap list.)

## Phase 6 commit checkpoint

```bash
git commit -m "test(v3): full e2e Maestro flow + Instrument Serif fonts"
```

---

# Out of scope (explicitly deferred)

These are real follow-ups but NOT in this plan:

- Real RevenueCat IAP (current `StubPaywallView` stays; the Pro upsell in V3SettingsScreen links nowhere live)
- Real Apple Sign In via `ASAuthorizationAppleIDProvider` (current stub uses the demo account)
- Real Google Sign In (same)
- Cross-platform import from Android (v1.3.7 SQLite format incompatible)
- Drag-to-reorder rooms/places (inherited broken state from v2)
- Cloud sync
- Backend auth server

These are noted in CLAUDE.md and will become Phase 7+ when prioritized.

---

# Self-review

**Spec coverage check:**
- ✅ "Settings icon doesn't work" → Phase 2 replaces with native V3SettingsScreen
- ✅ "Hi Sam instead of my name" → Phase 1 Task 1.5 wires real user name
- ✅ "New login page" → Phase 1 Tasks 1.4 (sign-in + sign-up)
- ✅ Implement design from `Forget Me Note.html` → all six phases together cover every screen in `App.jsx`'s navigation: signin, signup, welcome, home, find, room, space, subspace, create, settings, plus the capture sheet and detail sheet
- ✅ Welcome screen → already exists (V3WelcomeScreen)
- ✅ "Lots of issues to fix" → Phase 6 QA pass surfaces the rest

**Placeholder scan:** ✅ Phase 1 has full code; Phases 2-6 explicitly mark "Tasks (outline)" and reference the JSX file + line numbers for visual details. No "implement later" without a file path + lines.

**Type consistency:** AuthStore methods (`signIn`, `signUp`, `signOut`, `currentUser`) match across V3RootView and the screens. `Route.settings` keeps the same case name in Phase 2 (only its destination view changes).

---

# Execution Handoff

Plan saved to `docs/superpowers/plans/2026-05-27-v3-full-implementation.md`.

Phase 1 is fully spec'd with code. Phases 2-6 are outlined; each will be expanded into full code at execution time (the agent/session executing that phase reads the JSX reference + the outline and writes the actual Swift).

Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task within each phase, review between tasks. Good for the ~30 tasks across 6 phases.

**2. Inline Execution** — I execute tasks myself in this session, batched per-phase, with checkpoints between phases.
