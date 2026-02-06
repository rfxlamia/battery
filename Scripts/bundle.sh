#!/usr/bin/env bash
#
# Bundle the Battery executable into a proper macOS .app bundle.
# Usage: ./Scripts/bundle.sh [release|debug]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

CONFIG="${1:-debug}"
BUILD_DIR="$PROJECT_DIR/.build/$CONFIG"
APP_NAME="Battery"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"

echo "Bundling $APP_NAME ($CONFIG)..."

# Find the built binary
BINARY="$BUILD_DIR/$APP_NAME"
if [[ ! -f "$BINARY" ]]; then
    echo "Error: Binary not found at $BINARY"
    echo "Build first with: swift build -c $CONFIG"
    exit 1
fi

# Clean old bundle
rm -rf "$APP_BUNDLE"

# Create bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Sign with entitlements (ad-hoc for development)
codesign --force --sign - \
    --entitlements "$PROJECT_DIR/Battery.entitlements" \
    "$APP_BUNDLE"

echo "Created: $APP_BUNDLE"
echo ""
echo "To run:"
echo "  open $APP_BUNDLE"
echo ""
echo "To install to /Applications:"
echo "  cp -r $APP_BUNDLE /Applications/"
