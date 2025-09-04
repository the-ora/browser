#!/bin/bash
set -e

# Setup Sparkle for Ora Browser
# This script generates DSA keys and creates the initial appcast.xml

echo "🔐 Setting up Sparkle for Ora Browser..."

# Check if generate_keys is available
if ! command -v generate_keys &> /dev/null; then
    echo "❌ generate_keys not found. Please install Sparkle tools:"
    echo "   brew install sparkle"
    exit 1
fi

# Create build directory
mkdir -p build

# Generate DSA keys
echo "🔑 Generating DSA keys..."
generate_keys

# Move keys to build directory
if [ -f "dsa_priv.pem" ]; then
    mv dsa_priv.pem build/
fi
if [ -f "dsa_pub.pem" ]; then
    mv dsa_pub.pem build/
fi

# Copy appcast template to build directory
if [ -f "appcast.xml" ]; then
    cp appcast.xml build/
fi

echo "✅ DSA keys generated!"
echo ""
echo "📋 Next steps:"
echo "1. Copy the public key from build/dsa_pub.pem"
echo "2. Add it to your Info.plist as SUPublicEDKey"
echo "3. Keep build/dsa_priv.pem secure for signing releases"
echo "4. Update build/appcast.xml template with your GitHub repo URL"
echo ""
echo "🔒 IMPORTANT: Keep build/dsa_priv.pem secure and never commit it to version control!"
echo "📁 All build files are now organized in the build/ directory"