import Foundation
import Security

/// Cloudflare API token. Never written to the vault, UserDefaults, or logs.
public enum PublishKeychain {
    public static let service = "dev.drawmeanelephant.banal.publish"

    public static func account(for vaultURL: URL) -> String {
        vaultURL.standardizedFileURL.path
    }

    public static func save(token: String, vaultURL: URL) throws {
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            delete(vaultURL: vaultURL)
            return
        }
        delete(vaultURL: vaultURL)
        let account = account(for: vaultURL)
        let payload = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: payload,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PublishKeychainError.saveFailed(status)
        }
    }

    public static func token(vaultURL: URL) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: vaultURL),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func hasToken(vaultURL: URL) -> Bool {
        token(vaultURL: vaultURL)?.isEmpty == false
    }

    public static func delete(vaultURL: URL) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: vaultURL),
        ]
        SecItemDelete(query as CFDictionary)
    }
}

public enum PublishKeychainError: Error, Equatable, Sendable {
    case saveFailed(OSStatus)
}
