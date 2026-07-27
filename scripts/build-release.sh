#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/ScreenshotShelf.app"
ARM_BUILD="$ROOT/.build-arm64"
X86_BUILD="$ROOT/.build-x86"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

swift build \
  --package-path "$ROOT" \
  -c release \
  --triple arm64-apple-macosx13.0 \
  --build-path "$ARM_BUILD"

swift build \
  --package-path "$ROOT" \
  -c release \
  --triple x86_64-apple-macosx13.0 \
  --build-path "$X86_BUILD"

ARM_BIN="$ARM_BUILD/arm64-apple-macosx/release/ScreenshotShelf"
X86_BIN="$X86_BUILD/x86_64-apple-macosx/release/ScreenshotShelf"

install_name_tool -add_rpath "@executable_path/../Frameworks" "$ARM_BIN" 2>/dev/null || true
install_name_tool -add_rpath "@executable_path/../Frameworks" "$X86_BIN" 2>/dev/null || true

lipo -create "$ARM_BIN" "$X86_BIN" -output "$APP/Contents/MacOS/ScreenshotShelf"
chmod 755 "$APP/Contents/MacOS/ScreenshotShelf"

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
ditto \
  "$ARM_BUILD/arm64-apple-macosx/release/Sparkle.framework" \
  "$APP/Contents/Frameworks/Sparkle.framework"

codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "$APP"
