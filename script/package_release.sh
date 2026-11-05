#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
ARCH="${MACSENSE_ARCH:-$(uname -m)}"
RELEASE_DIR="$ROOT_DIR/dist/releases"
APP_BUNDLE="$ROOT_DIR/dist/MacSense.app"
BASE_NAME="MacSense-$APP_VERSION-$ARCH"

CONFIGURATION=release "$ROOT_DIR/script/build_and_run.sh" --build
codesign --verify --deep --strict "$APP_BUNDLE"
mkdir -p "$RELEASE_DIR"
STAGING_DIR="$(mktemp -d "$ROOT_DIR/.build/package.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
/usr/bin/ditto "$APP_BUNDLE" "$STAGING_DIR/MacSense.app"
ln -s /Applications "$STAGING_DIR/Applications"
cp "$ROOT_DIR/LICENSE" "$STAGING_DIR/LICENSE.txt"
cat > "$STAGING_DIR/Read me.txt" <<'INSTALL'
MacSense

Drag MacSense.app into Applications, then open it from Applications.
Requirements: macOS 14 or newer. Check the download's architecture label.

This preview is ad-hoc signed and has not been notarized by Apple.
macOS may block the first launch. Keep Gatekeeper enabled; see Apple's
instructions for reviewing and opening an app you trust:
https://support.apple.com/102445

Author: https://github.com/behruzinho
Project: https://github.com/behruzinho/MacSense
License: MIT
INSTALL
hdiutil create -volname "MacSense $APP_VERSION" -srcfolder "$STAGING_DIR" -format UDZO -ov "$RELEASE_DIR/$BASE_NAME.dmg"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$RELEASE_DIR/$BASE_NAME.zip"
(
    cd "$RELEASE_DIR"
    shasum -a 256 "$BASE_NAME.dmg" "$BASE_NAME.zip" > "$BASE_NAME-SHA256SUMS.txt"
)
echo "Release assets: $RELEASE_DIR"
