# Contributing to Paste Amendment

Issues and pull requests are welcome. Keep changes focused on restoring native paste while preserving normal browser editing.

## Report a problem

Include your macOS and Safari versions, the type of editable field, and whether the extension has website access. Prefer a small HTML reproduction over a link to a private account. Never include passwords, tokens, clipboard contents, or private screenshots.

## Work locally

The extension lives in `extension/`. The native macOS wrapper lives in `macos/`. The build entrypoint is `script/build_and_run.sh`; see the README for signing and notarization environment variables. Contributors use their own Developer ID identity and local Keychain profile. Do not commit signing keys, certificates, credentials, provisioning profiles, `.env` files, build artifacts, or local agent documents. No GitHub repository secrets are needed for local builds.

If you only change the content script, use the blocking-page fixtures and browser checks before attempting native packaging. `tests/paste.cjs` requires Node, the Playwright library, and installed Chrome; run `node tests/paste.cjs` with Playwright resolvable in your environment. Safari smoke testing is also needed for changes to extension loading or permissions.

## Preserve these behaviors

- Native insertion, selection replacement, and undo keep working.
- Ordinary typing and input notifications remain available to the page.
- Readonly and disabled fields remain unchanged.
- No clipboard reading or storage, analytics, or remote service calls.
- Limit interception to paste-related events on editable targets.

Add a focused regression check for a behavioral change. Describe the problem, the change, and validation in the pull request. Do not add broad browser permissions without explaining the need.

## Releases

Release maintainers build with Developer ID signing, notarize and staple both the app and DMG, and verify Gatekeeper acceptance before uploading the DMG and its SHA-256 checksum to GitHub Releases. Keep credentials in your local Keychain, referenced by profile name through the environment.

Contributions are covered by the repository's MIT license.
