# Phase 1 scan station

This is a development service for a dedicated Pi. Use the iPhone as its local
control screen. The USB camera stays on the Pi. The Mac app remains a separate
app with its current dependencies, session format, and release process.

Phase 1 provides manual capture, rectangular crop, review, rotation, page order,
remove/undo, and PDF download. The interface is in English and French. It has
no account, uploads, cloud OCR, or external web assets. Label printing is phase
2. Do not use the phase 0 print probe as a production print service.

The software checks use synthetic pages. Pi ARM64, the real camera, power,
thermal behaviour, iPhone certificate trust, and Safari background/download
behaviour still need the [phase 0 hardware checks](README.md) and the checks
at the end of this guide. Do not mark the station ready for daily use yet.

## Build on the Pi

Use the Pi 5 / Ubuntu 24.04 ARM64 / Swift 6.0.3 setup from the diagnostic guide.
Use the exact MJPG size and frame rate confirmed in phase 0. Install the
service tools as well:

```sh
sudo apt-get install python3-venv ffmpeg openssl v4l-utils poppler-utils
./RaspberryPi/build-station.sh
python3 -m venv RaspberryPi/.venv
RaspberryPi/.venv/bin/pip install -r RaspberryPi/requirements.txt
PI_PYTHON=RaspberryPi/.venv/bin/python ./RaspberryPi/test-station.sh
```

Swift has only the local ScannerCore dependency. Python packages are isolated
in the Pi venv. The Mac scripts do not install or import them. The CI Linux
host build is x86_64; it does not prove ARM64 or USB support.

## First local start

Use a reserved LAN address. These examples use `192.168.1.50` and port `8443`.
Replace both with your station settings. Use `https://192.168.1.50:8443` if
`scanner.local` does not resolve. The configured origin must match the address
in Safari exactly. Do not expose the port to the internet.

Generate the local certificate with the phase 0 tool. It expires after seven
days, so this is a development setup. Renew it before expiry. Install and trust
the local root certificate on the iPhone as described in the diagnostic guide.
Keep the root private key off the phone. Never turn off Safari TLS checks.

```sh
python3 RaspberryPi/Diagnostics/diagnose.py tls --output RaspberryPi/tls --ip 192.168.1.50
mkdir -p RaspberryPi/results/camera-lock
RaspberryPi/.venv/bin/python RaspberryPi/Service/station.py \
  --library "$PWD/RaspberryPi/results/library" --initialize \
  --bind 192.168.1.50 --origin https://scanner.local:8443 \
  --certificate RaspberryPi/tls/server.crt --key RaspberryPi/tls/server.key \
  --camera /dev/v4l/by-id/REPLACE_WITH_PHASE_0_DEVICE \
  --camera-lock "$PWD/RaspberryPi/results/camera-lock/camera.lock" \
  --size 3264x2448 --fps 5
```

The camera lock must be the **same absolute path for all service instances**.
The service also takes an exclusive OS lock on its library. Stop diagnostics
and all other camera apps before this start. The frame stream opens once.
A camera failure stops capture; the operator must fix it and restart the
service. It does not reconnect or take a new photo on its own.

`--initialize` is for the first setup only. Omit it on later starts. The service
requires `station-library` in the root and fails if the marker is absent. If
storage is on an external volume, check that volume is mounted before the first
initialization. Add a systemd mount dependency for that path before boot use.
Never initialize an absent mount path to get past the check.

To try the interface without USB hardware, replace the camera, camera-lock,
size, and fps arguments with `--demo`. This uses generated numbered pages and
shows **Synthetic camera**. Demo mode does not prove live capture.

In another local terminal, read the code:

```sh
cat RaspberryPi/results/library/pairing-code.txt
```

Open the configured HTTPS address in Safari. Enter the code within ten minutes.
The code permits up to eight paired phones, with five attempts per minute for
the station. A paired phone has access for 30 days. Restart creates a new code
and keeps valid phones. To revoke all phones, stop the service, start it once
with `--reset-pairing`, then omit that flag on later starts. This control is
local only. Tokens are in Secure, HttpOnly, SameSite cookies, not in URLs.
Pairing data and scan folders are private to the service user.

## Use the phone

1. Tap **Take control**. Create or select a document.
2. Check the live image. Open **Manual crop** if needed. Set left, top, width,
   and height as percentages of the original. The gold rectangle shows the crop.
3. Keep the page still. Tap **Capture page** once. Wait for **Saved — turn the
   page**. This means the image files and session manifest have been saved.
4. Open **Review**. Select a page. Rotate it, move it, or remove it. **Undo removal**
   restores the most recent removed page, including after a service restart.
   Removal keeps all image files. **Show original for crop** permits a new crop.
5. Tap **Prepare PDF**, then **Download PDF** when the job is complete. Use
   Safari's download/share controls to save it. PDFs contain the current page
   order and rotations. PDF image resolution is set to 150 dpi.
6. Tap **Pause** before leaving the station. It releases control. The physical
   camera stream stays open for previews; this phase has no automatic capture.

