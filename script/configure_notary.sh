#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-MacSense-Notary}"
TEAM_ID="$(codesign -dv --verbose=4 "$ROOT_DIR/dist/MacSense.app" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2}')"
if [ -z "$TEAM_ID" ] || [ "$TEAM_ID" = "not set" ]; then
    echo "Build with a Developer ID Application identity first." >&2
    exit 1
fi
echo "Configure Apple notarization profile: $PROFILE"
echo "Enter your Apple ID and an app-specific password in this terminal."
echo "Create the app-specific password at https://account.apple.com if needed."
echo "Do not paste passwords into chat. The credentials will be stored in Keychain."
xcrun notarytool store-credentials "$PROFILE" --team-id "$TEAM_ID"
echo "Profile configured. Next: ./script/notarize_release.sh '$PROFILE'"
