#!/bin/bash
# 打包 DeepSeekBalance.dmg：鲸鱼图标 + 拖拽安装布局
set -e
cd "$(dirname "$0")"

APP=~/Applications/DeepSeekBalance.app
STAGING=build/dmg-staging
DMG=build/DeepSeekBalance.dmg
TMP=build/tmp.dmg
VOLNAME="DeepSeek 余额"

echo "==> 构建 release app"
./build.sh >/dev/null 2>&1 || ./build.sh

echo "==> 生成 icns 图标"
mkdir -p build/AppIcon.iconset
for s in 16 32 64 128 256 512; do
  sips -z $s $s assets/whale.png --out build/AppIcon.iconset/icon_${s}x${s}.png >/dev/null 2>&1
done
for s in 32 64 128 256 512 1024; do
  h=$((s/2))
  sips -z $s $s assets/whale.png --out build/AppIcon.iconset/icon_${h}x${h}@2x.png >/dev/null 2>&1
done
iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns

echo "==> 设置 app 图标"
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "==> 组装 dmg 目录"
rm -rf "$STAGING" "$DMG" "$TMP"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
cp build/AppIcon.icns "$STAGING/.VolumeIcon.icns"

echo "==> 创建 dmg（含卷图标）"
hdiutil create -srcfolder "$STAGING" -volname "$VOLNAME" -format UDRW "$TMP" >/dev/null
MNTP=$(hdiutil attach "$TMP" -nobrowse | awk -F'\t' '/Volumes/ {print $NF}' | head -1)
SetFile -a C "$MNTP"
hdiutil detach "$MNTP" >/dev/null
hdiutil convert "$TMP" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$TMP"
rm -rf "$STAGING"

echo "==> 完成: $DMG ($(du -h "$DMG" | cut -f1))"