Only one phone can change a document. Another paired phone can view it and can
explicitly take control. Control expires after five seconds without a heartbeat.
After a disconnect or background pause, take control again. A save or PDF job
already accepted can finish; no new capture follows it. Browser retries use
the same saved command ID. If a connection fails, use **Check pending command**.
Do not start another capture until its result is known. The browser keeps one
pending request locally; do not clear website data until it is resolved.

## Storage and recovery

The Swift coordinator alone changes sessions. It uses the existing ScannerCore
operations and `Sessions/<UUID>/session.json`, `Originals/`, and `Pages/` layout.
The Pi journal, revisions, removed-page undo, and command results are sidecars
in `station.json` and `Jobs/`. No required fields are added to Mac manifests.
Originals and previous crop files are retained. Export copies are in the job
folder. The service never deletes a page image to free space.

Before a manifest change, the coordinator saves a commit record and syncs it.
It syncs image files and their folders before the manifest and its folder. A
restart completes a recorded manifest commit. An image job that stopped before
that record becomes **interrupted**; it is not replayed. Check the document,
then issue a new capture if needed. Orphan image files can remain after a failed
job. Keep them for recovery. Do not edit or remove the journal while the service
runs. Storage errors stop the coordinator so it cannot acknowledge an unsafe save.

The service reserves 512 MiB and requires another 128 MiB before a new command.
PDF export checks this reserve before each page. A failed export removes only
its incomplete PDF. The current limits are 500 pages per document and 10,000
saved command IDs per library. It refuses new commands at the journal limit;
it does not evict IDs and risk replaying a capture. A journal rotation tool is
not part of this phase. Large libraries and long-run memory use need Pi tests.

For a backup, stop the service and copy the complete library, including marker,
journal, jobs, manifests, and images. Keep a separate copy of TLS files. Restore
into a private folder owned by the service user, then start without
`--initialize`. For a Mac session transfer, copy the full session folder,
including image folders, while the Pi service is stopped. Open it in the Mac
app and check it before use. Do not run both apps against one mounted library.
Native Mac opening of a Pi session still needs a manual acceptance check.

## Start at boot

First validate foreground use. Install a clean checkout under
`/opt/foliobruma-scanner`, build the release coordinator, and create the venv
there. Create a dedicated system user and private data folders:

```sh
sudo useradd --system --user-group --home-dir /var/lib/foliobruma-scanner --create-home --groups video foliobruma
sudo install -d -o foliobruma -g foliobruma -m 700 /var/lib/foliobruma-scanner/library /var/lib/foliobruma-scanner/tls
sudo install -o root -g root -m 644 RaspberryPi/Packaging/foliobruma-station.service /etc/systemd/system/
sudo install -o root -g root -m 600 RaspberryPi/Packaging/station.conf.example /etc/foliobruma-station.conf
```

Copy the tested TLS certificate and key into the private TLS folder, owned by
`foliobruma` with mode `600`. Edit `/etc/foliobruma-station.conf` for the actual
address, camera path, mode, and file paths. Keep the application checkout owned
by the administrator; the service user needs read/execute access only.

Initialize the real library once, after checking its mount, then close stdin:

```sh
sudo -u foliobruma /opt/foliobruma-scanner/RaspberryPi/.build/release/ScannerStation /var/lib/foliobruma-scanner/library --initialize </dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now foliobruma-station
sudo systemctl status foliobruma-station
sudo -u foliobruma cat /var/lib/foliobruma-scanner/library/pairing-code.txt
```

The unit supplies the common camera lock under `/run/foliobruma`. It waits for
the network and requires the library marker. Check restart, missing mount,
certificate renewal, and power loss on the Pi before unattended use. The
systemd unit has not been run on this Mac. Label-printer access is not enabled.

## Design and validation

Hummingbird was a candidate in the plan. This phase uses
[aiohttp](https://docs.aiohttp.org/en/stable/web_advanced.html) for its established
HTTP/TLS implementation and [Pillow](https://pillow.readthedocs.io/en/stable/handbook/image-file-formats.html#pdf)
for platform image/PDF work. This keeps a small device adapter and avoids adding
a remote Swift dependency tree. The private JSON-lines pipe is serial IPC,
not a custom network protocol. Document rules stay in ScannerCore, called by
the Swift coordinator. The web client never edits a manifest.

FFmpeg opens one V4L2 MJPG stream at the configured size and rate. Each decoded
JPEG must match the size. The adapter keeps one latest original frame and one
small preview; a manual command freezes the current frame. Review work has a
single image conversion slot. Image/PDF work runs off the HTTP event loop.
There is one durable processing job at a time. This is a plain HTTPS website,
not an App Store app or an offline PWA. It needs the local station connection.

Automated checks use temporary libraries and real local HTTPS. See
[the phase 1 result record](PHASE1-RESULTS.md) for evidence and remaining gates.
Before hardware acceptance, check 20 non-private pages on the Pi, restart during
capture/export, keep/reorder/crop/undo, reconnect and take over from a second
phone, background Safari, download and read the PDF on the iPhone, and transfer
one synthetic session to the Mac. Confirm no extra page after disconnect.
Check that the actual negotiated camera frame rate matches phase 0; this service
checks dimensions but does not measure the live USB frame rate. Then measure
preview delay, save time, RAM, CPU, temperature, and free disk space.
