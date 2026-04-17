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

# Copy icons
cp AppIcon.icns "$RESOURCES/"
cp icon.png "$RESOURCES/"

echo "✓ App bundle created at $APP_NAME"
echo "Run: open $APP_NAME"
