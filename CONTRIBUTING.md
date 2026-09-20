# Contributing

Small fixes, hardware test reports, and improvements to scanning are welcome. For a larger change, open an issue first to discuss the scope.

## Source layout

| Path | Purpose |
| --- | --- |
| `Sources/FoliobrumaScanner/App/` | SwiftUI app entry point and window setup |
| `Sources/FoliobrumaScanner/Models/` | Saved document and page data |
| `Sources/FoliobrumaScanner/Scanner/` | Observable state and extensions for camera capture, processing, sessions, feedback, and PDF export |
| `Sources/FoliobrumaScanner/Capture/` | Automatic capture and warning gates |
| `Sources/FoliobrumaScanner/Imaging/` | Paper detection, image checks, and crop coordinates |
| `Sources/FoliobrumaScanner/Views/` | Main view, camera preview, controls, and page review |
| `Resources/Info.plist` | App metadata and camera permission text |
| `Tests/SessionTests.swift` | Regression tests with temporary session data |
| `build.sh` | Compile and locally sign the Mac app |
| `test.sh` | Compile and run the regression tests |

The app uses SwiftUI, AppKit, AVFoundation, Vision, Core Image, and PDFKit. It has no third-party runtime packages.

`ContentView` owns the `Scanner` model. Child views observe the same model. Stored
properties and initialization stay in `Scanner.swift`. Related operations stay in
extensions named `Scanner+<Purpose>.swift`. These files are one Swift module;
the extensions do not create separate services or change thread ownership.
Camera work stays on the camera queue. Published interface updates stay on the
main queue.

Use a separate file for each main type or view. Keep small related capture gates
together. Put new Swift files under `Sources/FoliobrumaScanner/`. Both scripts
include Swift files in this folder and its subfolders. The test build excludes
the app entry point with `SCANNER_TESTS`.

## Interface languages

English and French text is in `Resources/en.lproj/` and `Resources/fr.lproj/`.
Use `L10n.text` for interface text and `L10n.format` for messages with values.
Keep each message in one resource entry. Keep format placeholders such as `%ld`
and `%@` in both translations. `InfoPlist.strings` contains the camera permission
text. The build script copies the language folders into the app before signing.

Keep stored rejection reasons as English resource keys. Translate them when
shown. Do not translate storage paths, identifiers, or user document names.
The language setting uses the app-specific `AppleLanguages` preference and takes
effect at the next launch.

## Before a pull request

Run:

```sh
./test.sh
./build.sh
git diff --check
```

For camera, crop, or capture changes, also test with a real document camera. Report the camera model, macOS version, steps, and observed result. Automated tests do not prove live camera behaviour or sound timing.

Keep local scanning available without an account. Preserve existing sessions and original captures. Explain any change to the storage format or capture behaviour in the pull request.

## Release pipeline

GitHub Actions runs tests and creates a DMG, ZIP, install notes, license, and
SHA-256 checksums for pull requests, branch pushes, and manual runs. Download
these files from the `macOS-arm64` artifact on the Actions run page. The runner
uses Apple Silicon and macOS 15; the app deployment target remains macOS 14.
Artifacts expire after 14 days. Published release files remain on Releases.

To check the same package locally:

```sh
./test.sh
./release.sh 0.1.0
git diff --check
```

Files are saved under `build/release/0.1.0/`. The script sets the version in the
built app; it does not change the source plist. It uses the existing ad-hoc
signature. No Apple account, certificate, notarization secret, or paid service
is required.

To publish, commit the required source and pipeline changes, push that commit,
then push a new version tag. For example, use these commands only when `v0.1.0`
is the intended version and does not already exist:

```sh
git tag v0.1.0
git push origin v0.1.0
```

Tags must use `vX.Y.Z`. After tests and packaging pass, the publish job creates
a GitHub Release with the downloads and install steps. Only that job has
`contents: write` permission. Pull requests and manual runs do not publish.
The workflow does not replace an existing release. Use a new version tag for
changed files. Before publishing, test installation and camera access on a Mac
with a downloaded package. Local tests do not verify Gatekeeper or live capture.

## Report a problem

[Open an issue](https://github.com/AEnguerrand/foliobruma-scanner/issues) with:

- Your Mac, macOS version, and camera model.
- The commit or version you built.
- Steps to repeat the problem.
- What you expected and what happened.
- Whether it occurs during manual or automatic capture.

Use blank or synthetic documents for examples. Do not upload private letters, scans, session folders, or credentials. The repository excludes common image and PDF formats by default to help prevent accidental uploads.

## License

Contributions are provided under the repository's [MIT license](LICENSE).
