#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORM="${1:?Usage: build_app_store.sh ios|macos}"
TEAM_ID="${PASTE_AMENDMENT_TEAM_ID:?Set your Apple developer team ID}"
BUILD_NUMBER="${PASTE_AMENDMENT_BUILD_NUMBER:?Set a new TestFlight build number}"
VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$ROOT_DIR/extension/manifest.json")"
case "$PLATFORM" in
  ios) PROJECT="$ROOT_DIR/ios/Paste Amendment/Paste Amendment.xcodeproj"; CONFIGURATION=Release; DESTINATION='generic/platform=iOS'; PROFILE_SUFFIX='iOS'; OUTPUT_EXTENSION=ipa ;;
  macos) PROJECT="$ROOT_DIR/macos/Paste Amendment/Paste Amendment.xcodeproj"; CONFIGURATION=AppStore; DESTINATION='generic/platform=macOS'; PROFILE_SUFFIX='Mac'; OUTPUT_EXTENSION=pkg ;;
  *) echo 'Choose ios or macos.' >&2; exit 2 ;;
esac
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo 'Build number must be numeric.' >&2; exit 2; }
BUILD_DIR="$(mktemp -d /private/tmp/paste-amendment-store.XXXXXX)"
OUTPUT_DIR="$ROOT_DIR/output/appstore/$PLATFORM"
mkdir -p "$OUTPUT_DIR"
PLATFORM_ARGS=(IPHONEOS_DEPLOYMENT_TARGET=15.0)
if [[ "$PLATFORM" == macos ]]; then PLATFORM_ARGS=(MACOSX_DEPLOYMENT_TARGET=13.0); fi
cleanup() {
  if [[ "$PLATFORM" == macos ]]; then
    for app in "$BUILD_DIR/archive.xcarchive/Products/Applications/Paste Amendment.app" "$BUILD_DIR/derived/Build/Intermediates.noindex/ArchiveIntermediates/Paste Amendment/InstallationBuildProductsLocation/Applications/Paste Amendment.app"; do
      if [[ -d "$app" ]]; then
        pluginkit -r "$app/Contents/PlugIns/Paste Amendment Extension.appex" >/dev/null 2>&1 || true
        /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -u "$app" >/dev/null 2>&1 || true
      fi
    done
  fi
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT
python3 - "$BUILD_DIR/ExportOptions.plist" "$TEAM_ID" "$PROFILE_SUFFIX" "$PLATFORM" <<'PY'
import os,plistlib,sys
options = {
    'method': 'app-store-connect', 'destination': 'export', 'signingStyle': 'manual',
    'teamID': sys.argv[2], 'signingCertificate': 'Apple Distribution',
    'manageAppVersionAndBuildNumber': False,
    'provisioningProfiles': {
        'design.highgain.pasteamendment': f'Paste Amendment {sys.argv[3]} App Store',
        'design.highgain.pasteamendment.Extension': f'Paste Amendment Extension {sys.argv[3]} App Store',
    },
}
if sys.argv[4] == 'macos':
    options['installerSigningCertificate'] = os.environ['PASTE_AMENDMENT_INSTALLER_SIGNING_IDENTITY']
with open(sys.argv[1], 'wb') as f: plistlib.dump(options, f)
PY
if ! xcodebuild -project "$PROJECT" -scheme 'Paste Amendment' -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" -derivedDataPath "$BUILD_DIR/derived" -archivePath "$BUILD_DIR/archive.xcarchive" \
  DEVELOPMENT_TEAM="$TEAM_ID" MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  "${PLATFORM_ARGS[@]}" archive > "$OUTPUT_DIR/build.log" 2>&1; then
  tail -60 "$OUTPUT_DIR/build.log" >&2; exit 1
fi
if ! xcodebuild -exportArchive -archivePath "$BUILD_DIR/archive.xcarchive" -exportPath "$BUILD_DIR/export" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" > "$OUTPUT_DIR/export.log" 2>&1; then
  tail -40 "$OUTPUT_DIR/export.log" >&2; exit 1
fi
cp "$BUILD_DIR/export/Paste Amendment.$OUTPUT_EXTENSION" "$OUTPUT_DIR/Paste Amendment.$OUTPUT_EXTENSION"
echo "Prepared $PLATFORM TestFlight build $VERSION ($BUILD_NUMBER): $OUTPUT_DIR/Paste Amendment.$OUTPUT_EXTENSION"
