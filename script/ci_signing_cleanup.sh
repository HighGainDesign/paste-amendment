#!/bin/bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true ]] || exit 2
security delete-keychain "$RUNNER_TEMP/paste-amendment-signing.keychain-db" >/dev/null 2>&1 || true
rm -f "$RUNNER_TEMP/paste-amendment.p12" "$RUNNER_TEMP/paste-amendment-notary.p8"
