#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/ScreenshotShelf.app"
STAGE="$DIST/dmg"
DMG="$DIST/ScreenshotShelf.dmg"

if [[ ! -d "$APP" ]]; then
  "$ROOT/scripts/build-release.sh"
fi

mkdir -p "$STAGE/.background"
ditto "$APP" "$STAGE/ScreenshotShelf.app"
cp "$ROOT/Resources/dmg/dmg-background.png" "$STAGE/.background/dmg-background.png"
cp "$ROOT/Resources/dmg/DS_Store" "$STAGE/.DS_Store"
ln -sfn /Applications "$STAGE/Applications"

hdiutil create \
  -volname ScreenshotShelf \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

hdiutil verify "$DMG"
echo "$DMG"
