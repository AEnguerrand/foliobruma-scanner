#!/usr/bin/env python3
"""Phase 0 only: local device tests, with separate evidence for each step."""
import argparse
import datetime
import fcntl
import http.server
import ipaddress
import json
import math
import os
from pathlib import Path
import platform
import re
import signal
import ssl
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PI = ROOT / "RaspberryPi"
PAYLOAD = "https://example.com/pi-test"


def execute(command, timeout=60, stdin=None):
    process = subprocess.Popen([str(x) for x in command], stdin=stdin, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, start_new_session=True)
    try:
        output, _ = process.communicate(timeout=timeout)
    except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        output, _ = process.communicate()
        if isinstance(error, KeyboardInterrupt):
            raise
        return 124, output.decode(errors="replace") + "\nTIMEOUT\n"
    return process.returncode, output.decode(errors="replace")


def jpeg_size(data):
    if data[:2] != b"\xff\xd8":
        raise ValueError("Capture is not a JPEG")
    offset = 2
    while offset < len(data):
        if data[offset] != 255:
            raise ValueError("Invalid JPEG marker")
        while offset < len(data) and data[offset] == 255:
            offset += 1
        if offset >= len(data):
            break
        marker = data[offset]
        offset += 1
        if marker in (0xd9, 0xda):
            break
        if marker == 0x01 or 0xd0 <= marker <= 0xd7:
            continue
        if offset + 2 > len(data):
            break
        length = struct.unpack(">H", data[offset:offset + 2])[0]
        if length < 2 or offset + length > len(data):
            break
        if marker in (0xc0, 0xc1, 0xc2):
            if length < 8:
                break
            height, width = struct.unpack(">HH", data[offset + 3:offset + 7])
            if not width or not height:
                break
            return width, height
        offset += length
    raise ValueError("JPEG dimensions are missing")


def verify_mode(text, width, height, fps):
    if width <= 0 or height <= 0 or not math.isfinite(fps) or fps <= 0:
        raise ValueError("Use positive dimensions and a finite positive frame rate")
    dimensions = re.search(r"Width/Height\s*:\s*(\d+)\s*/\s*(\d+)", text)
    rate = re.search(r"Frames per second\s*:\s*([0-9.]+)", text)
    if not dimensions or tuple(map(int, dimensions.groups())) != (width, height):
        raise ValueError("Camera changed the requested dimensions")
    if not re.search(r"Pixel Format\s*:\s*'MJPG'", text):
        raise ValueError("Camera did not select MJPG")
    if not rate or abs(float(rate[1]) - fps) > 0.05:
        raise ValueError("Camera changed the requested frame rate")


