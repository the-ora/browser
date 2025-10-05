import Foundation
import Security

// MARK: - Keychain Service

class KeychainService {
    static let shared = KeychainService()

    private init() {}

    // MARK: - Store Data

    func store(_ data: Data, forKey key: String) -> Bool {
        // Delete any existing item first
        _ = delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.orabrowser.app.keychain",  // Fixed service identifier
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func store(_ string: String, forKey key: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return store(data, forKey: key)
    }

    // MARK: - Retrieve Data

    func retrieve(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.orabrowser.app.keychain",  // Fixed service identifier
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess else { return nil }
        return dataTypeRef as? Data
    }

    func retrieveString(key: String) -> String? {
        guard let data = retrieve(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete Data

    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.orabrowser.app.keychain"  // Fixed service identifier
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Check if Key Exists

    func exists(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.orabrowser.app.keychain",  // Fixed service identifier
            kSecReturnData as String: kCFBooleanFalse!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - API Key Storage Helper

extension KeychainService {
    // MARK: - OpenAI

    func storeOpenAIKey(_ key: String) -> Bool {
        return store(key, forKey: "openai_api_key")
    }

    func getOpenAIKey() -> String? {
        return retrieveString(key: "openai_api_key")
    }

    func deleteOpenAIKey() -> Bool {
        return delete(key: "openai_api_key")
    }

    func hasOpenAIKey() -> Bool {
        return exists(key: "openai_api_key") && !(getOpenAIKey()?.isEmpty ?? true)
    }

    // MARK: - Future providers can be added here

    // Example:
    // func storeClaudeKey(_ key: String) -> Bool { ... }
    // func getClaudeKey() -> String? { ... }
}
