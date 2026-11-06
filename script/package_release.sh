#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
ARCH="${MACSENSE_ARCH:-$(uname -m)}"
RELEASE_DIR="$ROOT_DIR/dist/releases"
APP_BUNDLE="$ROOT_DIR/dist/MacSense.app"
BASE_NAME="MacSense-$APP_VERSION-$ARCH"

if [ "${1:-}" != "--from-app" ]; then
    CONFIGURATION=release "$ROOT_DIR/script/build_and_run.sh" --build
fi
codesign --verify --deep --strict "$APP_BUNDLE"
mkdir -p "$RELEASE_DIR"
STAGING_DIR="$(mktemp -d "$ROOT_DIR/.build/package.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
/usr/bin/ditto "$APP_BUNDLE" "$STAGING_DIR/MacSense.app"
mkdir -p "$STAGING_DIR/Documentation"
cp "$ROOT_DIR/LICENSE" "$STAGING_DIR/Documentation/LICENSE.txt"
cat > "$STAGING_DIR/Documentation/Read me.txt" <<'INSTALL'
MacSense

Drag MacSense.app into Applications, then open it from Applications.
Requirements: macOS 14 or newer. Check the download's architecture label.

The release page states the signing and notarization status of this build.
Keep Gatekeeper enabled. Apple explains how to review an app you trust:
https://support.apple.com/102445

Author: https://github.com/behruzinho
Project: https://github.com/behruzinho/MacSense
License: MIT
INSTALL
# Release-only tooling lives in an isolated virtual environment, never in the app.
DMG_PYTHON="$ROOT_DIR/.build/dmg-tools/bin/python"
if [ ! -x "$DMG_PYTHON" ]; then python3 -m venv "$ROOT_DIR/.build/dmg-tools"; fi
if ! "$DMG_PYTHON" -c 'import importlib.metadata; assert all(importlib.metadata.version(k) == v for k, v in {"dmgbuild": "1.6.5", "ds-store": "1.3.1", "mac-alias": "2.2.2"}.items())' >/dev/null 2>&1; then
    "$DMG_PYTHON" -m pip install -r "$ROOT_DIR/script/dmg-requirements.txt"
fi
swift "$ROOT_DIR/script/generate_dmg_background.swift" "$STAGING_DIR/background.tiff" "$APP_VERSION" "$ARCH"
"$DMG_PYTHON" -m dmgbuild -s "$ROOT_DIR/script/dmg_settings.py" \
    -D "app=$STAGING_DIR/MacSense.app" \
    -D "documentation=$STAGING_DIR/Documentation" \
    -D "background=$STAGING_DIR/background.tiff" \
    -D "volume_name=MacSense $APP_VERSION" \
    "MacSense $APP_VERSION" "$STAGING_DIR/$BASE_NAME.dmg"
if [ -n "${MACSENSE_SIGN_IDENTITY:-}" ]; then
    codesign --force --timestamp --sign "$MACSENSE_SIGN_IDENTITY" "$STAGING_DIR/$BASE_NAME.dmg"
fi
mv -f "$STAGING_DIR/$BASE_NAME.dmg" "$RELEASE_DIR/$BASE_NAME.dmg"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$RELEASE_DIR/$BASE_NAME.zip"
(
    cd "$RELEASE_DIR"
    shasum -a 256 "$BASE_NAME.dmg" "$BASE_NAME.zip" > "$BASE_NAME-SHA256SUMS.txt"
)
echo "Release assets: $RELEASE_DIR"
