#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
SOURCES=(Sources/FoliobrumaScanner/**/*.swift)
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
APP="$PWD/build/Foliobruma Scanner.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ICONSET="$PWD/build/AppIcon.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" Resources/Brand/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  RETINA_SIZE=$((SIZE * 2))
  sips -z "$RETINA_SIZE" "$RETINA_SIZE" Resources/Brand/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cp Resources/Brand/AppIcon.png "$APP/Contents/Resources/ScannerIcon.png"
xcrun swiftc \
  -sdk "$SDK_PATH" \
  -target arm64-apple-macosx14.0 \
  -parse-as-library -swift-version 5 \
  -O -framework SwiftUI -framework AppKit -framework AVFoundation \
  -framework Vision -framework PDFKit -framework CoreImage \
  "${SOURCES[@]}" -o "$APP/Contents/MacOS/FoliobrumaScanner"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -n "${RELEASE_VERSION:-}" ]]; then
  if [[ ! "$RELEASE_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    print -u2 'RELEASE_VERSION must use X.Y.Z.'
    exit 1
  fi
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $RELEASE_VERSION" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $RELEASE_VERSION" "$APP/Contents/Info.plist"
fi
xattr -dr com.apple.FinderInfo "$APP" 2>/dev/null || true
codesign --force --sign - --identifier org.sovenelia.scanner "$APP"
printf '%s\n' "$APP"
