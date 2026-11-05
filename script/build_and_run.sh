#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
APP_NAME="MacSense"
BUNDLE_ID="io.github.behruzinho.MacSense"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
APP_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
BUILD_CONFIGURATION="${CONFIGURATION:-debug}"
BUILD_ARGS=(-c "$BUILD_CONFIGURATION")
if [ -n "${MACSENSE_ARCH:-}" ]; then BUILD_ARGS+=(--arch "$MACSENSE_ARCH"); fi
if [[ ! "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "Invalid VERSION" >&2; exit 2; fi
if [[ "$BUILD_CONFIGURATION" != "debug" && "$BUILD_CONFIGURATION" != "release" ]]; then echo "Invalid CONFIGURATION" >&2; exit 2; fi

case "$MODE" in run|--build|--verify|--debug|--logs|--telemetry) ;; *) echo "Usage: $0 [--build|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;; esac
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
cd "$ROOT_DIR"
swift build "${BUILD_ARGS[@]}" --cache-path "$ROOT_DIR/.build/cache"
BUILD_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
for RESOURCE_BUNDLE in "$BUILD_DIR"/*.bundle; do
    if [ -d "$RESOURCE_BUNDLE" ]; then /usr/bin/ditto "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/$(basename "$RESOURCE_BUNDLE")"; fi
done
if [ -f "$ROOT_DIR/Resources/AppIcon.icns" ]; then cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"; fi
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>$APP_NAME</string>
<key>CFBundleDisplayName</key><string>$APP_NAME</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
python3 - "$APP_BUNDLE/Contents/Info.plist" "${MACSENSE_SUPPORT_URL:-}" <<'SUPPORT'
import sys, plistlib, urllib.parse
path, support = sys.argv[1:]
with open(path, 'rb') as f: info = plistlib.load(f)
info['CFBundleLocalizations'] = ['ru', 'en', 'zh-Hans', 'es', 'de']
if support:
    parsed = urllib.parse.urlparse(support)
    if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password:
        raise SystemExit('MACSENSE_SUPPORT_URL must be a valid HTTPS page URL')
    info['MacSenseSupportURL'] = support
with open(path, 'wb') as f: plistlib.dump(info, f)
SUPPORT
if [ -n "${MACSENSE_SIGN_IDENTITY:-}" ]; then
    codesign --force --options runtime --timestamp --sign "$MACSENSE_SIGN_IDENTITY" "$APP_BUNDLE"
else
    codesign --force --sign - "$APP_BUNDLE" >/dev/null 2>&1
fi
case "$MODE" in
  --build) echo "$APP_BUNDLE" ;;
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"" ;;
  --telemetry) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\"" ;;
  --verify) open -n "$APP_BUNDLE"; sleep 2; pgrep -x "$APP_NAME" >/dev/null; echo "MacSense is running" ;;
  run) open -n "$APP_BUNDLE" ;;
esac
