#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
SOURCES=(Sources/FoliobrumaScanner/**/*.swift)
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
mkdir -p build/tests
mkdir -p build
xcrun clang -isysroot "$SDK_PATH" -target arm64-apple-macosx14.0 -O2 -c Sources/PrinterUSB/QL600USB.c -o build/QL600USB.o
xcrun swiftc \
  -sdk "$SDK_PATH" \
  -target arm64-apple-macosx14.0 \
  -parse-as-library -swift-version 5 \
  -D SCANNER_TESTS -framework SwiftUI -framework AppKit -framework AVFoundation \
  -framework Vision -framework PDFKit -framework CoreImage \
  -framework IOKit -import-objc-header Sources/PrinterUSB/QL600USB.h build/QL600USB.o \
  "${SOURCES[@]}" Tests/*.swift -o build/tests/session-tests
build/tests/session-tests
