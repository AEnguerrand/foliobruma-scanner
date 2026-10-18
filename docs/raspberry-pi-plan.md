# Raspberry Pi scanning station plan

[Documentation](README.md) · [Shared core](shared-core.md) · [Mac development](development.md)

Date: 18 October 2026. Status: proposed work, not an available Pi release.
Source baseline: `d3f0ce189d018eea9825100f7b22bb69182b562d` on `main`.
This document plans a separate Pi service. It does not change the Mac app.
No Pi, Linux camera, iPhone, or Linux printer test was run for this plan.

## Intended result

Connect the IRIScan Desk 6 Pro and Brother QL-600 to a dedicated Raspberry Pi.
Use Safari on an iPhone to control scanning, review pages, export PDFs, and
print labels. The Pi owns the devices and saved files. The phone is a control
screen. A Mac is not needed during normal Pi use.

Keep the current native Mac app available and usable without a Pi. Local
capture, review, storage, label generation, and PDF export must need no account
or internet connection on either platform. Reading an existing online QR link
can still need a network and sign-in.

## Scope and first decisions

- Use one repository, the existing `ScannerCore`, and separate platform code.
- Build a browser interface first. A native iOS app is outside this plan.
- Support one camera, one QL-600, and one active operator per station first.
- Deliver manual capture before automatic capture. Add book split and batches
  after the save and review path is reliable.
- Keep English and French interface text. Keep document text, identifiers,
  stored keys, and URLs unchanged when the language changes.
- Do not add telemetry, cloud OCR, remote access, router port forwarding, or
  mandatory cloud services. Do not add automatic uploads in the first release.
- Keep existing Mac cloud and permanent-label features working. An optional
  Pi account adapter is a later phase, separate from local scanning.

## Hardware and operating system

| Part | Initial choice | Check before approval for regular use |
| --- | --- | --- |
| Pi | Raspberry Pi 5, 4 GB RAM | Measure memory and capture-to-save time during a long batch. 8 GB is optional margin, not a requirement proved by tests. |
| Power and cooling | Official 27 W USB-C supply; Pi 5 case with fan | Check for low voltage, USB resets, and thermal throttling under capture, export, and printing load. |
| System disk | 64–128 GB high-quality microSD | Keep logs bounded. Check restart and storage-full behaviour. |
| Scan disk | Start on microSD; use a USB SSD for large collections | An SSD is not a backup. Identify the volume by UUID and refuse capture if its expected mount is absent. |
| Network | Pi on home Ethernet or Wi-Fi; iPhone on the same LAN | Check discovery, reconnection, and direct address fallback. Internet is not required after installation. |
| Camera | Existing IRIScan Desk 6 Pro | Enumerate actual Linux formats, dimensions, rates, and controls. Prior Mac evidence is not Linux support. |
| Printer | Existing QL-600 with DK-22205 62 mm continuous roll | Check device status, physical label length, cut, margins, and QR readability. |

Use Ubuntu Server 24.04 LTS ARM64 as the initial build and runtime target.
It has a Pi 5 image and official Swift toolchains for its ARM64 platform.
This is a deliberate change from the earlier Raspberry Pi OS suggestion:
it gives the existing Swift core a documented toolchain target. Raspberry Pi
OS 64-bit can be evaluated later; do not assume a Raspbian driver or a Swift
binary for another distribution works on this target.

Use a powered USB hub only if measured device power requires one. The QL-600
uses its own power supply. The Pi supply, camera, fan, and SSD power budget
must be checked together. Do not require a display or keyboard for daily use.

## Existing code to keep and reuse

The current source already has a portable Swift package and Linux CI. A Pi
version does not need a second implementation of its document rules.

| Existing source | Pi use | Mac protection |
| --- | --- | --- |
| `Sources/ScannerCore/` document models, `DocumentOperations`, `SessionStore` | Keep the session schema, page order, rotations, originals, rejection records, and failed-write rules. | Use the same shared source and old-session checks. |
| `ItemReference`, `SheetGroupStore`, `LibraryLocking` | Reuse counters and group rules. Add a Linux cross-process file-lock adapter. | Keep `MacLibraryLock` and the Mac library location. |
| `CaptureGates` and `Quad` | Reuse monotonic timing and geometry. Linux supplies detection results. | Do not change Mac thresholds to tune Pi detection. |
| `QL600Raster` | Reuse the existing black-pixel-to-command encoder. | Keep current Mac raster and USB paths. |
| `LabelPrintStore` | Reuse print reservation, duplicate checks, explicit reprint, and unknown-result recovery. | Keep existing manual and automatic print history. |
| Upload and permanent-label rules | Preserve records during session transfer; reuse for a later optional Pi account adapter. | Keep Mac upload, credentials, revisions, and retry behaviour. |

