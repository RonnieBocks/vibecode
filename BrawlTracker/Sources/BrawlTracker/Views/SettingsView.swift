import SwiftUI

struct SettingsView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var tag: String = AppConfig.playerTag ?? ""
    @State private var token: String = Keychain.token ?? ""
    @State private var portalEmail: String = Keychain.portalEmail ?? ""
    @State private var portalPassword: String = Keychain.portalPassword ?? ""
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Connect your account")
                .font(.title2.weight(.bold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Player tag").font(.headline)
                TextField("#2PP0LV", text: $tag)
                    .textFieldStyle(.roundedBorder)
                Text("Find it under your profile in Brawl Stars.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("API token").font(.headline)
                SecureField("eyJ...", text: $token)
                    .textFieldStyle(.roundedBorder)
                Text("Create a key at developer.brawlstars.com → My Account → Create New Key, whitelisted to this Mac's public IP. Stored securely in your Keychain.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Automatic key renewal (optional)", systemImage: "arrow.triangle.2.circlepath").font(.headline)
                TextField("Developer portal email", text: $portalEmail).textFieldStyle(.roundedBorder)
                SecureField("Developer portal password", text: $portalPassword).textFieldStyle(.roundedBorder)
                Text("When your home IP changes and the API returns 403, the app logs into developer.brawlstars.com, revokes its old “BrawlTracker” key and creates a new one for the detected IP. Credentials stay in your Keychain.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let error = store.errorMessage, store.status == .failed {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Link("Open developer portal", destination: URL(string: "https://developer.brawlstars.com")!)
                    .font(.caption)
                Spacer()
                Button("Cancel") { dismiss() }
                Button(saving ? "Saving…" : "Save & Fetch") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(tag.trimmingCharacters(in: .whitespaces).isEmpty
                              || token.trimmingCharacters(in: .whitespaces).isEmpty
                              || saving)
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func save() {
        saving = true
        AppConfig.playerTag = AppConfig.normalizeTag(tag)
        Keychain.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        Keychain.portalEmail = portalEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        Keychain.portalPassword = portalPassword
        Task {
            await store.refresh()
            saving = false
            if store.status == .loaded { dismiss() }
        }
    }
}
