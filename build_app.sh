#!/bin/bash
set -e

echo "Building XiaoBaiTouchTool..."

# Build release binary
swift build -c release

# Create app bundle structure
APP_NAME="XiaoBaiTouchTool.app"
CONTENTS="$APP_NAME/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_NAME"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy binary
cp .build/release/XiaoBaiTouchTool "$MACOS/"

# Copy Info.plist
cp Info.plist "$CONTENTS/"

# Generate AppIcon.icns from icon.png
echo "Generating AppIcon.icns from icon.png..."
ICONSET="AppIcon.iconset"
rm -rf "$ICONSET"
mkdir "$ICONSET"
sips -z 16 16     icon.png --out "$ICONSET/icon_16x16.png"      > /dev/null 2>&1
sips -z 32 32     icon.png --out "$ICONSET/icon_16x16@2x.png"   > /dev/null 2>&1
sips -z 32 32     icon.png --out "$ICONSET/icon_32x32.png"      > /dev/null 2>&1
sips -z 64 64     icon.png --out "$ICONSET/icon_32x32@2x.png"   > /dev/null 2>&1
sips -z 128 128   icon.png --out "$ICONSET/icon_128x128.png"    > /dev/null 2>&1
sips -z 256 256   icon.png --out "$ICONSET/icon_128x128@2x.png" > /dev/null 2>&1
sips -z 256 256   icon.png --out "$ICONSET/icon_256x256.png"    > /dev/null 2>&1
sips -z 512 512   icon.png --out "$ICONSET/icon_256x256@2x.png" > /dev/null 2>&1
sips -z 512 512   icon.png --out "$ICONSET/icon_512x512.png"    > /dev/null 2>&1
sips -z 1024 1024 icon.png --out "$ICONSET/icon_512x512@2x.png" > /dev/null 2>&1
iconutil -c icns "$ICONSET" -o AppIcon.icns
rm -rf "$ICONSET"

# Copy icons
cp AppIcon.icns "$RESOURCES/"
cp icon.png "$RESOURCES/"

# Ad-hoc sign (免费，无需开发者账号)
codesign --force --deep --sign - "$APP_NAME"

echo "✓ App bundle created at $APP_NAME"

# --- Build DMG ---
echo "Building DMG..."

DMG_NAME="XiaoBaiTouchTool.dmg"
DMG_STAGING="dmg_staging"

rm -f "$DMG_NAME"
rm -rf "$DMG_STAGING"

# Prepare staging folder
mkdir "$DMG_STAGING"
cp -r "$APP_NAME" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

# Generate background image with drag arrow
python3 << 'PYEOF'
from PIL import Image, ImageDraw, ImageFont

W, H = 660, 400
bg = Image.new("RGBA", (W, H), (245, 245, 247, 255))
draw = ImageDraw.Draw(bg)

arrow_y = 200
arrow_x_start = W // 2 - 80
arrow_x_end = W // 2 + 80
arrow_color = (150, 150, 150, 255)

draw.line([(arrow_x_start, arrow_y), (arrow_x_end - 5, arrow_y)], fill=arrow_color, width=6)
draw.polygon([
    (arrow_x_end + 8, arrow_y),
    (arrow_x_end - 20, arrow_y - 16),
    (arrow_x_end - 20, arrow_y + 16),
], fill=arrow_color)

try:
    font = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 32)
except:
    font = ImageFont.load_default()

text = "拖拽到此处安装"
bbox = draw.textbbox((0, 0), text, font=font)
tw = bbox[2] - bbox[0]
draw.text(((W - tw) // 2, arrow_y + 40), text, fill=(120, 120, 120, 255), font=font)

bg.save("dmg_background.png")
PYEOF

# Create DMG with create-dmg (brew install create-dmg)
create-dmg \
  --volname "XiaoBaiTouchTool" \
  --background "dmg_background.png" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 80 \
  --icon "XiaoBaiTouchTool.app" 170 190 \
  --icon "Applications" 490 190 \
  --hide-extension "XiaoBaiTouchTool.app" \
  --no-internet-enable \
  "$DMG_NAME" \
  "$DMG_STAGING/"

# Cleanup
rm -f dmg_background.png
rm -rf "$DMG_STAGING"

echo ""
echo "✓ DMG created at $DMG_NAME"
echo ""
echo "分发给朋友后，朋友需要运行以下命令解除限制："
echo "  xattr -cr /path/to/XiaoBaiTouchTool.app"
echo "或者在 系统设置 → 隐私与安全性 中点击「仍要打开」"