New Linux adapters are required for V4L2 capture, image analysis, crop, PDF and
QR rendering, USB transport, local access control, and the service lifecycle.
`AppKit`, `AVFoundation`, `Vision`, `CoreImage`, `PDFKit`, and the current IOKit
USB transport do not run on Linux. Linux CI for the core does not prove device
support or image quality.

### Proposed source boundary

These paths are planned, not existing commands or packages:

```text
Sources/ScannerCore/           Existing portable data and rules
Sources/FoliobrumaScanner/     Existing native Mac app and Apple adapters
Sources/PrinterUSB/            Existing Mac printer transport
RaspberryPi/
  Package.swift               Separate Pi package; local dependency on ../
  Sources/ScannerStation/     Swift coordinator, local API, locks, and jobs
  Sources/LinuxAdapters/     C-compatible bridges for Linux device/image code
  Web/                       Local HTML, CSS, JavaScript, English, and French
  Tests/                     Pi contracts, simulated failures, and fixtures
  Packaging/                 ARM64 package, service, device rules, install notes
```

Prefer a Swift coordinator which imports `ScannerCore`. Evaluate Hummingbird
for HTTP, V4L2 for camera access, OpenCV for image operations, libusb for the
printer, and Cairo plus libqrencode for PDF/label drawing. Confirm versions,
licenses, ARM64 packaging, and measured memory use in phase 0 before selection.
Keep each required third-party dependency in the Pi package or Linux adapter;
do not add it to the shared package or the Mac build. Keep the MIT license
and include required dependency notices in a Pi distribution.

Do not build a custom HTTP protocol or copy session and print rules into
JavaScript or a second backend. If Swift deployment fails its first gate,
record the failure and revise the boundary before building the interface.

## Service, storage, and phone contracts

### One owner of state

The Pi service owns camera and printer handles. It serializes document edits
and device jobs. Image work must not block network responses. Permit one
full-resolution processing job at a time and bound preview buffers. Discard
old preview frames, not saved pages. Read the camera once and derive the
preview from that stream; do not assume simultaneous high-resolution and
preview streams are available.

Use command IDs and durable results for capture, finish, export, and print.
A repeated tap or retried request returns the existing job result. Include a
session ID and revision in edits. Reject stale edits and require an explicit
operator takeover. A second phone can view state but must not silently control
the current run. These service records sit beside the library and do not add
required fields to Mac session manifests.

### Save and recovery

- Use a proposed Pi library root of `/var/lib/foliobruma-scanner/library/`, or
  one explicitly selected mounted volume. Give the service a dedicated user.
- Retain the existing `Sessions/<id>/`, `Originals/`, `Pages/`, `Rejected/`,
  `session.json`, group files, counter files, and `label-prints.json` contracts.
- Save original and processed files before publishing a new manifest. Emit
  **Saved — turn the page** only after the complete save succeeds. Record
  failed and incomplete jobs for recovery; do not mark them saved.
- Add Linux file and directory sync around committed writes where needed.
  Atomic rename alone is not proof of survival after a power cut. Test this
  on disposable synthetic sessions, never private documents.
- Removal and recrop retain source images. Failed writes leave the prior
  document usable. Rejected images stay out of PDF export until accepted.
- Keep a reserve of free space. Stop new capture before the reserve is used;
  preserve existing files and show the problem on the phone. Bound logs and
  temporary files. Never remove originals to make room automatically.
- Transfer sessions as complete copies with a manifest and file checksums.
  Test both Mac-to-Pi and Pi-to-Mac copies. Do not use a live shared network
  folder or introduce two writers to one library. Imported references can
  collide across devices; preserve identity and show conflicts for review.
- Back up the whole library and service job records. Exclude credentials from
  normal export. Test restore, then make a new scan and review print history.

### Local connection

Serve the interface, preview, thumbnails, downloads, and API from one local
origin. Bundle all assets; no CDN or internet request is required for use.
Use a local hostname such as `scanner.local` and show an address fallback.
The first setup must test local HTTPS certificate trust on a real iPhone.
Provide a documented station certificate/trust procedure and locally issued
pairing code; require pairing for scans, preview, downloads, and commands.
Credentials must not appear in URLs or logs. No cloud account is needed.

