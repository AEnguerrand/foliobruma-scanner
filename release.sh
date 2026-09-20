#!/bin/zsh
# Build release files without an Apple account or distribution certificate.
set -euo pipefail
cd "${0:A:h}"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)}"
if (( $# > 1 )) || [[ ! "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  print -u2 'Usage: ./release.sh [X.Y.Z]'
  exit 1
fi
export RELEASE_VERSION="$VERSION"
./build.sh
APP="$PWD/build/Foliobruma Scanner.app"
OUTPUT="$PWD/build/release/$VERSION"
NAME="Foliobruma-Scanner-$VERSION-macOS-arm64"
mkdir -p "$OUTPUT"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/foliobruma-release.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
codesign --verify --deep --strict "$APP"
[[ "$(lipo -archs "$APP/Contents/MacOS/FoliobrumaScanner")" == arm64 ]]
ditto "$APP" "$STAGING/Foliobruma Scanner.app"
ln -s /Applications "$STAGING/Applications"
cp LICENSE "$STAGING/LICENSE.txt"
cp RELEASE-INSTALL.txt "$STAGING/READ-ME-FIRST.txt"
hdiutil create -volname 'Foliobruma Scanner' -srcfolder "$STAGING" \
  -format UDZO -ov "$OUTPUT/$NAME.dmg"
hdiutil verify "$OUTPUT/$NAME.dmg"
# Use a ZIP to retain bundle permissions and macOS metadata.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT/$NAME.zip"
cp RELEASE-INSTALL.txt "$OUTPUT/READ-ME-FIRST.txt"
cp LICENSE "$OUTPUT/LICENSE.txt"
(cd "$OUTPUT" && shasum -a 256 "$NAME.dmg" "$NAME.zip" READ-ME-FIRST.txt LICENSE.txt > SHA256SUMS.txt)
print "Release files: $OUTPUT"
