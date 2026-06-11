import XCTest
import SwiftData
@testable import ForgetMeNote

/// Exercises `V3/Auth/AuthStore`. `AuthStore` reads/writes `User` rows through a
/// `ModelContainer`'s `mainContext`, so each test builds an in-memory container
/// for `User` and runs assertions on the main actor (AuthStore APIs are
/// `@MainActor`).
@MainActor
final class AuthStoreTests: XCTestCase {

    /// Fresh in-memory container scoped to `User` so tests never touch disk and
    /// never collide across runs.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: User.self, configurations: config)
    }

    /// AuthStore persists the signed-in user id in UserDefaults; clear it so a
    /// stale session from a prior test can't leak into `currentUser`.
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "v3_session_user_id")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "v3_session_user_id")
        super.tearDown()
    }

    func testSignUpInsertsUserAndSetsCurrentUser() throws {
        let container = try makeContainer()
        let store = AuthStore(modelContainer: container)

        let result = store.signUp(name: "Sam", email: "sam@example.com", password: "hunter2")

        XCTAssertTrue(result.ok)
        XCTAssertNil(result.error)
        XCTAssertNotNil(store.currentUser)
        XCTAssertEqual(store.currentUser?.email, "sam@example.com")

        // The user is actually persisted in the container.
        let count = try container.mainContext.fetchCount(FetchDescriptor<User>())
        XCTAssertEqual(count, 1)
    }

    func testDuplicateEmailSignUpFails() throws {
        let container = try makeContainer()
        let store = AuthStore(modelContainer: container)

        let first = store.signUp(name: "Sam", email: "sam@example.com", password: "hunter2")
        XCTAssertTrue(first.ok)

        // Same email (different case / whitespace normalizes to the same row).
        let second = store.signUp(name: "Sammy", email: "  SAM@example.com ", password: "other")
        XCTAssertFalse(second.ok)
        XCTAssertEqual(second.error, "That email is already in use.")

        // No second row created.
        let count = try container.mainContext.fetchCount(FetchDescriptor<User>())
        XCTAssertEqual(count, 1)
    }

    func testSignInWrongPasswordReturnsWrongPasswordError() throws {
        let container = try makeContainer()
        let store = AuthStore(modelContainer: container)
        _ = store.signUp(name: "Sam", email: "sam@example.com", password: "hunter2")
        store.signOut()

        let result = store.signIn(email: "sam@example.com", password: "wrong")
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.error, "Wrong password. Try again?")
        XCTAssertNil(store.currentUser)
    }

    func testSignInUnknownEmailReturnsNoAccountError() throws {
        let container = try makeContainer()
        let store = AuthStore(modelContainer: container)

        let result = store.signIn(email: "nobody@example.com", password: "whatever")
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.error, "No account with that email.")
        XCTAssertNil(store.currentUser)
    }

    func testSignOutClearsCurrentUser() throws {
        let container = try makeContainer()
        let store = AuthStore(modelContainer: container)
        _ = store.signUp(name: "Sam", email: "sam@example.com", password: "hunter2")
        XCTAssertNotNil(store.currentUser)

        store.signOut()
        XCTAssertNil(store.currentUser)
    }
}
