#!/usr/bin/env bash
#
# Bundle the Battery executable into a proper macOS .app bundle.
#
# Modes (controlled by CODESIGN_IDENTITY env var):
#   Dev (default):  ad-hoc signing, no notarization
#   Release (CI):   Developer ID signing with hardened runtime
#
# Environment variables:
#   CODESIGN_IDENTITY  - Signing identity (default: "-" for ad-hoc)
#   VERSION            - Version string for Info.plist (e.g. "0.2.0")
#   BUILD_NUMBER       - Build number for Info.plist (e.g. "42")
#
# Usage: ./Scripts/bundle.sh [release|debug]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

CONFIG="${1:-debug}"
APP_NAME="Battery"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"

# Determine binary location
if [[ "$CONFIG" == "release" ]]; then
    # Universal binary from swift build --arch arm64 --arch x86_64
    BINARY="$PROJECT_DIR/.build/apple/Products/Release/$APP_NAME"
    if [[ ! -f "$BINARY" ]]; then
        # Fallback to standard release path
        BINARY="$PROJECT_DIR/.build/release/$APP_NAME"
    fi
else
    BINARY="$PROJECT_DIR/.build/debug/$APP_NAME"
fi

CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

echo "==> Bundling $APP_NAME ($CONFIG)"
echo "    Binary: $BINARY"
echo "    Identity: $CODESIGN_IDENTITY"

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
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Inject version and build number if provided
if [[ -n "${VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist"
    echo "    Version: $VERSION"
fi
if [[ -n "${BUILD_NUMBER:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist"
    echo "    Build: $BUILD_NUMBER"
fi

# Copy Sparkle.framework if it exists in the build artifacts
SPARKLE_FRAMEWORK=""
for candidate in \
    "$PROJECT_DIR/.build/artifacts/sparkle-project/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" \
    "$PROJECT_DIR/.build/artifacts/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"; do
    if [[ -d "$candidate" ]]; then
        SPARKLE_FRAMEWORK="$candidate"
        break
    fi
done

if [[ -n "$SPARKLE_FRAMEWORK" ]]; then
    echo "    Copying Sparkle.framework..."
    cp -R "$SPARKLE_FRAMEWORK" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"

    # Deep-sign the framework
    codesign --force --sign "$CODESIGN_IDENTITY" \
        --options runtime --timestamp \
        --deep \
        "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
fi

# Copy app icon
if [[ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "    Copied AppIcon.icns"
fi

# Sign the app
if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
    # Ad-hoc signing for development
    codesign --force --sign - \
        --entitlements "$PROJECT_DIR/Battery.entitlements" \
        "$APP_BUNDLE"
else
    # Developer ID signing for release
    codesign --force --sign "$CODESIGN_IDENTITY" \
        --entitlements "$PROJECT_DIR/Battery.entitlements" \
        --options runtime \
        --timestamp \
        --deep \
        "$APP_BUNDLE"
fi

echo ""
echo "==> Created: $APP_BUNDLE"

if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
    echo ""
    echo "To run:"
    echo "  open $APP_BUNDLE"
    echo ""
    echo "To install to /Applications:"
    echo "  cp -r $APP_BUNDLE /Applications/"
fi
