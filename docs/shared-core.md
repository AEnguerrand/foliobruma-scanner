# Shared code and platform code

The repository has two Swift modules. The Mac app depends on `ScannerCore`.
`ScannerCore` does not depend on the Mac app. It imports only Foundation and
has no third-party packages. This is the first code split for a future Windows
app. It does not add Windows camera, interface, installer, or device support.

## Current boundary

| Code | Location | Responsibility |
| --- | --- | --- |
| Document, page, and rejection data | `Sources/ScannerCore/` | Existing Codable session schema, page order, original paths, merge sources, and review records |
| Metadata and sheet groups | `Sources/ScannerCore/` | Stored fields, group order, and next-letter or next-sheet defaults |
| Session automation | `Sources/ScannerCore/` | Stored upload and print options; new options default to off |
| Crop geometry | `Sources/ScannerCore/Quad.swift` | Coordinates, bounds, area, and padding; Foundation geometry types |
| Capture and warning gates | `Sources/ScannerCore/CaptureGates.swift` | Timing decisions from supplied time and detection flags |
| Display text | `Sources/FoliobrumaScanner/Models/ScanDocument.swift` | Localized new-document title and display fallback |
| Storage and file locks | `Sources/FoliobrumaScanner/Models/` and `Scanner/` | Mac library path, reference counter, group locking, session writes, and published state |
| Camera and image processing | `Sources/FoliobrumaScanner/Scanner/`, `Capture/`, and `Imaging/` | AVFoundation, Vision, Core Image, and USB input |
| Interface, PDF, labels, and printing | `Sources/FoliobrumaScanner/Views/`, `Models/`, and `Sources/PrinterUSB/` | SwiftUI, AppKit, PDFKit, and IOKit |
| Account and upload operations | `Sources/FoliobrumaScanner/Cloud/` | Current API client, Keychain credentials, PDF preparation, and retry records |

The shared gates receive a monotonic elapsed time from the platform caller.
They do not open a camera, detect a hand, save an image, or emit a signal.
Capture thresholds and crop calculations are unchanged by this split.

`ScanDocument` requires a title from its caller. The Mac extension retains the
existing localized default. Decoding an existing title does not translate it.
Rejected-scan reasons remain stored resource keys. All existing JSON keys,
optional fields, coordinate encoding, and original-image paths are retained.
The Mac bundle identifier and session directory are unchanged.

## Build and tests

From the repository root:

```sh
swift run ScannerCoreChecks  # Shared library and tests only
./test.sh                    # Shared tests and Mac regression tests
./build.sh                   # Shared static library and Mac app
```

The package manifest includes only `Sources/ScannerCore/` and
`Tests/ScannerCore/`. Mac scripts use `build-core.sh` to build the same source
as a separate static library for macOS 14. The library is linked into the app;
there is no extra runtime library to install.

The test executable needs no XCTest installation, so it also runs with Apple
Command Line Tools alone. Shared tests cover old session decoding, exact JSON
structure after a round trip, original-image and merge records, batch defaults, capture cooldown, and
warning resets. CI runs the package on Linux as well as in the Mac test script.
Linux checks expose Apple framework dependencies but do not prove Windows
compatibility. Windows compilation and physical hardware tests remain required.

## Next extractions for Windows

1. Move session file operations behind an explicit storage interface. Keep the
   current commit-before-published-state rule, atomic writes, and original files.
2. Separate reference and group rules from their Mac file locks. The Windows
   implementation must preserve exclusive cross-process access and stale-write
   checks. Do not replace these locks with a thread-only lock.
3. Split the archive API and retry rules from Keychain, PDF rendering, and app
   preferences. Pass credentials and prepared PDF data through explicit inputs.
4. Add Windows camera, image-processing, PDF, print, and USB implementations.
   Supply their detection results to the existing shared capture gates.
5. Add a Windows build and run the same session fixtures there before claiming
   session compatibility. Then test camera resolution, capture timing, and
   printer completion with real hardware.

Keep new platform dependencies out of `ScannerCore`. Add a platform interface
when there is a concrete caller and implementation to test. A Windows frontend
written in another language will also need a language boundary to use this
Swift module; this change does not provide C or .NET bindings.
