# BrawlTracker — Developer Handoff

Everything needed to build, run, change, and rescue this app without any outside help.
Read the **Failsafe checklist** first; everything else is reference.

---

## 0. Failsafe checklist (do these today)

1. **Put the code under version control. It is not in git.** This is the single biggest risk.
   ```bash
   cd /Applications/BrawlTracker
   git init && git add -A && git commit -m "Initial import of BrawlTracker"
   ```
   Then push it somewhere (GitHub private repo, or even a second disk).
2. **Back up your data.** All app data lives in one folder; copy it anywhere safe:
   ```bash
   cp -R "$HOME/Library/Application Support/BrawlTracker" ~/Desktop/BrawlTracker-data-$(date +%F)
   ```
   Restoring is just copying it back while the app is quit.
3. **Back up the project folder** (`/Applications/BrawlTracker`) the same way. The built app in
   `/Applications/BrawlTracker.app` is disposable — it is rebuilt from the project by one script.
4. Keep **Xcode** installed (the Command Line Tools alone cannot compile SwiftUI on this macOS).

---

## 1. What this is

A native macOS app (SwiftUI, Swift Package Manager) that tracks a Brawl Stars account and runs a
ranked draft assistant. Everything is local: JSON files in Application Support, secrets in Keychain,
no server of ours anywhere.

- Project: `/Applications/BrawlTracker` (Swift package — this is the source of truth)
- Installed app: `/Applications/BrawlTracker.app` (a build product; regenerate with `make_app.sh`)
- Data: `~/Library/Application Support/BrawlTracker/` (see §5)
- Secrets: macOS Keychain, service `com.ronnie.brawltracker`

Size: ~8,100 lines of Swift across 48 files, plus 28 unit tests.

---

## 2. Build, run, test, package

**Requirements:** macOS 14+, full Xcode (`xcode-select -p` must point at `/Applications/Xcode.app/Contents/Developer`),
license accepted (`sudo xcodebuild -license accept`). Toolchain in use: Swift 6.x, package tools-version 5.10
(Swift 5 language mode — do not bump to 6 without fixing strict-concurrency errors).

```bash
cd /Applications/BrawlTracker
swift build                 # debug build (fast, ~2–5 s incremental)
swift test                  # runs the 28 unit tests (draft engine, costs, calibration, checklist…)
./make_app.sh               # release build → assembles /Applications/BrawlTracker.app → launches nothing
open -a /Applications/BrawlTracker.app
```

Do **not** run the bare binary in `.build/` — a plain executable has no Info.plist, so it gets no proper
window/Dock presence. Always go through `make_app.sh`. If a build is interrupted (e.g. a killed process),
the next release build can take several minutes while the cache rebuilds; that is normal.

`make_app.sh` does: `swift build -c release` → copies the executable and the SPM resource bundle
(`BrawlTracker_BrawlTracker.bundle`, which holds the sample player JSON and all icons) into
`Contents/Resources`, copies `AppIcon.icns`, writes Info.plist + PkgInfo, ad-hoc codesigns.
The bundle ID is `com.ronnie.brawltracker`. If you ever change the package/target name, update the
script's `APP_NAME` and the resource-bundle name (`<Package>_<Target>.bundle`).

`scripts/make_icon.swift` regenerates the app icon (`swift scripts/make_icon.swift Sources/BrawlTracker/Resources/Icon`
then `iconutil -c icns …`). The `Resources/Icon` folder is excluded from SPM processing on purpose.

