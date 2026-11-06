#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-${MACSENSE_NOTARY_PROFILE:-MacSense-Notary}}"
APP_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
APP_BUNDLE="$ROOT_DIR/dist/MacSense.app"
ARCH="$(lipo -archs "$APP_BUNDLE/Contents/MacOS/MacSense")"
BASE_NAME="MacSense-$APP_VERSION-$ARCH"
RELEASE_DIR="$ROOT_DIR/dist/releases"
WORK_DIR="$ROOT_DIR/.build/notarization"
mkdir -p "$WORK_DIR"
codesign --verify --deep --strict "$APP_BUNDLE"
if ! codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1 | /usr/bin/grep '^Authority=Developer ID Application:' > /dev/null; then
    echo "A Developer ID Application signature is required." >&2
    exit 1
fi
submit() {
    local archive="$1" result_file="$2"
    xcrun notarytool submit "$archive" --keychain-profile "$PROFILE" --wait --output-format json > "$result_file"
    python3 - "$result_file" <<'CHECK'
import json,sys
with open(sys.argv[1]) as f: result=json.load(f)
print('Apple notarization:',result.get('status'),'submission:',result.get('id'))
if result.get('status') != 'Accepted': raise SystemExit('Notarization was not accepted; retrieve the submission log before publishing.')
CHECK
}
echo "Submitting the signed app to Apple…"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$WORK_DIR/app.zip"
submit "$WORK_DIR/app.zip" "$WORK_DIR/app-result.json"
xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"
echo "Repackaging the stapled app…"
"$ROOT_DIR/script/package_release.sh" --from-app
echo "Submitting the DMG to Apple…"
submit "$RELEASE_DIR/$BASE_NAME.dmg" "$WORK_DIR/dmg-result.json"
xcrun stapler staple "$RELEASE_DIR/$BASE_NAME.dmg"
xcrun stapler validate "$RELEASE_DIR/$BASE_NAME.dmg"
spctl --assess --type execute --verbose=2 "$APP_BUNDLE"
(
    cd "$RELEASE_DIR"
    shasum -a 256 "$BASE_NAME.dmg" "$BASE_NAME.zip" > "$BASE_NAME-SHA256SUMS.txt"
)
echo "Notarized and stapled release assets: $RELEASE_DIR"
