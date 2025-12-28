#!/bin/bash
set -e

# Setup Sparkle for Ora Browser
# This script generates DSA keys and creates the initial appcast.xml

echo "🔐 Setting up Sparkle for Ora Browser..."

# Check if generate_keys is available
if ! command -v generate_keys &> /dev/null; then
    echo "📦 Installing Sparkle tools..."

    # Try Homebrew first
    if command -v brew &> /dev/null; then
        echo "🍺 Installing via Homebrew..."
        brew install sparkle
    else
        echo "❌ Homebrew not found. Please install Homebrew first:"
        echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi

    # Check again after installation
    if ! command -v generate_keys &> /dev/null; then
        echo "❌ generate_keys still not found after installation."
        echo "🔧 Trying alternative installation method..."

        # Try downloading Sparkle tools directly
        SPARKLE_URL="https://github.com/sparkle-project/Sparkle/releases/download/2.7.1/Sparkle-2.7.1.tar.xz"
        SPARKLE_DIR="$HOME/.sparkle-tools"

        echo "⬇️  Downloading Sparkle tools..."
        mkdir -p "$SPARKLE_DIR"
        cd "$SPARKLE_DIR"

        if command -v curl &> /dev/null; then
            curl -L "$SPARKLE_URL" -o sparkle.tar.xz
        elif command -v wget &> /dev/null; then
            wget "$SPARKLE_URL" -O sparkle.tar.xz
        else
            echo "❌ Neither curl nor wget found. Please install one of them."
            exit 1
        fi

        echo "📦 Extracting Sparkle tools..."
        tar -xf sparkle.tar.xz

        # Find the generate_keys binary
        GENERATE_KEYS_PATH=$(find . -name "generate_keys" -type f 2>/dev/null | head -1)

        if [ -z "$GENERATE_KEYS_PATH" ]; then
            echo "❌ generate_keys binary not found in downloaded Sparkle tools."
            echo "🔍 Contents of Sparkle directory:"
            find . -type f -name "*" | head -10
            exit 1
        fi

        echo "✅ Found generate_keys at: $GENERATE_KEYS_PATH"

        # Add to PATH for this session
        export PATH="$SPARKLE_DIR/bin:$PATH"

        # Create symlink for future use
        mkdir -p "$HOME/bin"
        ln -sf "$GENERATE_KEYS_PATH" "$HOME/bin/generate_keys"
        export PATH="$HOME/bin:$PATH"
    fi
fi

# Verify generate_keys is now available
if ! command -v generate_keys &> /dev/null; then
    echo "❌ generate_keys command still not available."
    echo "🔧 Please check your Sparkle installation or PATH."
    exit 1
fi

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