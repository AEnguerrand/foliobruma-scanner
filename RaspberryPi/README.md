# Raspberry Pi phase 0 diagnostics

This package tests the proposed Pi station. It is not a Pi app release.
The Mac app and its build remain separate. The package does not open a scan
library, upload files, or install a background service.

Use a Raspberry Pi 5 with 4 GB RAM, the official 27 W supply, a fan, and
Ubuntu Server 24.04 LTS ARM64. Connect one USB document camera and one Brother
QL-600 with 62 mm continuous DK-22205 tape. Use a blank or synthetic page.
The camera test currently accepts MJPG only. A camera with no suitable MJPG
mode needs more adapter work; do not select a lower mode to mark a test passed.

## 1. Install tools

Install Ubuntu updates, then install these packages:

```sh
sudo apt-get update
sudo apt-get install build-essential pkg-config git python3 openssl usbutils v4l-utils libusb-1.0-0-dev libqrencode-dev
```

Install **Swift 6.0.3 for Ubuntu 24.04, aarch64** from the
[official Swift download page](https://www.swift.org/install/linux/ubuntu/24_04/).
Use the matching signature and the Swift verification instructions. Do not
substitute the x86_64 archive. Put the toolchain `usr/bin` directory in `PATH`.
Confirm that `swift --version` reports 6.0.3 and an aarch64 Linux target.
The `inventory --core` command checks the OS, CPU architecture, and Swift version.

Use a clean checkout of the diagnostic PR, or extract the source archive. Run
all commands below from its root. The archive includes `ScannerCore` source;
it needs no GitHub access after download. The build has no remote Swift packages.
Ubuntu package revisions can change. The report records installed versions.
Keep those results with the OS image name and image checksum for a repeat test.
A fully pinned OS image is an output of phase 0, after the hardware run.

```sh
./RaspberryPi/build-diagnostics.sh
./RaspberryPi/test-diagnostics.sh
mkdir -p RaspberryPi/results
python3 RaspberryPi/Diagnostics/diagnose.py inventory --core --output RaspberryPi/results/baseline
ls -l /dev/v4l/by-id/
```

Do not run diagnostics as root. Camera access usually needs the `video` group.
If access is denied, an administrator can add the test user to that group;
log out and back in. Check device permissions before you change them.

The USB helper does not detach a kernel driver or take a printer from CUPS.
Stop competing print jobs before the test. If `usblp` owns the interface, record
that result; an administrator can temporarily unload it with `sudo modprobe -r
usblp`, then restore it with `sudo modprobe usblp` after the test. If USB access
is denied, an administrator can install the supplied rule:

```sh
sudo groupadd -f foliobruma
sudo usermod -aG video,foliobruma "$USER"
sudo cp RaspberryPi/Packaging/70-foliobruma-diagnostics.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

Log out and back in, then reconnect the printer. The rule gives only the
`foliobruma` group access to `04f9:20c0`. Do not use world-writable USB permissions.
After a temporary test, an administrator can remove this rule and reload the
rules. Record each system change in the report. No driver or permission changes
occur in the scripts.

## 2. Check the camera

Replace `CAMERA` with the exact stable device path. Some cameras have more than
one node. Use the node that lists video capture modes.

```sh
CAMERA=/dev/v4l/by-id/usb-REPLACE_WITH_YOUR_CAMERA-video-index0
python3 RaspberryPi/Diagnostics/diagnose.py inventory --device "$CAMERA" --output RaspberryPi/results/devices
```

Read `camera-modes.log`. Choose the intended full page MJPG size and a frame
rate that the camera lists for that size. The numbers below are examples:

```sh
python3 RaspberryPi/Diagnostics/diagnose.py camera --device "$CAMERA" --width 3840 --height 2160 --fps 15 --output RaspberryPi/results/camera-1
```

The command stops if the negotiated dimensions, MJPG format, or frame rate
changes. It skips ten frames, captures one JPEG, and checks its dimensions.
Inspect `synthetic-page.jpg` for focus, page edges, light, and distortion.
A software pass checks the mode and image dimensions. It does not prove useful
page quality, automatic capture, or sustained performance. This test changes
the camera mode and does not restore its previous mode.

## 3. Check the printer

First request status and prepare raster bytes without printing:

```sh
python3 RaspberryPi/Diagnostics/diagnose.py label --output RaspberryPi/results/label-dry
```

Then request **one** print and cut:

```sh
python3 RaspberryPi/Diagnostics/diagnose.py label --print-test --output RaspberryPi/results/label-print-1
```

The QR contains `https://example.com/pi-test`. QR creation is local. The package
makes no request to that address. Use the iPhone camera to read the QR payload;
there is no need to open the link. Record the exact payload and the measured cut
length. The image area is 696 × 225 dots at 300 dpi, with the shared encoder's
35-dot feed margin. The expected physical label is about 62 × 25 mm; measure it.

Before print bytes are sent, the USB helper checks the current printer status,
error flags, roll width, media type, and phase. It records raw status packets
and transferred byte counts. Success needs both completion and ready status.
This is transport evidence. Inspect the label and cut even after success.

Each command requires a new output folder. A print command saves pending intent
before it starts the transport. A timeout, disconnect, or interrupted process
can leave a label printed. **Check the physical label before another command.**
There is no automatic retry. Keep the failed report and record the operator's
decision before a manual retry in a new folder. The pending record is a diagnostic
record, not a production label history or a session schema change.

## 4. Test the iPhone connection

Connect the Pi and iPhone to the same trusted LAN. Guest Wi-Fi can block peers.
Get the Pi LAN IPv4 address with `hostname -I`. Replace the example below:

```sh
python3 RaspberryPi/Diagnostics/diagnose.py tls --ip 192.168.1.50 --output RaspberryPi/tls
python3 RaspberryPi/Diagnostics/diagnose.py serve --tls RaspberryPi/tls --bind 192.168.1.50
```

The command creates a test CA and a server certificate valid for seven days.
The certificate covers `scanner.local` and the supplied IPv4 address. The page
is the only served path. Keys, images, reports, and library files are not served.
This short-lived test server uses the Python standard library. It is not the
production station API and provides no pairing or device controls.

1. Copy only `RaspberryPi/tls/ca.cer` to your Mac through SSH, then AirDrop it to
   the iPhone. Compare its SHA-256 certificate fingerprint with the Pi output.
2. Install the certificate profile in iPhone Settings. Then use **General →
   About → Certificate Trust Settings** to enable full trust for this test CA.
   Follow the [Apple certificate trust instructions](https://support.apple.com/en-us/102390).
   A managed phone can block this step; record a failed step if it does.
3. Open `https://192.168.1.50:8443/` in Safari. Record the address and iOS version.
   There must be no certificate warning. Close Safari, reopen it, and test again.
   Test `https://scanner.local:8443/` only if local name resolution is configured.
   The package does not install mDNS. The IP address is the baseline test.
4. Stop the server with Ctrl-C. Remove the test CA profile and trust from the
   iPhone after the test. Delete the local TLS folder when no more tests need it.
   Never share the CA or server private keys.

If Ubuntu Firewall is active, an administrator must permit TCP 8443 from the
local subnet for this test, then remove that rule. Do not expose the test server
to the internet. No router changes or cloud services are required.

## 5. Record the gate result

Copy [REPORT.md](REPORT.md) to a private test record. Link the output folders.
Each `report.json` records source, host, command results, logs, and manual checks
that start as `not-run`. A command pass is not a phase 0 pass. Missing tools and
blocked probes stay visible; read all steps, including optional inventory probes.
Use a second inventory run after the camera and print tests to compare kernel
USB errors, temperature, and available power information. Ubuntu might not have
`vcgencmd`; record the supply and any unavailable power fields manually.

Do not commit results, test captures, TLS files, or USB serial numbers. The default
output paths are ignored by Git. Review logs before you share them. There is no
upload command. The diagnostic tools never use the Mac session folder.

Phase 0 passes only with a real ARM64 shared-core run, a usable full page photo,
a physically checked label and cut, a correct QR read on the iPhone, and trusted
HTTPS on that iPhone. Record every failure. Fix hardware blockers before phase 1.

## Checks without a Pi

On a host with Swift, Python, a C compiler, pkg-config, and libusb headers, run:

```sh
./RaspberryPi/test-diagnostics.sh
```

This checks rejected camera mode changes, JPEG dimensions, failure reports,
print intent, timeout handling, a trusted loopback TLS request, denied file paths,
label raster geometry, and five simulated USB outcomes. It does not access USB.
The Linux CI job also builds the real C helpers and generates a QR matrix.
These checks do not prove ARM64 operation or hardware support.

To make a source package from a clean committed checkout:

```sh
./RaspberryPi/package-diagnostics.sh
```

The archive and SHA-256 file are under `RaspberryPi/build/`. They include the
source revision, this guide, and shared-core checks. They exclude the Mac app,
Git history, results, and keys. Keep the archive checksum with the report. The
archive is a test package, not a signed release.

Technical references: [V4L2 format negotiation](https://www.kernel.org/doc/html/latest/userspace-api/media/v4l/vidioc-g-fmt.html),
[libusb transfers](https://libusb.sourceforge.io/api-1.0/group__libusb__syncio.html),
[libqrencode](https://fukuchi.org/works/qrencode/manual/qrencode_8h.html), and the
[Brother QL-600 raster specification](https://download.brother.com/welcome/docp000698/cv_ql600710720_eng_raster_102.pdf).
