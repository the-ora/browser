#!/bin/bash
set -e

# Setup Sparkle for Ora Browser
# Generates Ed25519 keys and creates the initial appcast.xml.

echo "Setting up Sparkle for Ora Browser..."

if ! command -v generate_keys >/dev/null 2>&1; then
    echo "Installing Sparkle tools..."

    if ! command -v brew >/dev/null 2>&1; then
        echo "error: Homebrew is required. Install it from https://brew.sh" >&2
        exit 1
    fi

    brew install sparkle

    if ! command -v generate_keys >/dev/null 2>&1; then
        echo "generate_keys not found after brew install; trying direct download..."

        SPARKLE_VERSION="2.7.1"
        SPARKLE_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
        SPARKLE_DIR="$HOME/.sparkle-tools"

        mkdir -p "$SPARKLE_DIR"

        if ! command -v curl >/dev/null 2>&1; then
            echo "error: curl is required to download Sparkle tools." >&2
            exit 1
        fi

        curl -L "$SPARKLE_URL" -o "$SPARKLE_DIR/sparkle.tar.xz"
        tar -xf "$SPARKLE_DIR/sparkle.tar.xz" -C "$SPARKLE_DIR"

        GENERATE_KEYS_PATH=$(find "$SPARKLE_DIR" -name "generate_keys" -type f 2>/dev/null | head -1)
        if [ -z "$GENERATE_KEYS_PATH" ]; then
            echo "error: generate_keys binary not found in Sparkle download." >&2
            exit 1
        fi

        mkdir -p "$HOME/bin"
        ln -sf "$GENERATE_KEYS_PATH" "$HOME/bin/generate_keys"
        export PATH="$HOME/bin:$PATH"
    fi
fi

if ! command -v generate_keys >/dev/null 2>&1; then
    echo "error: generate_keys is still not available. Check your Sparkle installation." >&2
    exit 1
fi

echo "Generating Ed25519 keys..."
mkdir -p build
generate_keys

[ -f "dsa_priv.pem" ] && mv dsa_priv.pem build/
[ -f "dsa_pub.pem" ]  && mv dsa_pub.pem build/
[ -f "appcast.xml" ]  && cp appcast.xml build/

echo "Keys generated in build/."
echo ""
echo "Next steps:"
echo "  1. Copy the public key from build/dsa_pub.pem"
echo "  2. Add it to project.yml as SUPublicEDKey"
echo "  3. Keep build/dsa_priv.pem secure; do not commit it"
echo "  4. Update appcast.xml with your GitHub repository URL"
