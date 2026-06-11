import Foundation
import SwiftData
import SwiftUI

@Observable
final class AuthStore {
    private(set) var currentUser: User?
    private let modelContainer: ModelContainer
    private let sessionKey = "v3_session_user_id"

    @MainActor
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

    @MainActor
    func signIn(email: String, password: String) -> AuthResult {
        let normalized = email.trimmingCharacters(in: .whitespaces).lowercased()
        let context = modelContainer.mainContext
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

    @MainActor
    func signUp(name: String, email: String, password: String) -> AuthResult {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let normalized = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmedName.isEmpty else { return .failure("What should we call you?") }
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.email == normalized })
        if (try? context.fetch(descriptor))?.first != nil {
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

    @MainActor
    func useDemoAccount() -> AuthResult {
        let email = "demo@fmn.app"
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.email == email })
        if let existing = (try? context.fetch(descriptor))?.first {
            UserDefaults.standard.set(existing.id, forKey: sessionKey)
            currentUser = existing
            return .success()
        }

        let user = User(demoName: "Sam", email: email)
        context.insert(user)
        do { try context.save() } catch {
            return .failure("Could not start demo account.")
        }
        UserDefaults.standard.set(user.id, forKey: sessionKey)
        currentUser = user
        return .success()
    }

    @MainActor
    func signOut() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
        currentUser = nil
    }

    @MainActor
    private static func loadSession(container: ModelContainer) -> User? {
        guard let id = UserDefaults.standard.string(forKey: "v3_session_user_id") else { return nil }
        let context = container.mainContext
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == id })
        if let user = (try? context.fetch(descriptor))?.first {
            return user
        }
        UserDefaults.standard.removeObject(forKey: "v3_session_user_id")
        return nil
    }
}
