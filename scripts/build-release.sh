#!/bin/bash
set -e

# build-release.sh
# Builds, signs, and packages a release DMG for distribution.

load_env() {
    if [ ! -f ".env" ]; then
        echo "error: .env file not found." >&2
        echo "" >&2
        echo "Create a .env file with the following variables:" >&2
        echo "  APPLE_ID=your-apple-id@example.com" >&2
        echo "  TEAM_ID=your-team-id" >&2
        echo "  APP_SPECIFIC_PASSWORD_KEYCHAIN=your-keychain-item-name" >&2
        echo "  SIGNING_IDENTITY=\"Developer ID Application: Your Name (TEAM_ID)\"" >&2
        exit 1
    fi

    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a

    local required_vars=(APPLE_ID TEAM_ID APP_SPECIFIC_PASSWORD_KEYCHAIN SIGNING_IDENTITY)
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            echo "error: Missing required variable: $var (check your .env)" >&2
            exit 1
        fi
    done
}

load_env
export DEVELOPMENT_TEAM="$TEAM_ID"

VERSION=$(grep "MARKETING_VERSION:" project.yml | sed 's/.*MARKETING_VERSION: //' | tr -d ' ')
DMG_NAME="Ora-Browser-${VERSION}.dmg"

echo "Building Ora Browser v${VERSION} (Release)..."

# Preserve files that must survive a clean build
preserve() { [ -f "$1" ] && mv "$1" "$2" || true; }
restore()   { [ -f "$2" ] && mv "$2" "$1" || true; }

preserve build/dsa_priv.pem  /tmp/ora_build_dsa_priv.pem
preserve build/dsa_pub.pem   /tmp/ora_build_dsa_pub.pem
preserve build/appcast.xml   /tmp/ora_build_appcast.xml
preserve appcast.xml         /tmp/ora_root_appcast.xml
preserve build/.gitkeep      /tmp/ora_build_gitkeep

rm -rf build/
mkdir -p build

restore build/dsa_priv.pem   /tmp/ora_build_dsa_priv.pem
restore build/dsa_pub.pem    /tmp/ora_build_dsa_pub.pem
restore build/appcast.xml    /tmp/ora_build_appcast.xml
restore appcast.xml          /tmp/ora_root_appcast.xml
restore build/.gitkeep       /tmp/ora_build_gitkeep

rm -f ./*.dmg

cat > build/exportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>$SIGNING_IDENTITY</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF

echo "Generating Xcode project..."
xcodegen

echo "Building..."
xcodebuild build \
    -scheme ora \
    -configuration Release \
    -destination "platform=macOS" \
    -derivedDataPath "build/DerivedData" \
    DEVELOPMENT_TEAM="$TEAM_ID"

echo "Copying app bundle..."
if [ ! -d "build/DerivedData/Build/Products/Release/Ora.app" ]; then
    echo "error: Built app not found at expected path." >&2
    exit 1
fi
ditto "build/DerivedData/Build/Products/Release/Ora.app" "build/Ora.app"

echo "Signing app bundle..."
codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "build/Ora.app"

if ! command -v create-dmg >/dev/null 2>&1; then
    echo "error: create-dmg not found. Install it with: brew install create-dmg" >&2
    exit 1
fi

echo "Creating DMG..."
rm -f "build/${DMG_NAME}"
create-dmg \
    --app-drop-link 600 185 \
    --window-size 800 400 \
    --volname "Ora Browser" \
    "build/${DMG_NAME}" \
    "build/Ora.app" 2>/dev/null || true

# create-dmg may stage the output under a temporary name
TEMP_DMG=$(ls build/rw.*.${DMG_NAME} 2>/dev/null | head -1)
if [ -n "$TEMP_DMG" ]; then
    mv "$TEMP_DMG" "build/${DMG_NAME}"
fi

if [ ! -f "build/${DMG_NAME}" ]; then
    echo "error: DMG creation failed." >&2
    exit 1
fi

echo "Signing DMG..."
codesign -f --timestamp -s "$SIGNING_IDENTITY" "build/${DMG_NAME}"

echo "Notarizing..."
xcrun notarytool submit "build/${DMG_NAME}" \
    --keychain-profile "${APP_SPECIFIC_PASSWORD_KEYCHAIN}" \
    --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "build/${DMG_NAME}"
xcrun stapler staple "build/Ora.app"

# Security check
if git ls-files 2>/dev/null | grep -q "\.env$"; then
    echo "error: .env is tracked by git. Remove it with:" >&2
    echo "  git rm --cached .env && git commit -m 'Remove .env from tracking'" >&2
    exit 1
fi

echo ""
echo "Release build complete."
echo "  build/${DMG_NAME} ($(du -h "build/${DMG_NAME}" | cut -f1))"
echo "  build/Ora.app"