class Report:
    def __init__(self, folder):
        self.folder = Path(folder).resolve()
        self.folder.mkdir(mode=0o700, parents=False, exist_ok=False)
        if (ROOT / ".git").exists():
            head_code, head = execute(["git", "-C", ROOT, "rev-parse", "HEAD"])
            dirty_code, dirty = execute(["git", "-C", ROOT, "status", "--porcelain"])
            if head_code or dirty_code:
                raise RuntimeError("Cannot read the source revision and worktree state")
        else:
            head = (PI / "SOURCE_HEAD").read_text()
            dirty = "archive; compare archive SHA-256 before use"
        self.data = {"schema": 1, "created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                     "source_head": head.strip(), "source_changes": dirty.strip(),
                     "system": platform.platform(), "machine": platform.machine(), "steps": {},
                     "manual": {"camera_focus_and_edges": "not-run", "physical_label_and_cut_mm": "not-run",
                                "iphone_qr_payload": "not-run", "iphone_trusted_https": "not-run",
                                "power_supply_and_usb_resets": "not-run"}}
        self.save()

    def save(self):
        temp = self.folder / ".report.tmp"
        with temp.open("w") as stream:
            json.dump(self.data, stream, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        temp.replace(self.folder / "report.json")

    def run(self, name, command, timeout=60, required=True, stdin=None):
        code, output = execute(command, timeout, stdin)
        (self.folder / (name + ".log")).write_text(output)
        self.data["steps"][name] = {"command": list(map(str, command)), "exit_code": code,
                                    "result": "pass" if code == 0 else "fail" if required else "unavailable"}
        self.save()
        if code and required:
            raise RuntimeError(f"{name} failed ({code}). Read {name}.log")
        return output


def inventory(report, args):
    for name, command in [
        ("os", ["cat", "/etc/os-release"]), ("kernel", ["uname", "-a"]),
        ("usb", ["lsusb"]), ("usb-tree", ["lsusb", "-t"]),
        ("camera-list", ["v4l2-ctl", "--list-devices"]),
        ("swift-version", ["swift", "--version"]),
        ("packages", ["dpkg-query", "-W", "v4l-utils", "libusb-1.0-0", "libqrencode4", "python3", "openssl"]),
        ("python-tls", ["python3", "-c", "import sys,ssl; print(sys.version); print(ssl.OPENSSL_VERSION)"]),
        ("disk", ["df", "-h", str(report.folder)]),
        ("memory", ["free", "-h"]),
        ("thermal", ["sh", "-c", "cat /sys/class/thermal/thermal_zone*/temp"]),
        ("kernel-log", ["journalctl", "-k", "-b", "--no-pager", "-n", "200"]),
        ("power", ["vcgencmd", "get_throttled"]),
    ]:
        try:
            report.run(name, command, required=False)
        except FileNotFoundError as error:
            report.data["steps"][name] = {"result": "unavailable", "error": str(error)}
            report.save()
    if args.device:
        report.run("camera-modes", ["v4l2-ctl", "-d", args.device, "--list-formats-ext"])
        report.run("camera-controls", ["v4l2-ctl", "-d", args.device, "--all", "--list-ctrls-menus"])
    if args.core:
        if platform.machine() != "aarch64" or platform.system() != "Linux":
            raise RuntimeError("The ARM64 gate needs Linux aarch64")
        os_release = platform.freedesktop_os_release()
        if os_release.get("ID") != "ubuntu" or os_release.get("VERSION_ID") != "24.04":
            raise RuntimeError("Phase 0 requires Ubuntu 24.04")
        version = report.run("arm64-toolchain", ["swift", "--version"])
        if not re.search(r"Swift version 6\.0\.3\b", version):
            raise RuntimeError("Phase 0 requires Swift 6.0.3")
        report.run("arm64-core", ["swift", "run", "--package-path", ROOT, "ScannerCoreChecks"], 600)
        report.run("arm64-label-build", ["swift", "build", "--package-path", PI], 600)


def camera(report, args):
    if not args.device.startswith("/dev/v4l/by-id/"):
        raise ValueError("Use a stable /dev/v4l/by-id/ device path")
    report.data["requested_camera"] = vars(args).copy()
    report.save()
    base = ["v4l2-ctl", "-d", args.device]
    report.run("camera-modes", base + ["--list-formats-ext"])
    report.run("camera-set", base + [f"--set-fmt-video=width={args.width},height={args.height},pixelformat=MJPG",
                                      f"--set-parm={args.fps}"])
    selected = report.run("camera-selected", base + ["--get-fmt-video", "--get-parm"])
    verify_mode(selected, args.width, args.height, args.fps)
    photo = report.folder / "synthetic-page.jpg"
    # Keep the negotiated mode and stream in the same open operation. Check it again after capture.
    captured = report.run("camera-capture", base + ["--get-fmt-video", "--get-parm", "--stream-mmap=4",
                          "--stream-skip=10", "--stream-count=1", f"--stream-to={photo}"], 60)
    verify_mode(captured, args.width, args.height, args.fps)
    dimensions = jpeg_size(photo.read_bytes())
    if dimensions != (args.width, args.height):
        raise ValueError(f"JPEG dimensions changed: {dimensions}")
    report.data["captured_dimensions"] = dimensions
    report.save()


def label(report, args):
    helper = PI / "build" / "ql600-probe"
    report.run("printer-status", [helper, "--status"])
    matrix = report.run("qr-matrix", [PI / "build" / "qr-matrix"])
    (report.folder / "matrix.txt").write_text(matrix)
    report.run("label-raster", [PI / ".build/debug/DiagnosticLabel", report.folder / "matrix.txt",
                               report.folder / "label.raster"])
    report.data["label"] = {"payload": PAYLOAD, "transport": "not-sent", "manual_print_requested": args.print_test}
    report.save()
    if args.print_test:
        # Write intent before a process can send print bytes. Never retry automatically.
        with (report.folder / "print-attempt.json").open("x") as stream:
            json.dump({"state": "pending-check-physical-label", "payload": PAYLOAD}, stream)
            stream.flush()
            os.fsync(stream.fileno())
        report.data["label"]["transport"] = "pending-check-physical-label"
        report.save()
        with (report.folder / "label.raster").open("rb") as stream:
            report.run("printer-transfer", [helper, "--print-test"], 90, stdin=stream)
        report.data["label"]["transport"] = "completion-and-ready-received"
        report.save()


def certificates(args):
    folder = Path(args.output).resolve()
    folder.mkdir(mode=0o700, exist_ok=False)
    address = str(ipaddress.IPv4Address(args.ip))
    commands = [
        ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "7", "-sha256",
         "-keyout", folder / "ca.key", "-out", folder / "ca.crt", "-subj", "/CN=Foliobruma phase 0 test CA",
         "-addext", "basicConstraints=critical,CA:TRUE,pathlen:0", "-addext", "keyUsage=critical,keyCertSign,cRLSign"],
        ["openssl", "req", "-newkey", "rsa:2048", "-nodes", "-keyout", folder / "server.key",
         "-out", folder / "server.csr", "-subj", "/CN=scanner.local"],
        ["openssl", "x509", "-req", "-in", folder / "server.csr", "-CA", folder / "ca.crt",
         "-CAkey", folder / "ca.key", "-CAcreateserial", "-days", "7", "-sha256",
         "-extfile", folder / "server.ext", "-out", folder / "server.crt"],
        ["openssl", "x509", "-in", folder / "ca.crt", "-outform", "DER", "-out", folder / "ca.cer"],
    ]
    (folder / "server.ext").write_text(f"subjectAltName=DNS:scanner.local,IP:{address}\nbasicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\n")
    for command in commands:
        code, output = execute(command)
        if code:
            raise RuntimeError(output)
    for key in folder.glob("*.key"):
        key.chmod(0o600)
    code, output = execute(["openssl", "x509", "-in", folder / "ca.crt", "-noout", "-fingerprint", "-sha256"])
    if code:
        raise RuntimeError(output)
    print(output.strip())
    print(f"Transfer only {folder / 'ca.cer'} to the iPhone. Never transfer the keys.")


