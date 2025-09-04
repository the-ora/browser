#!/bin/bash
set -e

# Create Release Script for Ora Browser
# This script creates a signed release and updates the appcast

if [ $# -lt 1 ]; then
    echo "Usage: $0 <version> [private_key_file]"
    echo "Example: $0 0.0.2 ../dsa_priv.pem"
    exit 1
fi

VERSION=$1
PRIVATE_KEY=${2:-"build/dsa_priv.pem"}

echo "🚀 Creating Ora Browser Release v$VERSION..."

# Build the release
echo "🔨 Building release..."
chmod +x build-release.sh
./build-release.sh

# Check if DMG was created
if [ ! -f "build/Ora-Browser.dmg" ]; then
    echo "❌ DMG not found in build/ directory. Build may have failed."
    exit 1
fi

# Sign the release with Sparkle
echo "🔐 Signing release with Sparkle..."
if [ -f "$PRIVATE_KEY" ]; then
    if command -v sign_update &> /dev/null; then
        SIGNATURE=$(sign_update -f "build/Ora-Browser.dmg" -k "$PRIVATE_KEY")
        echo "✅ Release signed: $SIGNATURE"
    else
        echo "⚠️  sign_update not found. Install Sparkle tools: brew install sparkle"
        SIGNATURE="SIGNATURE_PLACEHOLDER"
    fi
else
    echo "⚠️  Private key not found at $PRIVATE_KEY"
    SIGNATURE="SIGNATURE_PLACEHOLDER"
fi

# Update appcast.xml
echo "📝 Updating appcast.xml..."
sed -i.bak "s/0\.0\.1/$VERSION/g" build/appcast.xml
sed -i.bak "s/YOUR_DSA_SIGNATURE_HERE/$SIGNATURE/g" build/appcast.xml
sed -i.bak "s/v0\.0\.1/v$VERSION/g" build/appcast.xml

# Get file size
FILE_SIZE=$(stat -f%z "build/Ora-Browser.dmg")
sed -i.bak "s/length=\"0\"/length=\"$FILE_SIZE\"/g" build/appcast.xml

# Update pubDate
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")
sed -i.bak "s/<pubDate>.*<\/pubDate>/<pubDate>$PUB_DATE<\/pubDate>/g" build/appcast.xml

echo "✅ Release v$VERSION created!"
echo "📁 Files ready for upload (in build/ directory):"
echo "   - build/Ora-Browser.dmg (signed)"
echo "   - build/appcast.xml (updated)"
echo "   - build/dsa_pub.pem (public key for app)"
echo ""
echo "🚀 Next steps:"
echo "1. Upload build/Ora-Browser.dmg to GitHub releases"
echo "2. Host build/appcast.xml at a public URL"
echo "3. Add build/dsa_pub.pem content to your app's SUPublicEDKey"
echo "4. Update SUFeedURL in Info.plist to point to your appcast.xml"