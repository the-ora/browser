#!/bin/bash
set -e

# Ora Browser Release Build Script
# This script builds a release version of Ora Browser for distribution

echo "🏗️  Building Ora Browser Release..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build/
mkdir -p build

# Generate Xcode project if needed
if [ ! -f "Ora.xcodeproj" ]; then
    echo "📋 Generating Xcode project..."
    xcodegen
fi

# Build the app
echo "🔨 Building release version..."
xcodebuild build \
    -scheme ora \
    -configuration Release \
    -destination "platform=macOS" \
    -archivePath "build/Ora.xcarchive" \
    archive

# Export the app
echo "📦 Exporting app..."
xcodebuild -exportArchive \
    -archivePath "build/Ora.xcarchive" \
    -exportPath "build/" \
    -exportOptionsPlist "build/exportOptions.plist"

# Create DMG if create-dmg is available
if command -v create-dmg &> /dev/null; then
    echo "💿 Creating DMG..."
    create-dmg \
        --volname "Ora Browser" \
        --volicon "ora/Assets.xcassets/AppIcon.appiconset/ora-white-macos-icon.png" \
        --window-pos 200 120 \
        --window-size 800 400 \
        --icon-size 100 \
        --icon "build/Ora.app" 200 190 \
        --hide-extension "build/Ora.app" \
        --app-drop-link 600 185 \
        "build/Ora-Browser.dmg" \
        "build/Ora.app"
else
    echo "⚠️  create-dmg not found. Skipping DMG creation."
    echo "Install with: brew install create-dmg"
fi

echo "✅ Release build complete!"
echo "📁 Release files in build/:"
ls -la build/