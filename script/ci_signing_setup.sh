#!/bin/bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true ]] || { echo 'Run only on an ephemeral GitHub Actions runner.' >&2; exit 2; }
for name in CERTIFICATE_BASE64 CERTIFICATE_PASSWORD NOTARY_KEY_BASE64 NOTARY_KEY_ID NOTARY_ISSUER_ID PASTE_AMENDMENT_TEAM_ID; do
  [[ -n "${!name:-}" ]] || { echo "Missing signing configuration: $name" >&2; exit 2; }
done
umask 077
certificate="$RUNNER_TEMP/paste-amendment.p12"
api_key="$RUNNER_TEMP/paste-amendment-notary.p8"
keychain="$RUNNER_TEMP/paste-amendment-signing.keychain-db"
printf '%s' "$CERTIFICATE_BASE64" | base64 --decode > "$certificate"
printf '%s' "$NOTARY_KEY_BASE64" | base64 --decode > "$api_key"
keychain_password="$(openssl rand -hex 32)"
echo "::add-mask::$keychain_password"
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 7200 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$certificate" -P "$CERTIFICATE_PASSWORD" -t cert -f pkcs12 -k "$keychain" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" "$HOME/Library/Keychains/login.keychain-db"
identity="$(security find-identity -v -p codesigning "$keychain" | awk '/Developer ID Application/ { print $2; exit }')"
[[ -n "$identity" ]] || { echo 'Developer ID identity with private key is required.' >&2; exit 1; }
xcrun notarytool store-credentials PasteAmendment-CI --keychain "$keychain" \
  --key "$api_key" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" >/dev/null
rm -f "$certificate" "$api_key"
printf 'PASTE_AMENDMENT_SIGNING_IDENTITY=%s\nPASTE_AMENDMENT_NOTARY_KEYCHAIN=%s\n' "$identity" "$keychain" >> "$GITHUB_ENV"