Opening in Xcode: **File ▸ Open** the `/Applications/BrawlTracker` folder (it's a package). Run from Xcode works,
but the shipped app still comes from `make_app.sh`.

---

## 3. Project layout

```
Sources/BrawlTracker/
  BrawlTrackerApp.swift     App entry, sidebar tabs, RootView, menu commands (⌘R refresh, ⌘1–7 tabs),
                            AccountFooter, banners/toasts, first-run checklist. All stores are created here
                            and injected with .environment(...).
  Data/                     @Observable stores (one per concern), all persisted to Application Support
    PlayerStore             Live account fetch on launch (player + battle log + catalog), sample fallback,
                            auto key renewal on invalid-IP 403, toast messages.
    TierListStore           Named tier lists, drag/drop moves, reset backup + restore, legacy migration.
    MapDataStore            Maps + game modes (cached weekly), named map pools, live-rotation autofill.
    MatchLogStore           Saved ranked matches (draft + series result).
    BattleArchiveStore      Permanent battle archive (API only keeps 25), allies/opponents, stats helpers.
    SeasonStore             Seasons: start/end snapshots, manual resource logs, gains.
    SnapshotStore           Per-fetch account snapshots (data only, no charts).
    SkinStore               Wardrobe (observed equipped skins + manual entries/costs).
    RankedSettings          Brawlers hidden from the ranked assistant.
    DraftConfigStore        The editable draft model (weights + playbook rules), migration on defaults change.
    DraftLearning           Derived model from battles + matches (recency-weighted). Rebuilt from raw data;
                            never persisted, so new seasons/pools need no reset.
    ReferenceStore          BrawlAPI brawler reference (class, rarity, all gadgets/star powers), cached weekly.
    Keychain                API token + developer-portal login. AppConfig: player tag (UserDefaults).
    JSONStore               Shared load/save helper (ISO-8601 dates). Newer stores use it; older ones have
                            their own save/load — see §8 gotchas.
  Models/
    Player, Battle, BrawlerCatalog, BrawlAPIReference, GameMap, MatchRecord   API/data shapes
    BrawlerRarity           Rarity per brawler (noff palette), used for portrait backgrounds
    UpgradeCosts            Level ladder + item prices; spent / to-eligible / to-max with itemized lines
    DraftPlaybook           Roster→class map, mode→meta, guide text; reads live `config`
    DraftConfig             All tunable weights + playbook rules (migration-tolerant decoding, versioned)
    DraftEngine             Ban/pick scoring, perspective (you/teammate/enemy), backup swap, counters
    WinProbability          Live win chance with shrinkage + clamp
    DraftChecklist          Order-agnostic comp checklist
    MatchTips               In-match tips (prose) + `GamePlan` (glanceable structured plan)
    MatchAnalysis           Post-match review (bans, draft, result, lessons)
  Networking/
    BrawlAPIClient          Official API (bearer token, IP-whitelisted). Parses detected IP from 403 bodies.
    DevPortalClient         developer.brawlstars.com login → revoke → create key (undocumented endpoints)
  Views/                    One file per tab/sheet. RankedView is the big one (draft session + board).
  Resources/
    sample_player.json      Real /players/{tag} pull used when not connected
    BrawlerIcons/*.webp     107 portraits named by normalized brawler name (see BrawlerArt aliases)
    UIIcons/*.png           Loadout/trophy/gear/buffie icons
    Icon/AppIcon.icns       App icon (generated)
Tests/BrawlTrackerTests/    XCTest; `@testable import BrawlTracker`. Tests set DraftPlaybook.config = .defaults.
```

---

## 4. External services

| Service | Used for | Auth | Notes |
|---|---|---|---|
| `https://api.brawlstars.com/v1` | `/players/{tag}`, `/players/{tag}/battlelog`, `/brawlers` | Bearer key from developer.brawlstars.com, **locked to your public IP** | `#` in tags → `%23`. Battle log = last ~25 only. No currency balances, no owned-skin inventory. |
| `https://developer.brawlstars.com/api` | Auto key renewal: `login`, `apikey/list`, `apikey/revoke`, `apikey/create` | Portal email/password (Keychain) | Undocumented community endpoints; may change. Triggered only on an invalid-IP 403. |
| `https://api.brawlapi.com/v1` | `/brawlers` (reference), `/maps`, `/gamemodes`, `/events` (rotation) | none | Cached 7 days on disk. `/events` is frequently empty. No skins endpoint. |
| Bundled assets | portraits, icons, rarity colors | — | Pulled once from noff.gg during development and shipped in the bundle; **nothing is fetched from noff at runtime**. Map images load from `cdn.brawlify.com` via `AsyncImage`. |

To add a new brawler's art: drop `<normalized-name>.webp` into `Resources/BrawlerIcons` (normalization =
lowercase alphanumerics; e.g. `El Primo` → `elprimo.webp`). Two known aliases live in `BrawlerArt.aliases`
(`glowy→glowbert`, `larrylawrie→larryandlawrie`). Add a rarity in `BrawlerRarity.swift` and a draft class in
`DraftPlaybook.roster` (or set it in-app under Draft Model ▸ Brawler classes).

