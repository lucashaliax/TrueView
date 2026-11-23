#!/bin/zsh
# Builds TrueView, installs it in /Applications, relaunches it and checks its resource use.
# Usage: ./build.sh                build, install, check
#        ./build.sh --zip          also write build/release/TrueView.zip for a GitHub release
#        ./build.sh --no-install   only build (prints where the app is)
# VERSION=0.0.1 ./build.sh --no-install builds an older-looking copy (for testing updates).
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${VERSION:-0.3}"
BUILD_NUMBER="${BUILD_NUMBER:-3}"
# Signed with the developer's team (not ad hoc) so the in-app updater can check that an
# update comes from the same developer.
SIGN_ID="${SIGN_ID:-Apple Development}"
# Build outside ~/Documents: it syncs with iCloud Drive, which tags bundle folders with
# attributes that break code signing.
OUT="$HOME/Library/Developer/TrueView-build"
APP="$OUT/TrueView.app"
BIN="TrueView"

rm -rf "$APP" "$OUT/obj"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$OUT/obj"
cp Icon/TrueView.icns "$APP/Contents/Resources/TrueView.icns"

clang -c Sources/DisplayControl.m -o "$OUT/obj/DisplayControl.o" -fobjc-arc -O2 -mmacosx-version-min=26.0

swiftc -O -swift-version 5 -target arm64-apple-macos26.0 \
  -import-objc-header Sources/DisplayControl.h \
  Sources/*.swift "$OUT/obj/DisplayControl.o" \
  -framework AppKit -framework SwiftUI -framework CoreGraphics -framework ServiceManagement \
  -o "$APP/Contents/MacOS/$BIN"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.trueview.app</string>
  <key>CFBundleName</key><string>TrueView</string>
  <key>CFBundleDisplayName</key><string>TrueView</string>
  <key>CFBundleExecutable</key><string>$BIN</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>CFBundleIconFile</key><string>TrueView</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>© 2026 Lucas Haliax</string>
  <key>UpdateRepository</key><string>lucashaliax/TrueView</string>
</dict></plist>
EOF

xattr -cr "$APP"
codesign --force --sign "$SIGN_ID" "$APP"
codesign --verify --deep --strict "$APP"
echo "Built and signed TrueView $VERSION: $APP"

if [[ "${1:-}" == "--no-install" ]]; then exit 0; fi

if [[ "${1:-}" == "--zip" ]]; then
  mkdir -p build/release
  rm -f build/release/TrueView.zip
  ditto -c -k --keepParent "$APP" build/release/TrueView.zip
  echo "Wrote build/release/TrueView.zip"
fi

pkill -x TrueView || true
sleep 1
rm -rf /Applications/TrueView.app
ditto "$APP" /Applications/TrueView.app
open -g /Applications/TrueView.app
echo "Installed /Applications/TrueView.app"

# Wait out launch work (e.g. an update check, which uses the network) so the measurement
# shows the app at rest.
sleep 15
tools/check_resources.sh /Applications/TrueView.app