Use host/origin checks, CSRF protection, bounded request sizes, and opaque file
IDs resolved inside the library. Bind access to the intended local interfaces.
A device on the same LAN is not automatically an operator. Do not expose the
service to the internet. A trusted-iPhone setup and recovery path is a release
gate, not a certificate warning the user must ignore on every visit.

For the first interface use an MJPEG preview or bounded JPEG updates, plus
small state updates. Measure Safari support and bandwidth before choosing the
transport. Full-resolution images remain on the Pi. Export an ordinary PDF
which Safari can download and share. Do not require phone camera permission,
service workers, push notifications, or App Store installation.

## iPhone interface

| Screen | Required actions and visible state |
| --- | --- |
| Connect | Pair with the station; show camera, printer, storage, and connection state. |
| Documents | Create/open a document; title and reference; search; English/French setting. |
| Scan | Large preview and crop outline; Capture page; Start/Pause; Book/Single page; saved page count and clear warnings. |
| Review | Thumbnails, full-page zoom, rotation, order, removal/undo, rejected-photo review, and manual crop. Pause auto capture on entry. |
| Finish | Export/download PDF; check page count and rejected photos; preview/print label; finish item or start the next sheet. |
| Station | Device selection, free space, backup/export, service version, and safe shutdown. |

Keep the main capture controls visible on a small portrait screen. Test
landscape, safe areas, large text, VoiceOver labels, and French text expansion.
Use a muted inline preview. Enable phone sounds only after an explicit Start
or Enable sound tap. Always show save state as text and colour; do not depend
on sound or vibration. Test sound on a real phone, not only browser automation.

The Pi is the source of saved-page counts and job status. Reconnection loads a
fresh snapshot and then new events; it must not play old saved signals again.
The first release pauses new automatic captures when the active phone stops
renewing a short control lease. A pending save or print can finish. Test a
five-second lease as the initial value. Returning to Safari requires explicit
resume. This prevents continued page capture without visible feedback when
the phone locks or Safari suspends. An optional Pi speaker and operation
without a connected phone can be evaluated later.

## Label printing

Use the existing physical format: **62 × 25 mm**, black on white, DK-22205.
The current encoder uses **696 × 225 printable pixels**, with feed margins.
Do not treat 225 pixels as the full physical label length. Generate QR pixels
and text on the Pi; use one rendered bitmap for preview, PDF, and USB commands.
Keep sharp module edges, a sufficient quiet zone, and readable identifiers.
Test the shortest and longest allowed links and accented titles.

Prefer a direct Linux USB adapter with libusb and the current `QL600Raster`.
Reuse the existing QL-600 status sequence and error semantics, not the IOKit
calls. Confirm the model, 62 mm continuous roll, cover state, and completion.
Make device rules narrow. Do not run the network service as root or let CUPS
and direct USB transport own the printer at the same time. A successful USB
write or queue submission alone does not prove a label was printed.

Use `LabelPrintStore.begin` before sending bytes. Complete the saved job after
the device result. An uncertain result stays pending after a crash or timeout.
Never silently retry it. The phone must offer **Confirm label handled** and
an explicit **Reprint** action. Retry is permitted automatically only when the
adapter proves that no print data could have been sent. Keep the same guards
for manual print and print-on-finish. Test network retries and two phones.

For the first offline release, print an existing valid HTTPS link supplied by
the user or retained in an imported session. Do not invent an online document
URL or reserve an ID without the archive. A new local scan without a link can
be saved and exported; explain why its QR label is not yet available. Creating
a QR is offline; opening an online destination is a separate operation.

A later optional archive adapter can reserve permanent `/d/` identities,
attach PDFs, and print on finish using the existing revision and retry rules.
Use `ArchiveTransport` with origin-scoped credentials and no redirects. Keep
private documents private. No automatic upload or server API change belongs
in the local-station phases. QR-based local document links need a separate
identity/address design and are not part of the first release.

## Phases, outputs, and gates

Estimates below are engineering time for one developer with the Pi, camera,
printer, roll, and iPhone available. They are not measured delivery dates.
Do not proceed past a failed hardware gate by assuming another Pi fixes it.

