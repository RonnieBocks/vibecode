import Foundation

/// Structured error from the official Brawl Stars API, with friendly messaging
/// and the caller's detected IP parsed out of 403 bodies (so the user knows
/// exactly which IP to whitelist).
struct BrawlAPIError: Error {
    enum Kind {
        case invalidIP        // 403 — this machine's IP isn't whitelisted for the key
        case badToken         // 403 — token wrong/expired
        case notFound         // 404 — tag not found
        case rateLimited      // 429
        case server           // 5xx
        case network          // no connectivity, timeout
        case decoding
        case other
    }

    let kind: Kind
    let statusCode: Int?
    let detectedIP: String?
    let detail: String

    var userMessage: String {
        switch kind {
        case .invalidIP:
            let ip = detectedIP.map { " This Mac's public IP is \($0)." } ?? ""
            return "The API key isn't authorized for this network (403).\(ip) Add that IP to your key at developer.brawlstars.com → your key → Allowed IPs."
        case .badToken:
            return "The API token was rejected (403). Re-check or paste a new key from developer.brawlstars.com."
        case .notFound:
            return "That player tag wasn't found (404). Double-check it in Settings."
        case .rateLimited:
            return "Rate limited by the API (429). Try again in a moment."
        case .server:
            return "The Brawl Stars API is having problems (\(statusCode.map(String.init) ?? "5xx")). Try again later."
        case .network:
            return "Couldn't reach the Brawl Stars API. Check your internet connection."
        case .decoding:
            return "Got an unexpected response from the API. \(detail)"
        case .other:
            return "API error\(statusCode.map { " (\($0))" } ?? ""). \(detail)"
        }
    }
}

/// Thin async client for the official API. IP-whitelisted bearer-token auth.
struct BrawlAPIClient {
    private let base = URL(string: "https://api.brawlstars.com/v1")!
    private let token: String
    private let session: URLSession

    init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    // MARK: - Endpoints

    func player(tag: String) async throws -> Player {
        try await get("/players/\(encode(tag))")
    }

    func battleLog(tag: String) async throws -> BattleLog {
        try await get("/players/\(encode(tag))/battlelog")
    }

    func brawlers() async throws -> BrawlerCatalog {
        try await get("/brawlers")
    }

    // MARK: - Core

    private func encode(_ tag: String) -> String {
        // The '#' in a tag must be percent-encoded.
        tag.replacingOccurrences(of: "#", with: "%23")
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: base.absoluteString + path) else {
            throw BrawlAPIError(kind: .other, statusCode: nil, detectedIP: nil, detail: "Bad URL")
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw BrawlAPIError(kind: .network, statusCode: nil, detectedIP: nil,
                                detail: error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw BrawlAPIError(kind: .other, statusCode: nil, detectedIP: nil, detail: "No HTTP response")
        }

        switch http.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw BrawlAPIError(kind: .decoding, statusCode: 200, detectedIP: nil,
                                    detail: "\(error)")
            }
        case 403:
            let body = String(data: data, encoding: .utf8) ?? ""
            let ip = Self.parseDetectedIP(from: body)
            // The invalid-IP 403 body mentions the client IP; a bad-token 403
            // typically does not.
            let isIPProblem = ip != nil || body.lowercased().contains("ip")
            throw BrawlAPIError(kind: isIPProblem ? .invalidIP : .badToken,
                                statusCode: 403, detectedIP: ip, detail: body)
        case 404:
            throw BrawlAPIError(kind: .notFound, statusCode: 404, detectedIP: nil, detail: "")
        case 429:
            throw BrawlAPIError(kind: .rateLimited, statusCode: 429, detectedIP: nil, detail: "")
        case 500...599:
            throw BrawlAPIError(kind: .server, statusCode: http.statusCode, detectedIP: nil, detail: "")
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw BrawlAPIError(kind: .other, statusCode: http.statusCode, detectedIP: nil, detail: body)
        }
    }

    /// Extracts the first IPv4 address from a 403 body (Supercell reports the
    /// detected client IP there), avoiding any third-party IP lookup.
    static func parseDetectedIP(from body: String) -> String? {
        let pattern = #"(\d{1,3}\.){3}\d{1,3}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(body.startIndex..., in: body)
        guard let match = regex.firstMatch(in: body, range: range),
              let r = Range(match.range, in: body) else { return nil }
        return String(body[r])
    }
}
