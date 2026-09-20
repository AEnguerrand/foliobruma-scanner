#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
APP="$PWD/build/Foliobruma Scanner.app"
mkdir -p "$APP/Contents/MacOS"
xcrun swiftc -sdk "$SDK_PATH" -target arm64-apple-macosx14.0 -parse-as-library -swift-version 5 -O -framework SwiftUI -framework AppKit -framework AVFoundation -framework Vision -framework PDFKit -framework CoreImage Sources/Scanner.swift -o "$APP/Contents/MacOS/FoliobrumaScanner"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>FoliobrumaScanner</string><key>CFBundleIdentifier</key><string>org.sovenelia.scanner</string><key>CFBundleName</key><string>Foliobruma Scanner</string><key>CFBundleDisplayName</key><string>Foliobruma Scanner</string><key>CFBundleVersion</key><string>1</string><key>CFBundleShortVersionString</key><string>0.1.0</string><key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>NSCameraUsageDescription</key><string>Scan your books and documents with the connected document camera. Images stay on your Mac.</string><key>NSHighResolutionCapable</key><true/></dict></plist>
PLIST
xattr -d com.apple.FinderInfo "$APP" 2>/dev/null || true
codesign --force --sign - --identifier org.sovenelia.scanner "$APP"
printf '%s\n' "$APP"