| Phase | Deliverable and ownership boundary | Exit gate | Estimate |
| --- | --- | --- | --- |
| 0: feasibility | Pi-only diagnostic code and a synthetic hardware report. Pin OS/toolchain, enumerate V4L2 modes, run `ScannerCoreChecks` on ARM64, save a full-resolution page, print and cut one QR label, and open a trusted local page on iPhone. | Record exact devices/OS/versions, actual dimensions/rate, readable text, physical QR read, driver ownership, and power status. Stop or revise the design if any part fails. | 1–3 days; driver work can extend this. |
| 1: manual station | Separate Pi package, single service owner, Linux locks, persistent command IDs, secure pairing, and basic iPhone capture/review/PDF flow. Use a manual crop before automatic crop. | Twenty synthetic pages survive save/restart, browser retries, rotate/order/remove/undo, PDF download, and a phone disconnect with no extra capture. Mac compatibility checks pass. | 4–7 days. |
| 2: labels | Linux renderer and USB/status adapter using shared raster and print history. Phone preview, Print, Reprint, and unknown-result review. | Physical format and QR pass; cover open, wrong roll, cable loss, printer power loss, and lost phone replies cannot silently duplicate labels. | 3–5 days. |
| 3: automatic capture | Linux page, movement, hand/obstruction, duplicate, blur, and exposure checks feeding shared gates; automatic crop, book split, and manual overrides. | Labelled non-private scenarios record missed pages, false warnings, duplicate captures, crop error, and save latency. Hand detection must be implemented and checked before being advertised. | 1–3 weeks; largest uncertainty. |
| 4: dedicated appliance | ARM64 release package, startup service, narrow device permissions, disk checks, backup/restore, safe shutdown, and update/rollback procedure. | Cold boot without a screen; printer can be absent at boot; USB reconnect works; a service crash preserves committed scans; interrupted jobs are visible; update and rollback retain the library. | 3–5 days. |
| 5: pilot | Batch UI, required sheet/letter flow, English/French checks, physical acceptance report, and full compatibility validation. | The long-batch, hardware, iPhone, and Mac gates below pass on the final version. Publish only supported and tested capabilities. | 3–5 days. |
| 6: optional follow-up | Pi account/upload adapter, permanent-label reservation/attachment, larger batch grouping, physical USB button, or Pi speaker. Separate scoped PRs. | Existing cloud contracts plus authenticated end-to-end and physical tests for each selected feature. | Estimate separately. |

Allow roughly **2–3 weeks for a manual station with labels**, then **4–8+ weeks
total for a reliable automatic-scanning pilot**. The estimates overlap by
phase and assume phase 0 passes. Full Mac feature parity is not in this range.

## How to keep the Mac app working

1. Start each phase from a clean committed worktree. Keep Pi source, web assets,
   dependencies, package files, and service scripts under `RaspberryPi/`.
2. Keep `build.sh`, `test.sh`, `build-core.sh`, Mac resources, app identifiers,
   and the legacy Mac session path unchanged unless a scoped change is needed.
   Keep Apple imports and Pi dependencies out of `ScannerCore`.
3. Use existing shared APIs first. Put a required shared change in its own
   small compatibility PR with old-session, failed-write, and print-history
   checks. Do not tune shared capture timing to hide a Linux detector problem.
4. Retain the existing Linux shared-core CI job and Apple Silicon Mac test/build
   job. Add Pi jobs; do not replace Mac jobs or make the Mac build require
   Linux libraries. Check final source once per required profile.
5. Keep the existing Mac tag/release workflow. Build Pi artifacts with a distinct
   workflow and Pi-specific tags, for example `pi-v0.1.0`, so a Mac tag cannot
   publish a Pi-only release. Recheck the current `v*` trigger before adding
   any release trigger. Do not publish during the planning or feasibility work.
6. At a phase boundary retain a short report: exact head, changed files,
   checks, hardware results, open processes, limits, and the next step.

## Validation and release acceptance

For this documentation-only plan, check whitespace, the diff, local links,
and command examples. No app rebuild or hardware claim is required.

For each later code or build change, run from the repository root:

```sh
./test.sh
./build.sh
git diff --check
```

`./test.sh` already runs `swift run ScannerCoreChecks`. Do not repeat the
shared profile unless a separate Linux target or changed source needs it.
Add focused Pi tests and ARM64 builds. An x86 Linux CI pass is not ARM64
validation. Keep fake devices, temporary sessions, and synthetic images in
software tests; never use private scans as fixtures.

