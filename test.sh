#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
mkdir -p build/tests
xcrun swiftc \
  -sdk "$SDK_PATH" \
  -target arm64-apple-macosx14.0 \
  -parse-as-library -swift-version 5 \
  -D SCANNER_TESTS -framework SwiftUI -framework AppKit -framework AVFoundation \
  -framework Vision -framework PDFKit -framework CoreImage \
  Sources/Scanner.swift Tests/SessionTests.swift -o build/tests/session-tests
build/tests/session-tests
