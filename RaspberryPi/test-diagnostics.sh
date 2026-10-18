#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m unittest discover -s RaspberryPi/Tests -p 'test_diagnostics.py'
swift build --package-path RaspberryPi
mkdir -p RaspberryPi/build
cc -std=c11 -Wall -Wextra -Werror RaspberryPi/Diagnostics/ql600-probe.c RaspberryPi/Tests/mock-usb.c \
  $(pkg-config --cflags libusb-1.0) -o RaspberryPi/build/mock-probe
python3 RaspberryPi/Tests/check-raster.py
