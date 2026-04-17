#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="XiaoBaiTouchTool"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building $APP_NAME..."
cd "$SCRIPT_DIR"
swift build -c release

echo "Packaging .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"

# Copy binary
cp ".build/release/$APP_NAME" "$MACOS/$APP_NAME"

# Copy Info.plist
cp "Info.plist" "$CONTENTS/Info.plist"

echo "Done! App bundle created at: $APP_BUNDLE"
echo ""
echo "To run: open \"$APP_BUNDLE\""
echo "Note: On first launch, grant Accessibility permission in System Settings > Privacy & Security > Accessibility"
