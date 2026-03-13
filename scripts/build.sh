#!/bin/bash
set -euo pipefail

# build.sh — Archive, export, notarize, and package Ora Browser into a DMG.
#
# Usage: ./scripts/build.sh
#
# Reads version from project.yml. Expects .env with:
#   TEAM_ID, SIGNING_IDENTITY, DEVELOPER_ID_PROFILE, APP_SPECIFIC_PASSWORD_KEYCHAIN
#
# Output: build/Ora-Browser-<version>.dmg (signed, notarized, stapled)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

load_env TEAM_ID SIGNING_IDENTITY DEVELOPER_ID_PROFILE APP_SPECIFIC_PASSWORD_KEYCHAIN

VERSION=$(grep "MARKETING_VERSION:" project.yml | sed 's/.*MARKETING_VERSION: //' | tr -d ' ')
DMG_NAME="Ora-Browser-${VERSION}.dmg"
ARCHIVE_PATH="build/Ora.xcarchive"
EXPORT_PATH="build/export"
EXPORT_OPTIONS_PLIST="/tmp/ora-export-options.plist"
NOTARY_RESULT_PLIST="/tmp/ora-notary-result.plist"
NOTARY_LOG_FILE="build/notary-log.json"
trap 'rm -f "$EXPORT_OPTIONS_PLIST"' EXIT

step "Building Ora Browser v${VERSION}"

# Clean build dir (preserve root appcast and public key)
[[ -f appcast.xml ]] && cp appcast.xml /tmp/ora_appcast_backup.xml || true
[[ -f ora_public_key.pem ]] && cp ora_public_key.pem /tmp/ora_public_key_backup.pem || true
rm -rf build/
mkdir -p build
[[ -f /tmp/ora_appcast_backup.xml ]] && mv /tmp/ora_appcast_backup.xml appcast.xml || true
[[ -f /tmp/ora_public_key_backup.pem ]] && mv /tmp/ora_public_key_backup.pem ora_public_key.pem || true

echo "Generating Xcode project..."
xcodegen

cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>${SIGNING_IDENTITY}</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>com.orabrowser.app</key>
        <string>${DEVELOPER_ID_PROFILE}</string>
    </dict>
</dict>
</plist>
EOF

echo "Archiving (this may take a few minutes)..."
if command -v xcbeautify >/dev/null 2>&1; then
    xcodebuild archive \
        -scheme ora \
        -configuration Release \
        -destination "platform=macOS" \
        -archivePath "$ARCHIVE_PATH" \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
        PROVISIONING_PROFILE_SPECIFIER="$DEVELOPER_ID_PROFILE" \
        DEVELOPMENT_TEAM="$TEAM_ID" \
        2>&1 | xcbeautify
else
    xcodebuild archive \
        -scheme ora \
        -configuration Release \
        -destination "platform=macOS" \
        -archivePath "$ARCHIVE_PATH" \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
        PROVISIONING_PROFILE_SPECIFIER="$DEVELOPER_ID_PROFILE" \
        DEVELOPMENT_TEAM="$TEAM_ID"
fi

[[ -d "$ARCHIVE_PATH" ]] || die "Archive failed — ${ARCHIVE_PATH} not found."

echo "Exporting signed app..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

APP_PATH="$EXPORT_PATH/Ora.app"
[[ -d "$APP_PATH" ]] || die "Export failed — ${APP_PATH} not found."

echo "Copying exported app bundle..."
ditto "$APP_PATH" "build/Ora.app"

echo "Verifying exported app signature..."
codesign --verify --deep --strict --verbose=4 "build/Ora.app" >/dev/null || die "App signature verification failed after export."

# --- Sign ---

step "Signing & packaging"

echo "Creating DMG..."
create-dmg \
    --app-drop-link 600 185 \
    --window-size 800 400 \
    --volname "Ora Browser" \
    --skip-jenkins \
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
    --wait \
    --output-format plist > "$NOTARY_RESULT_PLIST"

NOTARY_ID="$(plutil -extract id raw -o - "$NOTARY_RESULT_PLIST")"
NOTARY_STATUS="$(plutil -extract status raw -o - "$NOTARY_RESULT_PLIST")"

if [[ "$NOTARY_STATUS" != "Accepted" ]]; then
    red "Notarization failed with status: ${NOTARY_STATUS}"
    xcrun notarytool log "$NOTARY_ID" \
        --keychain-profile "${APP_SPECIFIC_PASSWORD_KEYCHAIN}" \
        "$NOTARY_LOG_FILE"
    echo ""
    echo "High-signal notarization issues:"
    if command -v rg >/dev/null 2>&1; then
        rg -n "severity|path|message|issue" "$NOTARY_LOG_FILE" || true
    else
        grep -En "severity|path|message|issue" "$NOTARY_LOG_FILE" || true
    fi
    die "See ${NOTARY_LOG_FILE} for full notarization details."
fi

echo "Stapling notarization ticket..."
xcrun stapler staple "build/${DMG_NAME}"
xcrun stapler staple "build/Ora.app"

green "Build complete: build/${DMG_NAME} ($(du -h "build/${DMG_NAME}" | cut -f1))"
