#!/bin/zsh
# Compila o app e gera build/TrueView.app (só precisa das Command Line Tools).
set -euo pipefail
cd "$(dirname "$0")"

APP="build/TrueView.app"
BIN="TrueView"
rm -rf "$APP" build/obj
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/obj
cp Icon/TrueView.icns "$APP/Contents/Resources/TrueView.icns"

clang -c Sources/DisplayControl.m -o build/obj/DisplayControl.o -fobjc-arc -O2 -mmacosx-version-min=26.0

swiftc -O -swift-version 5 -target arm64-apple-macos26.0 \
  -import-objc-header Sources/DisplayControl.h \
  Sources/*.swift build/obj/DisplayControl.o \
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
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>CFBundleIconFile</key><string>TrueView</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF

xattr -cr "$APP"
codesign --force --sign - "$APP"
echo "OK: $APP"
