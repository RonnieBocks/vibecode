#!/bin/bash
# Builds BrawlTracker and packages it into a proper double-clickable .app
# bundle installed to /Applications. Re-run this after any code change.
set -euo pipefail

CONFIG="release"
APP_NAME="BrawlTracker"
BUNDLE_ID="com.ronnie.brawltracker"
INSTALL_DIR="/Applications"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$PROJECT_DIR"

# macOS ships bash 3.2, where expanding an empty array under `set -u` is an
# error — hence the ${a[@]+"${a[@]}"} guard on every expansion below.
ARCH_FLAGS=()
if [ "${UNIVERSAL:-0}" = "1" ]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
  echo "Building ($CONFIG, universal arm64 + x86_64) — this takes a few minutes..."
else
  echo "Building ($CONFIG)..."
fi
swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}

BIN_DIR="$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"
APP="$INSTALL_DIR/$APP_NAME.app"

echo "Assembling $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Executable
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

# SPM resource bundle (holds sample_player.json + BrawlerIcons) — placed in
# Contents/Resources so Bundle.module resolves it via Bundle.main.resourceURL.
if [ -d "$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle" ]; then
  cp -R "$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle" "$APP/Contents/Resources/"
fi

# App icon
ICON="$PROJECT_DIR/Sources/BrawlTracker/Resources/Icon/AppIcon.icns"
[ -f "$ICON" ] && cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

# Info.plist
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>Brawl Tracker</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleIconFile</key><string>AppIcon</string>
</dict>
</plist>
PLIST

echo "PkgInfo"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc codesign so Gatekeeper lets it launch locally.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "(codesign skipped)"

echo "Done: $APP"