---

## 5. Data files (`~/Library/Application Support/BrawlTracker/`)

| File | What | Safe to delete? |
|---|---|---|
| `tierlists.json` | All named tier lists + active id | No — your tier lists |
| `tierlists.backup.json` | Auto-backup written before a Reset | Yes |
| `tierlist.json`, `rotation.json` | **Legacy** single-list / single-rotation files from before migration | Yes (kept as an extra backup) |
| `tierlists.pre-restore.json` | The emptied file saved during the Sep 2 recovery | Yes |
| `map_pools.json` | Named map pools + active id | No |
| `matches.json` | Logged ranked matches (draft, suggestions, series, win chance) | No |
| `battles.json` | Permanent battle archive incl. allies/opponents | No |
| `seasons.json` | Seasons + manual resource logs | No |
| `snapshots.json` | Per-fetch account snapshots | No (regrows) |
| `skins.json` | Wardrobe | No |
| `ranked_settings.json` | Hidden-from-ranked brawlers | Regenerates with defaults |
| `draft_config.json` | Editable draft model | Regenerates with defaults (loses tweaks/overrides) |
| `brawlapi_cache.json`, `maps_cache.json`, `gamemodes_cache.json` | 7-day caches | Yes (re-fetched) |

Secrets are **not** in this folder: API token, portal email and password are Keychain items under service
`com.ronnie.brawltracker` (accounts `apiToken`, `portalEmail`, `portalPassword`). The player tag is in
UserDefaults key `playerTag`; last selected tab is `lastTab`.

**Restore procedure for any file:** quit the app, copy the backup into place, relaunch. The app reads
everything at launch and writes on change, so never edit files while it is running.

---

## 6. How the app is wired

- Every store is an `@MainActor @Observable final class`, created once in `BrawlTrackerApp` and passed down
  with `.environment(store)`. Views read them with `@Environment(Type.self)`.
- **Sheets do not reliably inherit `@Observable` environment values.** Every `.sheet { … }` in the codebase
  re-injects what it needs (`.environment(store).environment(archive)…`). If a sheet crashes on open with a
  missing-environment message, that's why.
- `RootView.onChange(of: store.lastUpdated)` is the "after every live fetch" hook: it archives new battles,
  observes equipped skins, records a snapshot, and shows a toast.
- `DraftPlaybook.config` is a **static** that `DraftConfigStore` sets in its `init` and on every change.
  The engine, learning model, win chance and checklist all read it. In tests, reset it in `setUp`.

---

## 7. The draft assistant (the part worth understanding)

Pipeline (all numbers editable in-app under Ranked ▸ Draft Model, stored in `draft_config.json`):

1. **Classify** — mode → meta (Aggro / Passive); global pick 1–6 → slot (1st / 2–3 / 4–5 / Last);
   each brawler → one of 7 draft classes.
2. **Bans** — `roleRank×1000 + tier×100 + callout 300 + threat (brawlers you lose to, ≤400)`.
3. **Picks** — targets for the slot (or backup roles if the slot's roles are already covered; the meta's top
   role always leads while missing; counter logic when the slot has no fixed target). Score =
   role match 1000 (or off-role rank×40) + tier×100 + eligible 500 / ineligible −5000 + callout 150
   ± matchups (counters +150 each, countered −250 each) − stacking (350 / 3000) ± your results (≤700)
   or observed record (≤200).
4. **Perspective** — the same function advises you, a teammate, or predicts an enemy; eligibility and
   personal stats apply only to *you*.