class TestPage(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/":
            self.send_error(404)
            return
        page = (PI / "Web/index.html").read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(page)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'")
        self.end_headers()
        self.wfile.write(page)

    def log_message(self, format, *args):
        print("HTTPS request received", flush=True)


def serve(args):
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(str(Path(args.tls) / "server.crt"), str(Path(args.tls) / "server.key"))
    server = http.server.ThreadingHTTPServer((args.bind, args.port), TestPage)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    print(f"Phase 0 HTTPS page on port {args.port}. Stop with Ctrl-C. No device controls.", flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    for action in ("inventory", "camera", "label"):
        command = commands.add_parser(action)
        command.add_argument("--output", required=True, help="New output directory; parent must exist")
        if action in ("inventory", "camera"):
            command.add_argument("--device", required=action == "camera")
        if action == "inventory":
            command.add_argument("--core", action="store_true", help="Run the real Linux ARM64 shared-core gate")
        elif action == "camera":
            command.add_argument("--width", type=int, required=True)
            command.add_argument("--height", type=int, required=True)
            command.add_argument("--fps", type=float, required=True)
        else:
            command.add_argument("--print-test", action="store_true", help="Print and cut ONE synthetic test label")
    command = commands.add_parser("tls")
    command.add_argument("--output", required=True)
    command.add_argument("--ip", required=True, help="Pi LAN IPv4 address")
    command = commands.add_parser("serve")
    command.add_argument("--tls", required=True)
    command.add_argument("--bind", default="127.0.0.1", help="Use the Pi LAN IPv4 address for an iPhone test")
    command.add_argument("--port", type=int, default=8443)
    args = parser.parse_args()
    if args.action == "tls":
        certificates(args)
    elif args.action == "serve":
        serve(args)
    else:
        # Serialize diagnostics for this user. Do not install a station service in phase 0.
        lock_path = Path.home() / ".foliobruma-pi-diagnostics.lock"
        with lock_path.open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            report = Report(args.output)
            try:
                globals()[args.action](report, args)
                report.data["command_result"] = "pass"
            except (Exception, KeyboardInterrupt) as error:
                report.data["command_result"] = "fail"
                report.data["error"] = str(error) or "Interrupted by operator"
                raise
            finally:
                report.save()
                print(f"Report: {report.folder / 'report.json'}")


if __name__ == "__main__":
    try:
        main()
    except (Exception, KeyboardInterrupt) as error:
        print(f"Stopped: {error}", file=sys.stderr)
        sys.exit(1)
