import Foundation
import HTSAPI
import Security

/// Where the login session lives on the device (docs/decisions/0031).
protocol SessionStoring: AnyObject, Sendable {
    func load() -> AuthSession?
    func save(_ session: AuthSession) throws
    func clear()
}

enum SessionStore {
    /// Set in `UserDefaults` on the first launch. It goes away with the app; the Keychain does not.
    static let installedKey = "HTSInstalled"
}

extension SessionStoring {
    /// Deleting the app asks for the login again (Leo's call): iOS keeps Keychain items after the app is deleted,
    /// so a launch without the install marker clears the session before anything else. Not while protected data is
    /// unavailable (a prewarmed launch before the first unlock): `UserDefaults` can read empty then, and the user
    /// would be logged out on their own.
    func resetIfFreshInstall(defaults: UserDefaults = .standard, protectedDataAvailable: Bool) {
        guard protectedDataAvailable, !defaults.bool(forKey: SessionStore.installedKey) else { return }
        clear()
        defaults.set(true, forKey: SessionStore.installedKey)
    }
}

/// The session as JSON in a generic password item, readable after the first unlock and never leaving this device.
final class KeychainSessionStore: SessionStoring {
    private let service = "com.hardtosubmit.app.session"
    private let account = "current"

    func load() -> AuthSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    func save(_ session: AuthSession) throws {
        clear()
        var item = baseQuery
        item[kSecValueData as String] = try JSONEncoder().encode(session)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

struct KeychainError: Error {
    let status: OSStatus
}

/// For tests and previews.
final class InMemorySessionStore: SessionStoring, @unchecked Sendable {
    private var session: AuthSession?

    init(_ session: AuthSession? = nil) {
        self.session = session
    }

    func load() -> AuthSession? { session }
    func save(_ session: AuthSession) throws { self.session = session }
    func clear() { session = nil }
}
