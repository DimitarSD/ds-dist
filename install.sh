#!/bin/bash
# One-line installer (mirrors cmux's kit): downloads the latest build, copies it
# to /Applications, and clears the Gatekeeper quarantine flag so the ad-hoc
# signed app opens without the "damaged" warning. After this first install,
# in-app auto-updates apply in place and never re-quarantine.
#
# Friends run:
#   curl -fsSL https://raw.githubusercontent.com/DimitarSD/ds-dist/main/install.sh | bash
set -euo pipefail

REPO="DimitarSD/ds-dist"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ Finding the latest release…"
DMG_URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*\.dmg"' \
  | head -1 | sed -E 's/.*"(https[^"]*)".*/\1/')"
[ -n "$DMG_URL" ] || { echo "✗ No .dmg asset found in the latest release."; exit 1; }

echo "→ Downloading…"
curl -fsSL "$DMG_URL" -o "$TMP/app.dmg"

echo "→ Mounting…"
MOUNT="$(hdiutil attach "$TMP/app.dmg" -nobrowse -readonly | grep -oE '/Volumes/[^"]*' | tail -1)"
APP_SRC="$(find "$MOUNT" -maxdepth 1 -name '*.app' | head -1)"
[ -n "$APP_SRC" ] || { hdiutil detach "$MOUNT" >/dev/null 2>&1 || true; echo "✗ No .app inside the DMG."; exit 1; }

APP_NAME="$(basename "$APP_SRC")"
DEST="/Applications/$APP_NAME"

echo "→ Installing $APP_NAME → /Applications…"
[ -d "$DEST" ] && rm -rf "$DEST"
cp -R "$APP_SRC" /Applications/
hdiutil detach "$MOUNT" >/dev/null 2>&1 || true

# Ad-hoc signed build → clear quarantine so Gatekeeper lets it open.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "✓ Installed (quarantine cleared). Launching…"
open "$DEST"
