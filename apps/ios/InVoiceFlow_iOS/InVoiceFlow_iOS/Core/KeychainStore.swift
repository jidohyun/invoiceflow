import Foundation
import Security

/// AMI-88 (iOS): Keychain-backed token storage. Used by `APIClient` for
/// the Bearer header and by `AuthViewModel` to bootstrap the logged-in
/// state on cold launch.
///
/// Synchronous on purpose — Keychain is fast (microseconds) and async
/// wrappers add no value here. All callers are MainActor.
@MainActor
final class KeychainStore {
    static let shared = KeychainStore()

    private let service = "com.invoiceflow.ios.auth"

    private init() {}

    func save(token: String, account: String = "session") {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var attrs = query
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attrs as CFDictionary, nil)
    }

    func token(account: String = "session") -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    func clear(account: String = "session") {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
