import SwiftUI

struct BrawlerCard: View {
    let brawler: Brawler

    private let cardHeight: CGFloat = 124
    private let barWidth: CGFloat = 48

    var body: some View {
        HStack(spacing: 0) {
            // Left: portrait + trophy/progress bar
            VStack(spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    BrawlerPortraitView(brawler: brawler, height: cardHeight - 26)
                    Text(brawler.name.uppercased())
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.8), radius: 1.5, y: 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 4)
                }
                TrophyBar(trophies: brawler.trophies, highest: brawler.highestTrophies)
                    .frame(height: 26)
            }

            LoadoutBar(brawler: brawler)
                .frame(width: barWidth)
        }
        .frame(height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Trophy / progress bar

struct TrophyBar: View {
    let trophies: Int
    let highest: Int

    /// Progress within the current 1000-trophy band (e.g. 1400 -> 400/1000).
    private var inBand: Int { trophies % 1000 }
    private var fraction: Double { Double(inBand) / 1000 }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Capsule().fill(Color.black.opacity(0.55))
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.24, green: 0.7, blue: 1),
                                                  Color(red: 0.1, green: 0.5, blue: 0.95)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: max(4, geo.size.width * fraction))
            }
            .clipShape(Capsule())
            .padding(.horizontal, 6)

            HStack(spacing: 4) {
                UIIcon(name: "trophy", size: 14, fallbackSymbol: "trophy.fill", fallbackTint: .yellow)
                Text("\(inBand)/1000")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
            }
        }
        .background(Color.black.opacity(0.25))
    }
}

// MARK: - Vertical loadout bar

struct LoadoutBar: View {
    let brawler: Brawler

    // Fixed magenta bar background for every brawler (independent of rarity).
    private static let magentaTop = Color(red: 0.80, green: 0.18, blue: 0.82)
    private static let magentaBottom = Color(red: 0.55, green: 0.10, blue: 0.62)

    private var gearCount: Int { brawler.gears.count }
    private var gadgetIcon: String { (brawler.buffies?.gadget ?? false) ? "gadget_buffy" : "gadget" }
    private var starIcon: String { (brawler.buffies?.starPower ?? false) ? "starpower_buffy" : "starpower" }
    private var hyperBuffy: Bool { brawler.buffies?.hyperCharge ?? false }

    var body: some View {
        VStack(spacing: 0) {
            LevelBadge(power: brawler.power,
                       hypercharged: brawler.hasHypercharge,
                       buffy: hyperBuffy)
                .frame(maxHeight: .infinity)

            LoadoutCell(icon: gadgetIcon, fallback: "bolt.fill", unlocked: !brawler.gadgets.isEmpty)
                .frame(maxHeight: .infinity)
            LoadoutCell(icon: starIcon, fallback: "star.fill", unlocked: !brawler.starPowers.isEmpty)
                .frame(maxHeight: .infinity)

            HStack(spacing: 4) {
                LoadoutCell(icon: "gear", fallback: "gearshape.fill", unlocked: gearCount >= 1, size: 19)
                LoadoutCell(icon: "gear", fallback: "gearshape.fill", unlocked: gearCount >= 2, size: 19)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Self.magentaTop, Self.magentaBottom],
                           startPoint: .top, endPoint: .bottom)
        )
    }
}

/// The top badge: power number, or the hypercharge flame with the number on it.
struct LevelBadge: View {
    let power: Int
    let hypercharged: Bool
    let buffy: Bool

    var body: some View {
        ZStack {
            if hypercharged {
                UIIcon(name: buffy ? "hypercharge_buffy" : "hypercharge",
                       size: 30, fallbackSymbol: "flame.fill", fallbackTint: .pink)
                Text("\(power)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .offset(y: 2)
                    .shadow(color: .black.opacity(0.6), radius: 1)
            } else {
                Circle()
                    .fill(LinearGradient(colors: power >= 11
                                            ? [Color(red: 0.98, green: 0.78, blue: 0.20), Color(red: 0.85, green: 0.55, blue: 0.08)]
                                            : [Color(red: 0.55, green: 0.2, blue: 0.85), Color(red: 0.36, green: 0.1, blue: 0.6)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2))
                    .frame(width: 28, height: 28)
                Text(power >= 11 ? "MAX" : "\(power)")
                    .font(.system(size: power >= 11 ? 8 : 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(height: 30)
    }
}

/// One loadout slot: the icon when unlocked, or a grey placeholder in the
/// same shape (the icon desaturated + dimmed) when not.
struct LoadoutCell: View {
    let icon: String
    let fallback: String
    let unlocked: Bool
    var size: CGFloat = 26

    var body: some View {
        UIIcon(name: icon, size: size, fallbackSymbol: fallback,
               fallbackTint: unlocked ? .primary : .secondary)
            .grayscale(unlocked ? 0 : 1)
            .brightness(unlocked ? 0 : -0.15)
            .opacity(unlocked ? 1 : 0.32)
    }
}

/// Kept for the detail view header.
struct PowerBadge: View {
    let power: Int

    var body: some View {
        Text("\(power)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(power >= 11 ? Color.purple : Color.blue, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
            .shadow(radius: 2, y: 1)
    }
}
