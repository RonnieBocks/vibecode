import SwiftUI
import AppKit

/// Loads bundled brawler portraits (Resources/BrawlerIcons/<name>.webp) and
/// provides placeholder helpers. Portraits are transparent character cutouts
/// of varying width, so callers show them with `.scaledToFit` on a tinted
/// background rather than cropping them to a fixed shape.
enum BrawlerArt {
    private static var imageCache: [Int: NSImage] = [:]

    /// Normalized filename base -> file URL, built once by scanning the bundle.
    private static let iconIndex: [String: URL] = {
        var index: [String: URL] = [:]
        for ext in ["webp", "png", "jpg", "jpeg"] {
            let urls = Bundle.module.urls(forResourcesWithExtension: ext,
                                          subdirectory: "BrawlerIcons") ?? []
            for url in urls {
                index[normalize(url.deletingPathExtension().lastPathComponent)] = url
            }
        }
        return index
    }()

    /// Brawlers whose API name differs from the artwork filename.
    private static let aliases: [String: String] = [
        "glowy": "glowbert",
        "larrylawrie": "larryandlawrie"
    ]

    static func image(for brawler: Brawler) -> NSImage? {
        if let cached = imageCache[brawler.id] { return cached }
        let key = normalize(brawler.name)
        let resolved = aliases[key] ?? key
        guard let url = iconIndex[resolved] ?? iconIndex[key],
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        imageCache[brawler.id] = image
        return image
    }

    private static var namedCache: [String: NSImage?] = [:]

    /// Portrait lookup by brawler name only (for tier-list chips, catalog rows).
    static func image(named name: String) -> NSImage? {
        let key = normalize(name)
        if let cached = namedCache[key] { return cached }
        let resolved = aliases[key] ?? key
        let img = (iconIndex[resolved] ?? iconIndex[key]).flatMap { NSImage(contentsOf: $0) }
        namedCache[key] = img
        return img
    }

    /// True pixel aspect ratio (width / height) of a portrait.
    static func aspect(_ image: NSImage) -> CGFloat {
        if let rep = image.representations.first, rep.pixelsHigh > 0 {
            return CGFloat(rep.pixelsWide) / CGFloat(rep.pixelsHigh)
        }
        return image.size.height > 0 ? image.size.width / image.size.height : 1
    }

    /// Lowercase and strip non-alphanumerics: "EL PRIMO"/"el_primo" -> "elprimo".
    static func normalize(_ s: String) -> String {
        String(s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    static func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    /// Stable per-brawler hue for the portrait background tint.
    static func tint(for name: String) -> Color {
        var hash: UInt64 = 1469598103934665603
        for byte in name.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return Color(hue: Double(hash % 360) / 360.0, saturation: 0.5, brightness: 0.62)
    }
}

/// The hero image for a brawler: a tinted gradient banner with the character
/// cutout centered at its natural aspect ratio (fit, never cropped). Falls
/// back to large initials when art is missing.
struct BrawlerPortraitView: View {
    let brawler: Brawler
    var height: CGFloat = 100
    /// Portraits are drawn with the character entering from the left of the
    /// frame, so cards anchor them leading and let the rarity color fill the
    /// right. Cards force the character to the full banner height (portraits
    /// always fill the canvas top-to-bottom), so the rarity color never bands
    /// above/below the character. The detail view instead fits the whole
    /// portrait, centered.
    var alignment: Alignment = .leading
    var fitWhole: Bool = false

    var body: some View {
        ZStack(alignment: alignment) {
            // Rarity color (matched to noff.gg), with a subtle depth gradient.
            BrawlerRarityTable.rarity(for: brawler.name).color
            LinearGradient(colors: [.clear, .black.opacity(0.18)],
                           startPoint: .top, endPoint: .bottom)

            if let image = BrawlerArt.image(for: brawler) {
                let base = Image(nsImage: image).resizable().interpolation(.high)
                if fitWhole {
                    base.aspectRatio(contentMode: .fit)
                } else {
                    // Force full banner height; width follows the true aspect
                    // ratio (left-anchored, clipped if it overruns the card).
                    base.frame(width: height * BrawlerArt.aspect(image), height: height)
                }
            } else {
                Text(BrawlerArt.initials(brawler.name))
                    .font(.system(size: height * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }
}
