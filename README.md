# Paste Amendment for Safari on Mac

A small Safari extension that restores native pasting in writable text fields, password fields, textareas, and contenteditable areas. No clipboard reading, saved text, network calls, or external dependencies in the extension. Requires macOS 13 or newer.

![Paste Amendment icon](assets/icon-preview.png)

## Use the built app

1. Download **Paste Amendment.dmg** from [GitHub Releases](https://github.com/HighGainDesign/paste-amendment/releases/latest), open it, and drag **Paste Amendment.app** to the Applications shortcut. Open the app once, then eject the disk image.
2. In **Safari → Settings → Extensions**, enable **Paste Amendment** and allow access to the websites where you want it. Safari controls website access; there is no extra toolbar button.
3. Refresh the webpage and paste normally with **⌘V** or **Edit → Paste**.

The app and DMG use Developer ID signing and Apple notarization. They do not require enabling unsigned extensions.

Apple's setup reference: [Running your Safari web extension](https://developer.apple.com/documentation/safariservices/running-your-safari-web-extension).

## Scope

Captures paste, paste-specific beforeinput events, and paste keyboard shortcuts before page handlers can cancel them. Leaves browser insertion, selection replacement, undo, and input/change events intact. Works on permitted HTTP(S) pages and matching frames, including dynamically added fields and open shadow DOM. Refresh after granting access.

Readonly/disabled controls stay readonly/disabled. Safari's protected pages, non-HTTP(S) frames (including about:blank/srcdoc), closed shadow roots, and sites that revert text in input handlers are not covered. Rich editors that need custom paste processing may behave differently; deny website access for that site if needed. It does not enable copy or cut.

## Build again

Requires Xcode and a Developer ID Application signing identity. Set `PASTE_AMENDMENT_SIGNING_IDENTITY` and `PASTE_AMENDMENT_TEAM_ID` in your local shell to your own identity and developer team. Run `./script/build_and_run.sh` to build, install in `/Applications`, and open the app, or add `--build-only` to package it without installation. To notarize and staple the release, set `PASTE_AMENDMENT_NOTARY_PROFILE` to your existing notarytool Keychain profile. No secrets are stored in this project or required as GitHub repository secrets.

Build log is `output/build.log`, and notarization results are in `output/notarization.log` and `output/dmg-notarization.log`. Builds use a temporary directory outside Dropbox to prevent File Provider metadata from breaking code signing. The script unregisters and deletes temporary app bundles on exit; it opens only the installed app. The release deliverable is `output/Paste Amendment.dmg`; a ZIP is retained locally as an intermediate packaging artifact. Source of truth is `extension/`; the Xcode project references these files directly.

## Distribution

Mac App Store distribution is optional for the macOS extension. A Developer ID–signed, notarized and stapled app can be shipped in this DMG through GitHub Releases or your own website. The containing app must be installed and opened once, then the user enables the extension and grants website access. Source can also be shared for others to build with their own identity.

See Apple's [Safari extension distribution guide](https://developer.apple.com/documentation/safariservices/distributing-your-safari-web-extension).

## Verification

`tests/paste.cjs` uses Node and the Playwright library with installed Chrome in an isolated headless profile. Run `node tests/paste.cjs` with Playwright resolvable, for example by setting `NODE_PATH` to your installed package directory. No packages need to be installed to use the app.

Checks trusted native paste against inline, window capture, beforeinput, and shortcut blockers; passwords, dynamic fields, contenteditable, open shadow DOM, frames, selection replacement, undo, ordinary typing/input events, and noneditable controls. These are Chromium browser tests of the script; Safari's installed extension still requires a manual smoke test after enabling.

For a manual smoke test, serve this directory locally (`python3 -m http.server 8767 --bind 127.0.0.1`), open `http://localhost:8767/tests/blocked-paste.html` in Safari, grant Paste Amendment access to localhost, refresh, and follow the page's copy/paste instructions. Stop the server with Ctrl-C.

## Contributing and license

See [CONTRIBUTING.mod](CONTRIBUTING.mod). Paste Amendment is available under the [MIT license](LICENSE).
