#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build --package-path RaspberryPi --product ScannerStation
"${PI_PYTHON:-python3}" -m unittest discover -s RaspberryPi/Tests -p test_station.py -v
