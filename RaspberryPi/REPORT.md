# Phase 0 hardware report

Gate status: NOT RUN. Change this only after the checks below.

- Date and operator:
- Source head and clean/changed state:
- Archive SHA-256, if used:
- Pi model and RAM:
- OS image name, download URL, image SHA-256, installed updates:
- Kernel, Swift, libusb, libqrencode, V4L2, Python, OpenSSL versions (logs):
- Power supply, cable, fan, storage, and free space:
- Camera model, USB VID:PID, stable node, USB speed/topology:
- Requested mode and negotiated mode (dimensions, format, fps):
- Captured JPEG dimensions; focus, all page edges, light, distortion:
- Printer model, USB VID:PID, status bytes, roll model and measured width:
- Print command folder, transfer result, physical label count, cut length in mm:
- iPhone model, iOS version, exact decoded QR payload:
- Pi LAN address, Safari URL, CA fingerprint, trust setup steps and result:
- Safari reopen result; local hostname result or not configured:
- Before/after temperature, power status, USB resets or disconnects:
- Permission, driver, firewall, and other temporary changes; restoration result:
- Test CA removed from iPhone and private keys removed after testing:

| Gate | Pass / fail / not run | Evidence and failed steps |
| --- | --- | --- |
| Swift 6.0.3 and ScannerCoreChecks on Linux aarch64 | Not run | |
| Diagnostic Swift and C tools build on this Pi | Not run | |
| Exact full page camera mode and usable test photo | Not run | |
| QL-600 status and one physical label with cut | Not run | |
| iPhone reads exact synthetic QR payload | Not run | |
| iPhone trusts HTTPS after Safari closes and opens | Not run | |
| Supply, heat, and USB connection observations | Not run | |

Command reports and manual observations:

Failures and operator decisions before any manual print retry:

Remaining blockers and next step:

Do not include private documents, credentials, or TLS private keys. A host test,
CI result, or printer completion packet does not replace a physical observation.
