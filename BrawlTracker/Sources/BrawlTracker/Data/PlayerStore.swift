import Foundation
import Observation

@MainActor
@Observable
final class PlayerStore {
    enum Status: Equatable {
        case idle, loading, loaded, needsSetup, failed
    }

    var player: Player?
    var battles: [BattleEntry] = []
    var catalog: [Int: CatalogBrawler] = [:]        // official /brawlers (id -> entry)
    var reference: [Int: ReferenceBrawler] = [:]    // BrawlAPI reference (id -> entry)

    var status: Status = .idle
    var errorMessage: String?
    /// True when the visible data is the bundled sample, not a live fetch.
    var usingSample = false
    var lastUpdated: Date?
    /// Transient user-facing notice ("Archived 12 new battles", "Key renewed…").
    var toast: String?

    // MARK: - Launch load

    /// Called on launch. Uses live API if configured; otherwise shows the
    /// bundled sample and flags that setup is needed.
    func load() async {
        async let ref = ReferenceStore.load()   // BrawlAPI reference, in parallel
        if AppConfig.isConfigured,
           let token = Keychain.token,
           let tag = AppConfig.playerTag {
            await fetchLive(token: token, tag: tag)
        } else {
            loadSample()
            status = .needsSetup
        }
        reference = await ref
    }

    /// Re-fetch (after the user saves settings or taps refresh).
    func refresh() async {
        async let ref = ReferenceStore.load()
        if let token = Keychain.token, let tag = AppConfig.playerTag {
            await fetchLive(token: token, tag: tag)
        } else {
            status = .needsSetup
        }
        reference = await ref
    }

    private func fetchLive(token: String, tag: String, renewed: Bool = false) async {
        status = .loading
        errorMessage = nil
        let client = BrawlAPIClient(token: token)
        do {
            // Player is required; battle log + catalog are best-effort.
            async let playerResult = client.player(tag: tag)
            async let battleResult = client.battleLog(tag: tag)
            async let catalogResult = client.brawlers()

            let player = try await playerResult
            self.player = player
            self.battles = (try? await battleResult)?.items ?? []
            if let cat = try? await catalogResult {
                self.catalog = Dictionary(uniqueKeysWithValues: cat.items.map { ($0.id, $0) })
            }
            self.usingSample = false
            self.lastUpdated = Date()
            self.status = .loaded
        } catch let error as BrawlAPIError {
            // Automatic key renewal: the IP changed and portal credentials exist.
            if error.kind == .invalidIP, !renewed, let ip = error.detectedIP, Keychain.canAutoRenew,
               let email = Keychain.portalEmail, let password = Keychain.portalPassword {
                do {
                    let newToken = try await DevPortalClient().regenerate(email: email, password: password, ip: ip)
                    Keychain.token = newToken
                    toast = "API key renewed for IP \(ip)"
                    await fetchLive(token: newToken, tag: tag, renewed: true)
                    return
                } catch {
                    self.errorMessage = "Key renewal failed: \(error.localizedDescription) — \(BrawlAPIError(kind: .invalidIP, statusCode: 403, detectedIP: ip, detail: "").userMessage)"
                    self.status = .failed
                    if player == nil { loadSample() }
                    return
                }
            }
            self.errorMessage = error.userMessage
            self.status = .failed
            if player == nil { loadSample() }   // keep something on screen
        } catch {
            self.errorMessage = "Unexpected error: \(error.localizedDescription)"
            self.status = .failed
            if player == nil { loadSample() }
        }
    }

    // MARK: - Sample fallback

    func loadSample() {
        guard let url = Bundle.module.url(forResource: "sample_player", withExtension: "json") else {
            errorMessage = "sample_player.json not found in bundle."
            return
        }
        do {
            let data = try Data(contentsOf: url)
            player = try JSONDecoder().decode(Player.self, from: data)
            usingSample = true
        } catch {
            errorMessage = "Failed to decode sample data: \(error)"
        }
    }
}
