#!/bin/bash
set -euo pipefail

# build.sh — Build, sign, notarize, and package Ora Browser into a DMG.
#
# Usage: ./scripts/build.sh
#
# Reads version from project.yml. Expects .env with:
#   TEAM_ID, SIGNING_IDENTITY, APP_SPECIFIC_PASSWORD_KEYCHAIN
#
# Output: build/Ora-Browser-<version>.dmg (signed, notarized, stapled)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

load_env TEAM_ID SIGNING_IDENTITY APP_SPECIFIC_PASSWORD_KEYCHAIN

VERSION=$(grep "MARKETING_VERSION:" project.yml | sed 's/.*MARKETING_VERSION: //' | tr -d ' ')
DMG_NAME="Ora-Browser-${VERSION}.dmg"

step "Building Ora Browser v${VERSION}"

# Clean build dir (preserve root appcast)
[[ -f appcast.xml ]] && cp appcast.xml /tmp/ora_appcast_backup.xml || true
rm -rf build/
mkdir -p build
[[ -f /tmp/ora_appcast_backup.xml ]] && mv /tmp/ora_appcast_backup.xml appcast.xml || true

echo "Generating Xcode project..."
xcodegen

echo "Building (this may take a few minutes)..."
if command -v xcbeautify >/dev/null 2>&1; then
    xcodebuild build \
        -scheme ora \
        -configuration Release \
        -destination "platform=macOS" \
        -derivedDataPath "build/DerivedData" \
        DEVELOPMENT_TEAM="$TEAM_ID" \
        2>&1 | xcbeautify
else
    xcodebuild build \
        -scheme ora \
        -configuration Release \
        -destination "platform=macOS" \
        -derivedDataPath "build/DerivedData" \
        DEVELOPMENT_TEAM="$TEAM_ID"
fi

[[ -d "build/DerivedData/Build/Products/Release/Ora.app" ]] || die "Build failed — Ora.app not found."

echo "Copying app bundle..."
ditto "build/DerivedData/Build/Products/Release/Ora.app" "build/Ora.app"

# --- Sign ---

step "Signing & packaging"

echo "Signing app bundle with Developer ID..."
codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "build/Ora.app"

echo "Creating DMG..."
create-dmg \
    --app-drop-link 600 185 \
    --window-size 800 400 \
    --volname "Ora Browser" \
    "build/${DMG_NAME}" \
    "build/Ora.app" 2>/dev/null || true

# create-dmg sometimes uses a temp name
TEMP_DMG=$(ls build/rw.*.dmg 2>/dev/null | head -1 || true)
[[ -n "$TEMP_DMG" ]] && mv "$TEMP_DMG" "build/${DMG_NAME}"
[[ -f "build/${DMG_NAME}" ]] || die "DMG creation failed."

echo "Signing DMG..."
codesign -f --timestamp -s "$SIGNING_IDENTITY" "build/${DMG_NAME}"

# --- Notarize ---

step "Notarizing"

xcrun notarytool submit "build/${DMG_NAME}" \
    --keychain-profile "${APP_SPECIFIC_PASSWORD_KEYCHAIN}" \
    --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "build/${DMG_NAME}"
xcrun stapler staple "build/Ora.app"

green "Build complete: build/${DMG_NAME} ($(du -h "build/${DMG_NAME}" | cut -f1))"