5. **Learning** — `DraftLearning` tallies every archived battle and logged series with a 60-day half-life;
   personal (you), observed (anyone), threats (enemies you lose to), baselines (mode/map). Smoothed
   `(wins+2)/(games+4)`, used after 3 games.
6. **Win chance** — per-pick tier/role/personal, coverage bonuses, sigmoid k=1.2, blended with your baseline,
   shrunk toward 50% until 50 logged matches, clamped 25–75%.
7. **Checklist / tips / review** — `DraftChecklist`, `MatchTips.plan`, `MatchAnalyzer`; all pure functions.

Everything above has a unit test; run `swift test` after touching any of it. The Draft Model screen's
"How it works" page is generated from the live weights, so it stays correct when you tune.

---

## 8. Gotchas that cost time before

- **Plain buttons need `.contentShape(Rectangle())`** on macOS when the label is an image/clipped view,
  or they stop being clickable.
- **Don't compute the learning model in a view property.** It must stay an `@State` cached value
  (rebuilt on `archive/matchLog` count change). Making it computed once rebuilt it per tile per render and
  froze the draft board.
- **Board taller than the window** must be inside a `ScrollView`; a bare `VStack` overflows off the top.
- **`DraftWeights`/`PlaybookConfig`/`DraftConfig` use custom `init(from:)`** so missing keys fall back to
  defaults. When you add a weight, add it to the decoder too, and bump `DraftConfig.version` + add a
  migration in `DraftConfigStore.migrate` if you change a default you want existing installs to receive.
- **Date encoding is inconsistent:** `JSONStore` writes ISO-8601; `MatchLogStore`, `BattleArchiveStore`,
  `SeasonStore`, `TierListStore`, `MapDataStore` use their own `JSONEncoder` (dates as seconds-since-2001
  floats). Both read back fine; just don't assume one format when scripting against the files.
- **Ranked doesn't award trophies** — Elo is the metric for ranked play; trophies stay flat.
- **The Reset button backs up first** (`tierlists.backup.json`) and asks for confirmation. Keep it that way.
- Brawlify/noff block scraping (403); BrawlAPI has no skins endpoint — the Wardrobe is observed+manual by design.
- Two match counts differ on purpose: Ranked tab = logged series; Battles tab = every archived game.

---

## 9. Common changes, step by step

**Add a sidebar tab:** add a case to `SidebarTab` (name + SF symbol) in `BrawlTrackerApp.swift`, add the
`case` in `RootView.detail`, create the view. The ⌘-number shortcut follows automatically.

**Add a persisted store:** copy `SkinStore` as a template (`@MainActor @Observable`, `JSONStore.load/save`),
create it in `BrawlTrackerApp`, add `.environment(...)`, and re-inject it in any sheet that needs it.

**Add a draft weight:** field + default in `DraftWeights`, a line in its `init(from:)`, use it in
`DraftEngine`/`WinProbability`, a `WeightRow` in `DraftModelView`, a sentence in the overview, a test.

**Change the playbook roster/rules:** either in-app (Draft Model ▸ Playbook rules / Brawler classes, persisted
as overrides) or the defaults in `DraftPlaybook.roster` / `PlaybookConfig.defaults`.

**Update brawler art / icons:** see §4. Rebuild with `make_app.sh` — icons are bundled, not fetched.

**Ship a change:** `swift build` → `swift test` → `./make_app.sh` → `open -a /Applications/BrawlTracker.app`.

---

## 10. Debugging

- Build errors: `swift build 2>&1 | grep error:`
- Data problems: the JSON files are readable; `python3 -c "import json; print(json.load(open('…')))"`.
- API problems: a 403 with "IP" in the body means the key isn't whitelisted for your current IP — the app
  shows the detected IP in the banner; fix it on the developer portal or enter portal credentials in Settings
  for auto-renewal. A 404 means a wrong tag.
- The sample data banner means the app is not connected (no token/tag) or the last fetch failed.
- If the window shows nothing after a change to the draft board, check for an overflowing layout or a
  computed property doing heavy work per render (see §8).
