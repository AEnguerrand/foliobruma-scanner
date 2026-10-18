#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build --package-path RaspberryPi -c release --product ScannerStation
