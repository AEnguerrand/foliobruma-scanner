# Phase 1 result record

Date: 2026-10-18. Base: `ab689c7b2d1d21ac6740f064666250eea4287c1b`
(phase 0 diagnostic branch). Branch: `codex/raspberry-pi-service`.

## Scope

- New Swift Pi coordinator, using existing ScannerCore document operations.
- Pi-only aiohttp HTTPS and Pillow/FFmpeg device adapter.
- English/French phone interface: pairing, explicit control, document search,
  manual capture/crop, review, rotate/order/remove/undo, and PDF download.
- Local pairing reset, saved command results, revision checks, exclusive library
  and camera locks, disk reserve, commit recovery, and interrupted-job handling.
- Foreground setup guide, boot unit, and separate Pi service CI job.
- Mac source, resources, shared code, build scripts, and release workflow unchanged.
  Diagnostic test discovery is narrowed so phase 0 needs no service dependencies.

## Evidence

The local service tests run the actual Swift coordinator and Python service over
HTTPS. They use generated pages, private temporary folders, two paired clients,
and an independent PDF reader where installed. The checks cover 20 pages across
restart and repeated command IDs; page operations and original preservation;
PDF page count; host, origin, CSRF and unpaired access checks; control takeover
and expiry; stale commands and reused IDs; simultaneous retries; failed image
processing; exclusive ownership; missing library; disk reserve; and recovery
of a saved commit intent. Recovery injection is not a power-cut test.

Local checks passed:

- `./RaspberryPi/test-station.sh`: 8 integration tests, including HTTPS and removed-volume marker checks. The deterministic
  failed-image check also passed on its own after its timing was removed.
- Diagnostic Python suite: all 8 existing tests.
- `./RaspberryPi/build-station.sh`: release build on Apple Silicon. This is a
  host build, not a Pi binary.
- `./test.sh`: shared and Mac regression suites passed.
- `./build.sh`: Mac app built and locally signed. It is not notarized.
- JavaScript syntax and Git whitespace checks passed.
- WebKit at 390 × 844: pairing, take control, create, synthetic capture, review,
  rotate, prepare PDF, download PDF, English/French layout. Both layouts had
  document width 390 with no horizontal overflow; visible page images loaded.
  A browser reload kept the paired connection. Screenshots use synthetic pages.
  The automation injected a screenshot style that CSP blocked; application
  scripts and styles loaded. Expected access errors occurred before pairing
  and during an intentional service restart. This is desktop WebKit emulation,
  not a physical iPhone or Safari certificate-trust result.

CI has a separate Linux service job, alongside the unchanged Mac job and the
phase 0 Linux diagnostic job. Check the PR for its final CI result.

## Open acceptance gates

- Phase 0 physical camera, USB printer, power, TLS trust and network checks.
- Native Ubuntu ARM64 build and tests on the target Pi 5.
- Actual MJPG mode/rate, frame freshness, image quality, capture timing,
  temperature, RAM, CPU and long-run storage behaviour.
- Physical iPhone Safari trust, foreground/background behaviour, full-size page
  viewing, PDF download/share, and two-phone transfer on the actual LAN.
- Abrupt power loss and real write failures; external-volume mount behaviour;
  systemd boot/restart and certificate renewal.
- Open a copied Pi synthetic session in the Mac app and check review/export.
- Label printing is phase 2. No production Pi print command is present.

These open gates prevent a daily-use or hardware-support claim. The service is
ready for supervised hardware validation after its software checks pass.

## Handover

Changes are under `RaspberryPi/`, plus README/index/plan links, ignore rules and
an added Linux CI job. The source uses no remote Swift packages. The service
runs no upload or automatic capture loop. The camera retains only a latest
frame and preview. Pending commands must be resolved before a new capture.
The 10,000-command journal limit is visible and requires future maintenance
work; it does not discard idempotency history.

Next phase: run the hardware gates above, then start a separate phase 2 concern
for QL-600 production labels. Keep label intent/result recovery separate from
this manual station delivery. See [the station guide](STATION.md).
