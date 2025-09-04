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
PRIVATE_KEY=${2:-"dsa_priv.pem"}

echo "🚀 Creating Ora Browser Release v$VERSION..."

# Build the release
echo "🔨 Building release..."
chmod +x build-release.sh
./build-release.sh

# Check if DMG was created
if [ ! -f "Ora-Browser.dmg" ]; then
    echo "❌ DMG not found. Build may have failed."
    exit 1
fi

# Sign the release with Sparkle
echo "🔐 Signing release with Sparkle..."
if [ -f "$PRIVATE_KEY" ]; then
    if command -v sign_update &> /dev/null; then
        SIGNATURE=$(sign_update -f "Ora-Browser.dmg" -k "$PRIVATE_KEY")
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
sed -i.bak "s/0\.0\.1/$VERSION/g" appcast.xml
sed -i.bak "s/YOUR_DSA_SIGNATURE_HERE/$SIGNATURE/g" appcast.xml
sed -i.bak "s/v0\.0\.1/v$VERSION/g" appcast.xml

# Get file size
FILE_SIZE=$(stat -f%z "Ora-Browser.dmg")
sed -i.bak "s/length=\"0\"/length=\"$FILE_SIZE\"/g" appcast.xml

# Update pubDate
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")
sed -i.bak "s/<pubDate>.*<\/pubDate>/<pubDate>$PUB_DATE<\/pubDate>/g" appcast.xml

echo "✅ Release v$VERSION created!"
echo "📁 Files ready for upload:"
echo "   - Ora-Browser.dmg (signed)"
echo "   - appcast.xml (updated)"
echo ""
echo "🚀 Next: Upload Ora-Browser.dmg to GitHub releases"
echo "🌐 Host appcast.xml at: https://your-domain.com/appcast.xml"
echo "⚙️  Update SUFeedURL in Info.plist to point to your appcast.xml"