#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
mkdir -p build/core
xcrun swiftc -sdk "$SDK_PATH" -target arm64-apple-macosx14.0 \
  -parse-as-library -swift-version 5 -O \
  -emit-library -static -emit-module -module-name ScannerCore \
  -emit-module-path build/core/ScannerCore.swiftmodule \
  Sources/ScannerCore/*.swift -o build/core/libScannerCore.a