| Evidence | Required checks |
| --- | --- |
| Shared contracts | Old session decode; Mac/Pi round trip; page order/rotation; originals retained; rejected-photo handling; failed writes; Linux cross-process locks; stale revisions; reference/group conflicts; print history and unknown results. |
| Pi service | Duplicate commands, simultaneous requests, bounded buffers, disk full, missing mount, service restart during capture/print/export, invalid file IDs, unpaired access, CSRF/origin checks, and complete backup/restore. |
| Real camera | Stable page; page turn; hand entering/leaving and resting on the page; intentional manual repeat; similar text pages; duplicate page; lighting change; glare; cropped edge; book spread. Record misses and false positives separately. |
| Real printer | Repeated 62 × 25 mm labels; cut/feed length; long-link QR read by iPhone; accented text; wrong roll; empty roll; open cover; cable loss before/after send; completion status; uncertain outcome and explicit reprint. |
| Real iPhone | Record iPhone/iOS/Safari versions. Pair/trust setup, portrait/landscape, large text, VoiceOver, English/French, sound after tap, PDF download/share, lock/unlock, Wi-Fi loss, stale preview, reconnect, and two-phone ownership. |
| Long batch | At least 500 page sides over at least 60 minutes using public/synthetic material. Record actual pace, missing/extra pages, memory, temperature, voltage, CPU, free space, preview delay, and p50/p95 capture-to-save time. |
| Mac regression | Required scripts pass. Open old and Pi-created synthetic sessions; capture, review, export, labels, and existing optional upload still work on Mac. Physical camera/print and authenticated tests are separate from automated evidence. |

Proposed performance targets for the pilot are preview age below one second
and p95 capture-to-save below two seconds after the stability gate accepts a
page, at the mode accepted in phase 0. These are targets, not current results.
Require no missing or extra committed pages in the counted long-batch test,
no automatic repeat of an uncertain label, and stable memory use. If targets
fail, reduce preview work or revise the supported capture mode explicitly;
do not silently lower saved resolution. Report unavailable hardware tests as
not run. Controlled power-loss tests use a disposable library and backup.

## First implementation task and handover

The next task is **phase 0 only**: prepare a reproducible ARM64 diagnostic
package and the hardware report template, then run it on the target station
when available. Its evidence must include the source head, OS image, Swift and
library versions, USB IDs, negotiated capture mode, image dimensions, printer
status, roll, cut length, QR read result, iPhone trust/setup result, and all
failed steps. No production upload or private session is needed.

This planning phase changes only this document and the documentation index.
It starts no scanner, print service, or build. The Mac checkout is kept separate.
Hardware support, ARM64 execution, capture speed, and print quality remain
unverified until the corresponding phase gates pass.

## Source references

External references were checked on 18 October 2026. They describe available
interfaces, not a passed test of this station.

- [Pi 5 specifications and accessories](https://www.raspberrypi.com/products/raspberry-pi-5/).
- [Pi USB and power requirements](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html).
- [Ubuntu 24.04 Pi 5 support](https://documentation.ubuntu.com/release-notes/24.04/) and [Ubuntu Pi images](https://ubuntu.com/hardware/docs/boards/how-to/ubuntu_supported/raspberry-pi/).
- [Swift toolchains for Ubuntu 24.04, including ARM64](https://www.swift.org/install/linux/ubuntu/24_04/).
- [V4L2 device discovery](https://www.kernel.org/doc/html/latest/userspace-api/media/v4l/open.html) and [format negotiation](https://cdn.kernel.org/doc/html/latest/userspace-api/media/v4l/format.html).
- [Brother QL-600 raster command reference](https://download.brother.com/welcome/docp000698/cv_ql600710720_eng_raster_102.pdf). Use the existing project encoder first; old Raspbian drivers are not proof of Ubuntu ARM64 support.
- [libusb API](https://libusb.sourceforge.io/api-1.0/), [OpenCV image I/O](https://docs.opencv.org/4.x/d4/da8/group__imgcodecs.html), [Cairo PDF output](https://www.cairographics.org/manual/cairo-PDF-Surfaces.html), and [libqrencode](https://fukuchi.org/works/qrencode/).
- [Hummingbird HTTP framework](https://github.com/hummingbird-project/hummingbird) and [systemd service lifecycle](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html).
- [WebKit iOS media policies](https://webkit.org/blog/6784/new-video-policies-for-ios/). Test sound and foreground/background behaviour on the target iPhone.

## Phase 0 package status

The [diagnostic package](../RaspberryPi/README.md) provides the first hardware
checks and a [report template](../RaspberryPi/REPORT.md). Hardware acceptance
is pending. The diagnostic tools do not change the Mac app.

## Phase 1 development status

The [manual station service](../RaspberryPi/STATION.md) is implemented separately
under `RaspberryPi/`. It uses a Swift coordinator with ScannerCore and a small
aiohttp/Pillow platform adapter. Hummingbird remains an evaluated alternative.
The Mac source and build remain separate. See the [result record](../RaspberryPi/PHASE1-RESULTS.md)
for software evidence and open hardware gates. Phase 0 hardware acceptance and
phase 1 Pi/iPhone acceptance are still pending. Production label printing is phase 2.
