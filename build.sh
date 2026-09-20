#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
SOURCES=(Sources/FoliobrumaScanner/**/*.swift)
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
APP="$PWD/build/Foliobruma Scanner.app"
mkdir -p "$APP/Contents/MacOS"
xcrun swiftc \
  -sdk "$SDK_PATH" \
  -target arm64-apple-macosx14.0 \
  -parse-as-library -swift-version 5 \
  -O -framework SwiftUI -framework AppKit -framework AVFoundation \
  -framework Vision -framework PDFKit -framework CoreImage \
  "${SOURCES[@]}" -o "$APP/Contents/MacOS/FoliobrumaScanner"
cp Resources/Info.plist "$APP/Contents/Info.plist"
xattr -dr com.apple.FinderInfo "$APP" 2>/dev/null || true
codesign --force --sign - --identifier org.sovenelia.scanner "$APP"
printf '%s\n' "$APP"
