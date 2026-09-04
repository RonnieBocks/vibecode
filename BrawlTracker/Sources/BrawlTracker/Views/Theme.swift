import SwiftUI

/// Shared design tokens so every tab reads as one system.
enum Theme {
    static let radius: CGFloat = 14
    static let radiusSmall: CGFloat = 10
    static let spacing: CGFloat = 16
    static let teamBlue = Color(red: 0.24, green: 0.52, blue: 0.98)
    static let teamRed = Color(red: 0.93, green: 0.30, blue: 0.30)
    static let gold = Color(red: 0.98, green: 0.78, blue: 0.20)
    static let magenta = Color(red: 0.80, green: 0.18, blue: 0.82)
    static let brandGradient = LinearGradient(colors: [Color(red: 0.95, green: 0.55, blue: 0.15),
                                                       Color(red: 0.80, green: 0.18, blue: 0.82)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// Bottom toast that fades after a few seconds.
struct ToastView: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text(text).font(.callout)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
        .shadow(radius: 8, y: 4)
        .padding(.bottom, 16)
    }
}

/// First-run checklist shown until the account is connected.
struct SetupChecklistView: View {
    let connected: Bool
    let hasPool: Bool
    let hasTiers: Bool
    let onConnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GET SET UP").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            row(done: connected, "Connect your account (player tag + API key)") {
                Button("Connect") { onConnect() }.buttonStyle(.borderedProminent).controlSize(.small)
            }
            row(done: hasPool, "Build this season's map pool in Maps (or Autofill rotation)") { EmptyView() }
            row(done: hasTiers, "Sort brawlers into your Tier List") { EmptyView() }
            row(done: false, "Start a Season in Progression, then run your first Ranked draft") { EmptyView() }
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1))
    }

    private func row<A: View>(done: Bool, _ text: String, @ViewBuilder action: () -> A) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle").foregroundStyle(done ? .green : .secondary)
            Text(text).font(.callout).foregroundStyle(done ? .secondary : .primary).strikethrough(done)
            Spacer()
            action()
        }
    }
}
