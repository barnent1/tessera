#!/usr/bin/env bash
set -euo pipefail

APP_NAME="tessera"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RES_DIR="${APP_DIR}/Contents/Resources"

# Ensure Command Line Tools are installed: xcode-select --install

echo "🔨 Building with Swift Package Manager..."
swift build -c release

echo "📦 Creating app bundle..."
mkdir -p "$MACOS_DIR" "$RES_DIR"

# Copy the built binary
cp ".build/release/Tessera" "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist
cp info.plist "${APP_DIR}/Contents/Info.plist"

# Copy icon if it exists
if [ -f "sources/resources/AppIcon.icns" ]; then
    cp sources/resources/AppIcon.icns "${RES_DIR}/"
    echo "📦 Copied AppIcon.icns"
fi

echo "✅ built ${APP_DIR}"
echo "run: open ${APP_DIR}"
echo "first run: grant Accessibility in System Settings → Privacy & Security → Accessibility."
