#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="DeepSeekBalance"
BUNDLE_ID="com.tomo.deepseek-balance"
DEST="$HOME/Applications/$APP_NAME.app"

echo "==> swift build -c release"
swift build -c release

rm -rf "$DEST"
mkdir -p "$DEST/Contents/MacOS" "$DEST/Contents/Resources"

cp assets/whale.png "$DEST/Contents/Resources/whale.png"

BIN="$(swift build -c release --show-bin-path)/$APP_NAME"
cp "$BIN" "$DEST/Contents/MacOS/$APP_NAME"

cat > "$DEST/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>DeepSeekBalance</string>
  <key>CFBundleDisplayName</key><string>DeepSeek 余额</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$DEST" 2>/dev/null || true

echo "✅ 已安装到 $DEST"
open "$DEST"
