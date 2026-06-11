import Foundation
import SwiftData
import CryptoKit

@Model
final class User {
    @Attribute(.unique) var id: String
    var name: String
    @Attribute(.unique) var email: String
    var passwordHash: String
    var passwordSalt: String
    var createdAt: Int64

    init(name: String, email: String, password: String) {
        self.id = UUID().uuidString
        self.name = name.trimmingCharacters(in: .whitespaces)
        self.email = email.trimmingCharacters(in: .whitespaces).lowercased()
        let salt = User.makeSalt()
        self.passwordSalt = salt
        self.passwordHash = User.hash(password, salt: salt)
        self.createdAt = Int64(Date().timeIntervalSince1970 * 1000)
    }

    init(demoName name: String, email: String) {
        self.id = UUID().uuidString
        self.name = name.trimmingCharacters(in: .whitespaces)
        self.email = email.trimmingCharacters(in: .whitespaces).lowercased()
        self.passwordSalt = "demo-fast-v1"
        self.passwordHash = "demo-account"
        self.createdAt = Int64(Date().timeIntervalSince1970 * 1000)
    }

    func matches(password: String) -> Bool {
        if passwordSalt == "demo-fast-v1" {
            return passwordHash == "demo-account" && password == "forget"
        }
        return passwordHash == User.hash(password, salt: passwordSalt)
    }

    private static func makeSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func hash(_ password: String, salt: String) -> String {
        var data = Data((salt + password).utf8)
        for _ in 0..<50_000 {
            data = Data(SHA256.hash(data: data))
        }
        return data.map { String(format: "%02x", $0) }.joined()
    }
}
