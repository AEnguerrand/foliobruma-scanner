#!/bin/sh
set -eu
pi_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
exec "${STATION_PYTHON:?}" "$pi_dir/Service/station.py" \
  --coordinator "$pi_dir/.build/release/ScannerStation" \
  --library "${STATION_LIBRARY:?}" --bind "${STATION_BIND:?}" \
  --origin "${STATION_ORIGIN:?}" --certificate "${STATION_CERT:?}" --key "${STATION_KEY:?}" \
  --camera "${STATION_CAMERA:?}" --camera-lock /run/foliobruma/camera.lock \
  --size "${STATION_SIZE:?}" --fps "${STATION_FPS:?}"
