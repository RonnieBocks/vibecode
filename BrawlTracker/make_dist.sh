#!/bin/bash
# Builds a universal BrawlTracker and packages it for sharing (AirDrop, etc.)
# into ./dist. Nothing personal is included: the app carries only the demo
# profile, and your token/tier lists/matches live outside the bundle.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"
DIST="$PROJECT_DIR/dist"
STAGE="$DIST/BrawlTracker"

rm -rf "$DIST"
mkdir -p "$STAGE"

# Build + assemble the .app (universal), installed to /Applications as usual.
UNIVERSAL=1 ./make_app.sh

cp -R /Applications/BrawlTracker.app "$STAGE/BrawlTracker.app"

cat > "$STAGE/READ ME FIRST.txt" <<'TXT'
BrawlTracker — Brawl Stars progression & ranked draft assistant
================================================================

Requires macOS 14 (Sonoma) or newer. Works on Apple Silicon and Intel Macs.


STEP 1 — INSTALL
----------------
Drag BrawlTracker.app into your Applications folder.


STEP 2 — LET MACOS OPEN IT
--------------------------
This app isn't signed with a paid Apple developer certificate, so macOS
blocks it the first time. That's expected. Pick either fix:

  Easiest — open Terminal (Applications > Utilities) and paste this line,
  then press Return:

      xattr -dr com.apple.quarantine /Applications/BrawlTracker.app

  Or — double-click the app, let it be blocked, then go to
  System Settings > Privacy & Security, scroll down, and click "Open Anyway".

You only have to do this once.


STEP 3 — CONNECT YOUR ACCOUNT
-----------------------------
The app opens with demo data and a Settings window. You need two things:

  1. Your player tag — find it under your profile in Brawl Stars.
     It looks like #ABC123XYZ.

  2. A free API key from Supercell:
       a. Go to developer.brawlstars.com and create an account.
       b. Click "My Account", then "Create New Key".
       c. Give it any name.
       d. For "Allowed IP Addresses", enter YOUR OWN public IP address.
          The site usually shows it, or search the web for "what is my IP".
       e. Copy the long key (it starts with "eyJ") and paste it into the app.

     IMPORTANT: keys are locked to the IP address you enter. You cannot use
     someone else's key, and if your home IP changes the key stops working.
     The app can renew it for you automatically — enter your developer portal
     email and password in Settings and it handles this whenever the IP moves.

Click "Save & Fetch" and your account loads.


STEP 4 — SET IT UP (a few minutes, worth it)
--------------------------------------------
  * Maps tab — build this season's map pool ("Autofill rotation", or add maps
    by hand). The ranked assistant only offers modes and maps in your pool.
  * Tier List tab — drag brawlers into S/A/B/C/D. The draft assistant leans on
    this to know what's currently strong.
  * Progression tab — "Start New Season" to begin tracking what you earn.
  * Ranked tab — "New Match" walks you through bans and drafting.


WHAT IT STORES, AND WHERE
-------------------------
Everything is local to your Mac. There is no server and no account with us.

  ~/Library/Application Support/BrawlTracker/   your tier lists, map pools,
                                                matches, battle archive, seasons
  macOS Keychain                                your API key and portal login

To back up, copy that folder. To remove the app completely, delete the .app,
that folder, and the "com.ronnie.brawltracker" entries in Keychain Access.


NOTES
-----
* The app fetches your data once per launch. Quit and reopen to refresh, or
  press Command-R.
* Brawl Stars only exposes your last ~25 battles, so the Battles tab builds
  history over time — the more you launch it, the more it knows.
* Coin, gem and bling balances aren't available from the API, so Progression
  asks you to log those by hand.
* Not affiliated with or endorsed by Supercell.
TXT

# Zip it so AirDrop moves a single file.
cd "$DIST"
zip -qr "BrawlTracker.zip" "BrawlTracker"
cd "$PROJECT_DIR"

echo
echo "Distribution ready:"
echo "  folder: $STAGE"
echo "  zip:    $DIST/BrawlTracker.zip  ($(du -h "$DIST/BrawlTracker.zip" | cut -f1))"
echo "  arches: $(lipo -archs "$STAGE/BrawlTracker.app/Contents/MacOS/BrawlTracker")"
