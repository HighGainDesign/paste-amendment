#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
case "$MODE" in run|--build-only|--verify) ;; *) echo "Usage: $0 [--build-only|--verify]" >&2; exit 2 ;; esac
SIGNING_IDENTITY="${PASTE_AMENDMENT_SIGNING_IDENTITY:?Set PASTE_AMENDMENT_SIGNING_IDENTITY to your Developer ID Application identity}"
TEAM_ID="${PASTE_AMENDMENT_TEAM_ID:?Set PASTE_AMENDMENT_TEAM_ID to your Apple developer team ID}"
NOTARY_PROFILE="${PASTE_AMENDMENT_NOTARY_PROFILE:-}"
NOTARY_KEYCHAIN="${PASTE_AMENDMENT_NOTARY_KEYCHAIN:-}"
NOTARY_TIMEOUT="${PASTE_AMENDMENT_NOTARY_TIMEOUT:-15m}"
VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$ROOT_DIR/extension/manifest.json")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Use a numeric X.Y.Z manifest version.' >&2; exit 2; }
NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
if [[ -n "$NOTARY_KEYCHAIN" ]]; then NOTARY_ARGS+=(--keychain "$NOTARY_KEYCHAIN"); fi
mkdir -p "$ROOT_DIR/output"
BUILD_DIR="$(mktemp -d /private/tmp/paste-amendment-build.XXXXXX)"
APP="$BUILD_DIR/Build/Products/Release/Paste Amendment.app"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister
cleanup() {
  if [[ -d "$APP" ]]; then
    pluginkit -r "$APP/Contents/PlugIns/Paste Amendment Extension.appex" >/dev/null 2>&1 || true
    "$LSREGISTER" -u "$APP" >/dev/null 2>&1 || true
  fi
  if [[ -d "$BUILD_DIR/dmg/Paste Amendment.app" ]]; then
    pluginkit -r "$BUILD_DIR/dmg/Paste Amendment.app/Contents/PlugIns/Paste Amendment Extension.appex" >/dev/null 2>&1 || true
    "$LSREGISTER" -u "$BUILD_DIR/dmg/Paste Amendment.app" >/dev/null 2>&1 || true
  fi
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT
if [[ "$MODE" != --build-only ]]; then pkill -x 'Paste Amendment' >/dev/null 2>&1 || true; fi
if ! xcodebuild -project "$ROOT_DIR/macos/Paste Amendment/Paste Amendment.xcodeproj" \
  -scheme 'Paste Amendment' -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$TEAM_ID" \
  OTHER_CODE_SIGN_FLAGS=--timestamp CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  CODE_SIGN_ENTITLEMENTS="$ROOT_DIR/Signing.entitlements" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="${PASTE_AMENDMENT_BUILD_NUMBER:-2}" \
  MACOSX_DEPLOYMENT_TARGET=13.0 build > "$ROOT_DIR/output/build.log" 2>&1; then
  tail -60 "$ROOT_DIR/output/build.log" >&2
  exit 1
fi
codesign --verify --deep --strict "$APP"
if [[ -n "$NOTARY_PROFILE" ]]; then
  ditto -c -k --keepParent --norsrc --noextattr "$APP" "$BUILD_DIR/Paste Amendment-notary.zip"
  xcrun notarytool submit "$BUILD_DIR/Paste Amendment-notary.zip" \
    "${NOTARY_ARGS[@]}" --wait --timeout "$NOTARY_TIMEOUT" \
    > "$ROOT_DIR/output/notarization.log" 2>&1
  cat "$ROOT_DIR/output/notarization.log"
  if ! /usr/bin/grep -q 'status: Accepted' "$ROOT_DIR/output/notarization.log"; then
    echo 'Notarization was not accepted; app will not be installed.' >&2
    exit 1
  fi
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl --assess --type execute --verbose=2 "$APP"
fi
ditto -c -k --keepParent --norsrc --noextattr "$APP" "$ROOT_DIR/output/Paste Amendment.zip"
mkdir -p "$BUILD_DIR/dmg"
ditto --norsrc --noextattr "$APP" "$BUILD_DIR/dmg/Paste Amendment.app"
ln -s /Applications "$BUILD_DIR/dmg/Applications"
cp "$ROOT_DIR/LICENSE" "$BUILD_DIR/dmg/LICENSE.txt"
DMG="$BUILD_DIR/Paste Amendment.dmg"
hdiutil create -volname 'Paste Amendment' -srcfolder "$BUILD_DIR/dmg" -fs HFS+ -format UDZO "$DMG"
codesign --sign "$SIGNING_IDENTITY" --timestamp "$DMG"
codesign --verify --strict "$DMG"
if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --wait --timeout "$NOTARY_TIMEOUT" \
    > "$ROOT_DIR/output/dmg-notarization.log" 2>&1
  cat "$ROOT_DIR/output/dmg-notarization.log"
  if ! /usr/bin/grep -q 'status: Accepted' "$ROOT_DIR/output/dmg-notarization.log"; then
    echo 'DMG notarization was not accepted; it will not be distributed.' >&2
    exit 1
  fi
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
fi
ditto --norsrc --noextattr "$DMG" "$ROOT_DIR/output/Paste Amendment.dmg"
echo "Built and verified: $APP"
echo "Packaged: $ROOT_DIR/output/Paste Amendment.dmg"
if [[ "$MODE" != --build-only ]]; then
  INSTALLED_APP="/Applications/Paste Amendment.app"
  ditto --norsrc --noextattr "$APP" "$INSTALLED_APP"
  codesign --verify --deep --strict "$INSTALLED_APP"
  "$LSREGISTER" -f "$INSTALLED_APP"
  /usr/bin/open "$INSTALLED_APP"
  if [[ "$MODE" == --verify ]]; then sleep 1; pgrep -x 'Paste Amendment' >/dev/null; fi
fi
