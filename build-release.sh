#!/bin/bash
set -e

# Ora Browser Release Build Script
# This script builds a release version of Ora Browser for distribution

echo "🏗️  Building Ora Browser Release..."

# Clean previous builds but preserve DSA keys and appcast
echo "🧹 Cleaning previous builds..."
# Preserve important files
if [ -f "build/dsa_priv.pem" ]; then
    mv build/dsa_priv.pem /tmp/dsa_priv.pem.backup
fi
if [ -f "build/dsa_pub.pem" ]; then
    mv build/dsa_pub.pem /tmp/dsa_pub.pem.backup
fi
if [ -f "build/appcast.xml" ]; then
    mv build/appcast.xml /tmp/appcast.xml.backup
fi
if [ -f "appcast.xml" ]; then
    mv appcast.xml /tmp/root_appcast.xml.backup
fi
if [ -f "build/.gitkeep" ]; then
    mv build/.gitkeep /tmp/.gitkeep.backup
fi

rm -rf build/
mkdir -p build

# Restore preserved files
if [ -f "/tmp/dsa_priv.pem.backup" ]; then
    mv /tmp/dsa_priv.pem.backup build/dsa_priv.pem
fi
if [ -f "/tmp/dsa_pub.pem.backup" ]; then
    mv /tmp/dsa_pub.pem.backup build/dsa_pub.pem
fi
if [ -f "/tmp/appcast.xml.backup" ]; then
    mv /tmp/appcast.xml.backup build/appcast.xml
fi
if [ -f "/tmp/root_appcast.xml.backup" ]; then
    mv /tmp/root_appcast.xml.backup appcast.xml
fi
if [ -f "/tmp/.gitkeep.backup" ]; then
    mv /tmp/.gitkeep.backup build/.gitkeep
fi

# Clean up any leftover DMG files
rm -f *.dmg

# Get version from project.yml
VERSION=$(grep "MARKETING_VERSION:" project.yml | sed 's/.*MARKETING_VERSION: //' | tr -d ' ')
DMG_NAME="Ora-Browser-${VERSION}.dmg"

# Create export options plist
echo "⚙️  Creating export options..."
cat > build/exportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>teamID</key>
    <string></string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF

# Generate Xcode project (always regenerate to ensure latest project.yml)
echo "📋 Generating Xcode project..."
xcodegen

# Build the app directly (faster than archiving)
echo "🔨 Building release version..."
xcodebuild build \
    -scheme ora \
    -configuration Release \
    -destination "platform=macOS" \
    -derivedDataPath "build/DerivedData" \
    > /dev/null 2>&1

# Copy the built app to build directory
echo "📦 Copying built app..."
if [ -d "build/DerivedData/Build/Products/Release/Ora.app" ]; then
    cp -r "build/DerivedData/Build/Products/Release/Ora.app" "build/"
    echo "✅ App copied to build directory"
else
    echo "❌ Built app not found in expected location"
    exit 1
fi

# Create DMG if create-dmg is available
if command -v create-dmg &> /dev/null; then
    if [ -d "build/Ora.app" ]; then
        echo "💿 Creating DMG..."
        # Remove any existing DMG first
        rm -f "build/${DMG_NAME}"
        # Use simpler create-dmg command to avoid parsing issues
        create-dmg \
            --volname "OraBrowser" \
            --window-pos 200 120 \
            --window-size 800 400 \
            --icon-size 100 \
            --icon "build/Ora.app" 200 190 \
            --hide-extension "build/Ora.app" \
            --link "/Applications" 600 185 \
            "build/${DMG_NAME}" \
            "build/Ora.app" 2>/dev/null || {
                echo "⚠️  create-dmg had warnings but continuing..."
            }
        # Rename DMG if it was created with temporary name
        TEMP_DMG=$(ls build/rw.*.${DMG_NAME} 2>/dev/null | head -1)
        if [ -n "$TEMP_DMG" ]; then
            mv "$TEMP_DMG" "build/${DMG_NAME}"
        fi

        # Verify DMG was created
        if [ -f "build/${DMG_NAME}" ]; then
            echo "✅ DMG created successfully!"
        else
            echo "❌ DMG creation failed!"
            exit 1
        fi
    else
        echo "❌ Ora.app not found in build directory. Cannot create DMG."
        exit 1
    fi
else
    echo "⚠️  create-dmg not found. Skipping DMG creation."
    echo "Install with: brew install create-dmg"
fi

# Verify DMG creation
if [ -f "build/${DMG_NAME}" ]; then
    echo "✅ Release build complete!"
    echo "📁 Release files in build/:"
    ls -la build/
    echo ""
    echo "🚀 Ready for distribution:"
    echo "   - build/${DMG_NAME} ($(du -h build/${DMG_NAME} | cut -f1))"
    echo "   - build/Ora.app (macOS application)"
else
    echo "❌ DMG creation failed!"
    exit 1
fi