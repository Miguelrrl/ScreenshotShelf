# ScreenshotShelf

A lightweight macOS menu bar app that replaces the temporary native screenshot
thumbnail with a persistent shelf.

## Features

- Persistent screenshot thumbnail on the display under the cursor
- Native drag and drop into other applications
- Copy, save, and discard actions
- Hover controls
- Multi-display and multi-Space safety
- Automatic updates powered by Sparkle
- Universal Apple Silicon and Intel build

## Requirements

- macOS 13 or later
- Xcode with the macOS SDK

## Build

```bash
./scripts/build-release.sh
```

The app bundle is written to `dist/ScreenshotShelf.app`.

To create the DMG:

```bash
./scripts/create-dmg.sh
```

## Publishing a release

Update `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`, commit
the changes, then push a matching tag:

```bash
git tag v0.2.0
git push origin main v0.2.0
```

GitHub Actions builds the universal app, creates the DMG, signs the Sparkle
update with EdDSA, publishes a GitHub Release, and updates the appcast served by
GitHub Pages.

## Distribution

The app currently uses ad hoc Apple code signing. macOS may require users to
approve the first launch in **System Settings → Privacy & Security**.

Sparkle update archives are independently authenticated with an EdDSA key.
