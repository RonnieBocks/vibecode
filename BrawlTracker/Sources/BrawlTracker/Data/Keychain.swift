import Foundation
import Security

/// Minimal Keychain wrapper for the API token. The token never lives in
/// UserDefaults or on disk in plaintext.
enum Keychain {
    private static let service = "com.ronnie.brawltracker"
    private static let account = "apiToken"

    static var token: String? {
        get { read(account: account) }
        set {
            if let value = newValue, !value.isEmpty { write(value, account: account) }
            else { delete(account: account) }
        }
    }

    /// Developer-portal login used only for automatic key renewal.
    static var portalEmail: String? {
        get { read(account: "portalEmail") }
        set { if let v = newValue, !v.isEmpty { write(v, account: "portalEmail") } else { delete(account: "portalEmail") } }
    }
    static var portalPassword: String? {
        get { read(account: "portalPassword") }
        set { if let v = newValue, !v.isEmpty { write(v, account: "portalPassword") } else { delete(account: "portalPassword") } }
    }
    static var canAutoRenew: Bool { !(portalEmail ?? "").isEmpty && !(portalPassword ?? "").isEmpty }

    // MARK: - Generic helpers

    private static func write(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func read(account: String) -> String? {
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
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Non-secret app configuration (the player tag).
enum AppConfig {
    private static let tagKey = "playerTag"

    static var playerTag: String? {
        get { UserDefaults.standard.string(forKey: tagKey) }
        set { UserDefaults.standard.set(newValue, forKey: tagKey) }
    }

    /// Normalizes a tag to the `#XXXX` form the API expects.
    static func normalizeTag(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if t.hasPrefix("#") { t.removeFirst() }
        return "#" + t
    }

    static var isConfigured: Bool {
        (playerTag?.isEmpty == false) && (Keychain.token?.isEmpty == false)
    }
}
