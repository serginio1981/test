import Foundation
import Security

/// Almacenamiento de secretos en el llavero del sistema (API key de Anthropic,
/// tokens de Microsoft...). Nunca en UserDefaults ni en logs.
enum KeychainStore {
    private static let service = "com.serginio.jarvis"
    private static let apiKeyAccount = "anthropic-api-key"
    static let microsoftTokensAccount = "microsoft-tokens"

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    // MARK: - API genérica

    static func save(_ value: String, account: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            delete(account: account)
            return
        }
        SecItemDelete(baseQuery(account: account) as CFDictionary)
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    // MARK: - API key de Anthropic (mismo account de siempre: compatible)

    static func saveAPIKey(_ key: String) { save(key, account: apiKeyAccount) }
    static func readAPIKey() -> String? { read(account: apiKeyAccount) }
    static func deleteAPIKey() { delete(account: apiKeyAccount) }

    static var hasAPIKey: Bool {
        readAPIKey() != nil
    }
}
