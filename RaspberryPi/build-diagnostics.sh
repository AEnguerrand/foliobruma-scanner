#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Host checks are useful, but only Linux aarch64 can pass the phase 0 ARM64 gate.
mkdir -p RaspberryPi/build
cc -std=c11 -Wall -Wextra -Werror RaspberryPi/Diagnostics/ql600-probe.c \
  $(pkg-config --cflags --libs libusb-1.0) -o RaspberryPi/build/ql600-probe
cc -std=c11 -Wall -Wextra -Werror RaspberryPi/Diagnostics/qr-matrix.c \
  $(pkg-config --cflags --libs libqrencode) -o RaspberryPi/build/qr-matrix
swift build --package-path RaspberryPi
