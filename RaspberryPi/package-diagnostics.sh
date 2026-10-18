#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -n "$(git status --porcelain)" ]; then
  echo 'Commit the source before packaging.' >&2
  exit 1
fi
revision=$(git rev-parse HEAD)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p RaspberryPi/build
git archive HEAD Package.swift Sources/ScannerCore Tests/ScannerCore RaspberryPi LICENSE | tar -xf - -C "$stage"
printf '%s\n' "$revision" > "$stage/RaspberryPi/SOURCE_HEAD"
archive="$PWD/RaspberryPi/build/foliobruma-pi-phase0-$revision.tar.gz"
tar -czf "$archive" -C "$stage" .
python3 - "$archive" <<'PYHASH'
import hashlib
from pathlib import Path
import sys
archive = Path(sys.argv[1])
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
Path(str(archive) + ".sha256").write_text(f"{checksum}  {archive.name}\n")
PYHASH
printf '%s\n' "$archive"
