import Foundation

/// Supercell developer-portal client used to renew the API key when this
/// Mac's public IP changes. Uses the same (undocumented) endpoints the
/// community key-managers use: login → list → revoke old → create for IP.
struct DevPortalClient {
    private let base = URL(string: "https://developer.brawlstars.com/api")!
    private let session: URLSession
    static let keyName = "BrawlTracker"

    init() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.httpCookieAcceptPolicy = .always
        cfg.httpShouldSetCookies = true
        cfg.timeoutIntervalForRequest = 20
        session = URLSession(configuration: cfg)
    }

    struct PortalError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private struct KeyList: Decodable { let keys: [Key]? }
    private struct Key: Decodable { let id: String; let name: String?; let cidrRanges: [String]?; let key: String? }
    private struct Created: Decodable { let key: Key? }

    /// Full renewal: returns a fresh token authorised for `ip`.
    func regenerate(email: String, password: String, ip: String) async throws -> String {
        try await login(email: email, password: password)
        let existing = try await listKeys()
        for k in existing where k.name == Self.keyName { try? await revoke(id: k.id) }
        // The portal caps keys at 10; if we're still full, drop the oldest.
        if existing.filter({ $0.name != Self.keyName }).count >= 10, let victim = existing.first {
            try? await revoke(id: victim.id)
        }
        return try await create(ip: ip)
    }

    private func login(email: String, password: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let (data, resp) = try await post("login", body: body)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["description"] as? String
            throw PortalError(message: msg ?? "Developer portal login failed (check email/password).")
        }
    }

    private func listKeys() async throws -> [Key] {
        let (data, _) = try await post("apikey/list", body: Data("{}".utf8))
        return (try? JSONDecoder().decode(KeyList.self, from: data))?.keys ?? []
    }

    private func revoke(id: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["id": id])
        _ = try await post("apikey/revoke", body: body)
    }

    private func create(ip: String) async throws -> String {
        let payload: [String: Any] = [
            "name": Self.keyName,
            "description": "Auto-renewed by BrawlTracker on \(ISO8601DateFormatter().string(from: Date()))",
            "cidrRanges": [ip],
            "scopes": NSNull(),
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await post("apikey/create", body: body)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let token = (try? JSONDecoder().decode(Created.self, from: data))?.key?.key, !token.isEmpty else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["description"] as? String
            throw PortalError(message: msg ?? "The portal did not return a new key.")
        }
        return token
    }

    private func post(_ path: String, body: Data) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await session.data(for: req)
    }
}
