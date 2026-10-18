"""Check shared raster output and USB failure gates with a mock transport."""
import os
from pathlib import Path
import subprocess
import tempfile

pi = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as folder:
    matrix = Path(folder) / "matrix.txt"
    raster = Path(folder) / "label.raster"
    matrix.write_text(("1" * 21 + "\n") * 21)
    cli = pi / ".build/debug/DiagnosticLabel"
    subprocess.run([cli, matrix, raster], check=True)
    data = raster.read_bytes()
    assert len(data) == 21162 and data[:200] == bytes(200) and data[-1] == 0x1a
    # Decode pin order. The module square is centred, with a four-module white border.
    for y in range(225):
        row = data[236 + y * 93:236 + (y + 1) * 93]
        assert row[:3] == bytes([0x67, 0, 90])
        for x in range(696):
            pin = 12 + 695 - x
            black = bool(row[3 + pin // 8] & (0x80 >> (pin % 8)))
            assert black == (295 <= x < 400 and 60 <= y < 165), (x, y)
    assert subprocess.run([cli, matrix, raster], capture_output=True).returncode != 0
    matrix.write_text("invalid")
    assert subprocess.run([cli, matrix, Path(folder) / "bad"], capture_output=True).returncode != 0
    for scenario, expected in (("ok", 0), ("roll", 1), ("timeout", 1), ("invalid", 1), ("partial", 2)):
        result = subprocess.run([pi / "build/mock-probe", "--print-test"], input=data,
                                capture_output=True, env={**os.environ, "MOCK_USB": scenario})
        assert result.returncode == expected, (scenario, result.stderr)
        if scenario in ("roll", "timeout", "invalid"):
            assert b"Print transfer started" not in result.stderr
        if scenario == "partial":
            assert b"uncertain-check-label" in result.stderr
        if scenario == "ok":
            assert b"Completion and ready received" in result.stderr
print("Raster geometry and five mock USB outcomes passed. No hardware used.")
