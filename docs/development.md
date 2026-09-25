# Build and development

[Documentation](README.md) · [Project overview](../README.md)

## Build and open

You need an Apple Silicon Mac, macOS 14 or later, and Apple Command Line Tools with a macOS 14 or newer SDK. Intel builds are not supported by the current scripts.

Install the tools if needed, then wait for the installation to finish:

```sh
xcode-select --install
```

Clone the repository and build the app:

```sh
git clone https://github.com/AEnguerrand/foliobruma-scanner.git
cd foliobruma-scanner
./build.sh
open "build/Foliobruma Scanner.app"
```

Allow camera access when macOS asks. The build uses Apple frameworks and needs no third-party packages or Xcode project. To use a full Xcode installation, set `DEVELOPER_DIR` to its `Contents/Developer` directory when you run the scripts.

The app is signed locally for development. It is not notarized. A rebuild can cause macOS to ask for camera access again.

## Tests and workflows

Run the regression tests without connecting a scanner:

```sh
./test.sh
```

Tests use temporary sessions and do not request camera access. They cover session persistence, failed-write recovery, page operations, crop coordinates, capture gates, warning gates, quality rejection with manual override, review capture exclusion, page replacement, original-image preservation, old session decoding, saved-document discovery, and PDF export failure recovery.

Shared document operations, storage, upload, batch, and capture rules are in
the `ScannerCore` Swift package under `Sources/ScannerCore/`. Mac interface,
camera, image processing, file locks, credentials, and device code stay under
`Sources/FoliobrumaScanner/` and `Sources/PrinterUSB/`.
The Mac scripts build and link the shared library. Run
`swift run ScannerCoreChecks` to test the shared package alone. See
[the source boundary](shared-core.md) for details. This split prepares code
reuse; a Windows app is not available yet.

GitHub Actions uses separate workflows. **Build** tests and builds branch
pushes, pull requests, and manual runs. **Release** tests, packages, and
publishes only when a version tag (`vX.Y.Z`) is pushed.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for the source layout, checks, release steps, and bug report guidance.

## Developer server

Production is the default server. To test another server, open **Settings → Advanced**. Enable **Developer mode**, enter an HTTPS
origin such as `https://staging.foliobruma.com`, then click **Save server settings**.
Quit and reopen the scanner. A DEV indicator shows the active server.

Sign in again for that server and start a new test document. Each server has a
separate Keychain credential and selected archive. Saved upload records stay
bound to their original server; legacy records belong to production. Label URLs
come from the selected server. Local scanning works without a connection.

The server must permit native scanner API requests. A browser-only Cloudflare
Access login is not sufficient; the scanner does not copy browser cookies or
follow API redirects. To return to production, disable developer mode, save,
and restart the app.

For a developer server protected by Cloudflare Access, restart on that server,
then enter its service token in the developer settings. **Save Access token**
stores both fields in macOS Keychain for the current origin. The secret is not
stored in preferences or sessions. The scanner sends the Access headers only
to that developer server; redirects are still blocked. The Access policy must
use **Service Auth** and select this token. SaaS sign-in is still required.
Use **Remove Access token** to remove the local copy. Revoke the token in
Cloudflare to remove server access.
