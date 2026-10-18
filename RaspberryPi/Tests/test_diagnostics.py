import importlib.util
from pathlib import Path
import ssl
import struct
import tempfile
import threading
import unittest
from unittest.mock import patch
import urllib.error
import urllib.request
from types import SimpleNamespace

spec = importlib.util.spec_from_file_location("diagnose", Path(__file__).parents[1] / "Diagnostics/diagnose.py")
diag = importlib.util.module_from_spec(spec)
spec.loader.exec_module(diag)


class DiagnosticsTests(unittest.TestCase):
    def test_camera_mode_must_match_all_requested_values(self):
        mode = "Width/Height : 3840/2160\nPixel Format : 'MJPG'\nFrames per second: 15.000 (15/1)"
        diag.verify_mode(mode, 3840, 2160, 15)
        for changed in (mode.replace("3840", "1920"), mode.replace("MJPG", "YUYV"),
                        mode.replace("15.000", "30.000"), ""):
            with self.assertRaises(ValueError):
                diag.verify_mode(changed, 3840, 2160, 15)

    def test_interruption_stops_the_child_process_group(self):
        with patch.object(diag.subprocess, "Popen") as spawn, patch.object(diag.os, "killpg") as kill:
            spawn.return_value.pid = 12345
            spawn.return_value.communicate.side_effect = [KeyboardInterrupt(), (b"", None)]
            with self.assertRaises(KeyboardInterrupt):
                diag.execute(["test-command"])
            kill.assert_called_once_with(12345, diag.signal.SIGKILL)

    def test_jpeg_dimensions_and_bad_data(self):
        frame = b"\xff\xd8\xff\xe0\x00\x04ab\xff\xc0\x00\x0b\x08" + struct.pack(">HH", 2160, 3840) + b"\x01\x01\x11\x00"
        self.assertEqual(diag.jpeg_size(frame), (3840, 2160))
        for data in (b"", b"not a jpeg", frame[:14], b"\xff\xd8\xff\xc0\x00\x00"):
            with self.assertRaises(ValueError):
                diag.jpeg_size(data)

    def test_failed_step_is_saved_and_existing_output_is_refused(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(diag, "execute", return_value=(0, "test-source")):
            output = Path(folder) / "new"
            report = diag.Report(output)
            with patch.object(diag, "execute", return_value=(1, "failure")), self.assertRaises(RuntimeError):
                report.run("probe", ["probe"])
            self.assertIn('"result": "fail"', (output / "report.json").read_text())
            self.assertEqual((output / "probe.log").read_text(), "failure")
            with self.assertRaises(FileExistsError):
                diag.Report(output)

    def test_archive_report_uses_embedded_revision_without_git(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            pi = root / "RaspberryPi"
            pi.mkdir()
            (pi / "SOURCE_HEAD").write_text("a" * 40 + "\n")
            with patch.object(diag, "ROOT", root), patch.object(diag, "PI", pi):
                report = diag.Report(root / "report")
            self.assertEqual(report.data["source_head"], "a" * 40)
            self.assertIn("archive", report.data["source_changes"])

    def test_print_intent_survives_transport_failure_and_no_retry_occurs(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder)
            class FakeReport:
                data = {}
                def __init__(self):
                    self.folder = output
                    self.calls = []
                def save(self):
                    pass
                def run(self, name, *args, **kwargs):
                    self.calls.append(name)
                    if name == "qr-matrix":
                        return ("0" * 21 + "\n") * 21
                    if name == "label-raster":
                        (output / "label.raster").write_bytes(b"test")
                    if name == "printer-transfer":
                        raise RuntimeError("USB disconnected")
                    return ""
            report = FakeReport()
            with self.assertRaises(RuntimeError):
                diag.label(report, SimpleNamespace(print_test=True))
            self.assertEqual(report.data["label"]["transport"], "pending-check-physical-label")
            self.assertTrue((output / "print-attempt.json").is_file())
            self.assertEqual(report.calls.count("printer-transfer"), 1)

    def test_timeout_is_reported(self):
        code, output = diag.execute(["python3", "-c", "import time; time.sleep(10)"], timeout=.05)
        self.assertEqual(code, 124)
        self.assertIn("TIMEOUT", output)

    def test_https_validates_ip_and_serves_only_the_test_page(self):
        with tempfile.TemporaryDirectory() as folder:
            tls = Path(folder) / "tls"
            diag.certificates(SimpleNamespace(output=tls, ip="127.0.0.1"))
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(tls / "server.crt", tls / "server.key")
            server = diag.http.server.ThreadingHTTPServer(("127.0.0.1", 0), diag.TestPage)
            server.socket = context.wrap_socket(server.socket, server_side=True)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                client = ssl.create_default_context(cafile=str(tls / "ca.crt"))
                address = f"https://127.0.0.1:{server.server_port}"
                with urllib.request.urlopen(address, context=client) as response:
                    self.assertIn(b"Foliobruma Pi test", response.read())
                for path in ("/ca.key", "/report.json", "/../", "/?test"):
                    with self.assertRaises(urllib.error.HTTPError) as raised:
                        urllib.request.urlopen(address + path, context=client)
                    self.assertEqual(raised.exception.code, 404)
                    raised.exception.close()
            finally:
                server.shutdown()
                server.server_close()
                thread.join()


if __name__ == "__main__":
    unittest.main()
