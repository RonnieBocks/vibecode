import SwiftUI
import AppKit

/// Renders a bundled UI icon from Resources/UIIcons/<name>.(webp|png), falling
/// back to an SF Symbol until the artwork file has been added. Used for the
/// game-style loadout/trophy icons on brawler cards.
struct UIIcon: View {
    let name: String
    var size: CGFloat = 18
    var fallbackSymbol: String
    var fallbackTint: Color = .secondary

    var body: some View {
        if let image = UIIconStore.image(name) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: fallbackSymbol)
                .font(.system(size: size * 0.95))
                .foregroundStyle(fallbackTint)
                .frame(width: size, height: size)
        }
    }
}

enum UIIconStore {
    private static var cache: [String: NSImage?] = [:]

    private static let index: [String: URL] = {
        var index: [String: URL] = [:]
        for ext in ["webp", "png", "jpg", "jpeg"] {
            let urls = Bundle.module.urls(forResourcesWithExtension: ext,
                                          subdirectory: "UIIcons") ?? []
            for url in urls {
                index[url.deletingPathExtension().lastPathComponent.lowercased()] = url
            }
        }
        return index
    }()

    static func image(_ name: String) -> NSImage? {
        let key = name.lowercased()
        if let cached = cache[key] { return cached }
        let img = index[key].flatMap { NSImage(contentsOf: $0) }
        cache[key] = img
        return img
    }
}
