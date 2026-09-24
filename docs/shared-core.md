# Shared code and platform code

The repository has two Swift modules. The Mac app depends on `ScannerCore`.
`ScannerCore` does not depend on the Mac app. It imports only Foundation and
has no third-party packages. The core contains document, storage, batch, upload,
and print rules. It does not provide a Windows interface or device support.

## Current boundary

| Shared code in `Sources/ScannerCore/` | Responsibility |
| --- | --- |
| Document and page models | Existing Codable session schema, original paths, merge sources, and review records |
| `DocumentOperations.swift` | Rotation, page order, removal, undo insertion, replacement identity, rejection resolution, and completion flags |
| `SessionStore.swift` | Create, load, and atomically save manifests; list sessions; recover rejected photos |
| Metadata and automation models | Batch defaults and stored upload and print options |
| `ItemReference.swift` | Reserve local reference numbers and recover the counter from restored sessions |
| `SheetGroupStore.swift` | Load and save group order, reject stale writes and overlapping membership, and find sheet records |
| `CloudUpload.swift` and `UploadPolicy.swift` | Multipart upload, retry records, destination and fingerprint checks, canonical hash input, and print retry state |
| `PermanentLabel.swift` | Label reservation identity, revision checks, and recovery after a lost attachment reply |
| `ArchiveServer.swift` | Validate and normalize server origins |
| `QL600Raster.swift` | Pack supplied black pixels into QL-600 commands |
| `Quad.swift` and `CaptureGates.swift` | Crop geometry and capture or warning timing |

| Mac code | Responsibility |
| --- | --- |
| `Models/MacLibraryLock.swift` | Exclusive cross-process file locks through Darwin |
| `Models/ItemReference.swift` and `Models/SheetGroupStore.swift` | Supply Mac locks to shared operations |
| `Models/ScanDocument.swift` | Localized default titles and display fallback |
| `Scanner/` | Select the library path, coordinate camera and interface work, and publish state after saves |
| `Cloud/CloudAPI.swift` | HTTP transport, redirect and credential policy, Keychain, and error localization |
| Other files in `Cloud/` | Account interface state, pairing, preferences, PDF rendering, and SHA-256 |
| `Views/`, `Imaging/`, `Capture/`, and printer files | SwiftUI, Apple image processing, camera preview, QR rendering, USB input, and printer transport |

Mac paths in the table are relative to `Sources/FoliobrumaScanner/`. The direct
USB printer transport is in `Sources/PrinterUSB/`.

## Platform contracts

`SessionStore` takes an explicit folder. It has no application-support path,
account requirement, or interface state. Page operations return a new document.
The Mac caller saves that document before publishing it. A failed write leaves
the current document and selection unchanged. Removal, replacement, and undo do
not delete source images. A new session becomes active only after its manifest
is written. The old session is saved first by the caller.

`LibraryLocking` must hold an exclusive cross-process lock until its body
returns or throws. Reference allocation and group read/check/write operations
run inside that lock. The core has no default lock. Windows must supply an
implementation before it can use these operations. A thread-only lock is not
sufficient. Group validation also compares the saved snapshot before writing.

`ArchiveTransport` receives a request with its path, method, data, query, and
revision. The adapter supplies the fixed server origin and credentials. It must
reject redirects, keep credentials scoped to that origin, and report HTTP
failures as `CloudFailure` with their status code. Retry rules depend on the
status: an explicit client rejection permits another start; an uncertain start
does not. Mac HTTP behavior and Keychain storage stay in the existing adapter.
Shared errors carry resource keys; the Mac app translates them for display.

PDF rendering and SHA-256 remain platform services. The shared core prepares
the canonical fingerprint data and reads the exact saved PDF for retries.
Label reservation IDs are saved before requests. The core checks label revisions
and recovers a lost attachment reply before it attempts another write.

Print intent is saved before a job can be sent. An unknown print result blocks
another job until the user checks the physical label. Confirmation updates the
record without sending a job. `QL600Raster` generates bytes only; the platform
renders the label, reads pixels, sends USB data, and checks printer completion.

Capture gates receive monotonic elapsed time and detection flags from the
platform. They do not open a camera, detect a hand, or emit a saved signal.
Capture thresholds and crop calculations are unchanged by this split.

## Compatibility and validation

Existing JSON keys, optional fields, coordinate encoding, and original-image
paths are retained. The Mac bundle identifier and session directory are
unchanged. Stored titles and rejection keys are not translated on decode.

From the repository root:

```sh
swift run ScannerCoreChecks  # Shared library and tests only
./test.sh                    # Shared tests and Mac regression tests
./build.sh                   # Shared static library and Mac app
```

The package contains only `Sources/ScannerCore/` and `Tests/ScannerCore/`.
The Mac scripts use `build-core.sh` to build the same source as a separate
static library for macOS 14. No extra runtime library is installed.

The test executable works with Apple Command Line Tools alone. Shared tests
use temporary folders and a fake transport. They check old session decoding,
page operations, failed writes, original preservation, recovery, reference
allocation, group conflicts, exact multipart bytes, lost server replies,
print retry guards, and printer command bytes. Mac integration tests also
cover localized errors, PDF export, image processing, and the existing flows.
CI runs the core on Linux and the full app tests and build on macOS.

## Remaining Windows work

- Supply a cross-process lock and an HTTP adapter that satisfies the contracts.
- Supply credential storage, hashing, PDF and QR rendering, camera access,
  image processing, USB input, and printer transport.
- Build a Windows interface and connect its state to the shared operations.
- Test file-write and lock behavior on Windows, including concurrent writers.
- Run the session fixtures and hardware tests before claiming compatibility.

Linux checks expose Apple framework dependencies but do not prove Windows
compatibility. Camera resolution, capture timing, physical labels, and printer
completion still need checks on the target hardware. A Windows frontend in
another language also needs bindings to use this Swift library; this change
does not supply C or .NET bindings.
