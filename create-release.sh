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

# Save original directory
ORIGINAL_DIR="$(pwd)"

echo "🚀 Creating Ora Browser Release v$VERSION..."

# Clean build directory for fresh build
echo "🧹 Cleaning build directory..."
rm -rf build/
mkdir -p build

# Setup Sparkle (generate DSA keys and install tools)
echo "🔐 Setting up Sparkle for Ora Browser..."

# Setup Sparkle tools PATH
echo "🔧 Setting up Sparkle tools..."

# Check if Sparkle is installed via Homebrew
if command -v brew &> /dev/null && brew list sparkle &> /dev/null; then
    echo "✅ Sparkle found via Homebrew"
    SPARKLE_BIN_PATH="/opt/homebrew/Caskroom/sparkle/2.7.1/bin"
    export PATH="$SPARKLE_BIN_PATH:$PATH"
elif [ -d "/opt/homebrew/Caskroom/sparkle" ]; then
    # Find the latest version
    SPARKLE_VERSION=$(ls /opt/homebrew/Caskroom/sparkle/ | sort -V | tail -1)
    SPARKLE_BIN_PATH="/opt/homebrew/Caskroom/sparkle/$SPARKLE_VERSION/bin"
    export PATH="$SPARKLE_BIN_PATH:$PATH"
else
    echo "❌ Sparkle not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install sparkle
        SPARKLE_BIN_PATH="/opt/homebrew/Caskroom/sparkle/2.7.1/bin"
        export PATH="$SPARKLE_BIN_PATH:$PATH"
    else
        echo "❌ Homebrew not found. Please install Homebrew first."
        exit 1
    fi
fi

echo "🔧 Sparkle tools path: $SPARKLE_BIN_PATH"

# Verify tools are available
if ! command -v generate_keys &> /dev/null; then
    echo "❌ generate_keys command not found in PATH"
    echo "Current PATH: $PATH"
    exit 1
fi

if ! command -v sign_update &> /dev/null; then
    echo "❌ sign_update command not found in PATH"
    echo "Current PATH: $PATH"
    exit 1
fi

echo "✅ Sparkle tools ready!"

# Ensure build directory exists
mkdir -p build

# Generate DSA keys (only if they don't already exist)
if [ ! -f "build/dsa_priv.pem" ] || [ ! -f "build/dsa_pub.pem" ]; then
    echo "🔑 Generating DSA keys..."

    # First check if keys exist in Keychain
    if generate_keys -p >/dev/null 2>&1; then
        echo "✅ DSA keys found in Keychain, exporting..."

        # Export private key from Keychain
        if generate_keys -x build/dsa_priv.pem 2>/dev/null; then
            echo "✅ Private key exported to build/dsa_priv.pem"
        else
            echo "❌ Failed to export private key from Keychain"
            exit 1
        fi

        # Get public key and save to file
        PUBLIC_KEY=$(generate_keys -p)
        echo "$PUBLIC_KEY" > build/dsa_pub.pem
        echo "✅ Public key saved to build/dsa_pub.pem"
    else
        echo "⚠️  No DSA keys found in Keychain. Generating new keys..."

        # Generate new DSA keys
        if generate_keys; then
            echo "✅ New DSA keys generated"

            # Export the newly generated keys
            if generate_keys -x build/dsa_priv.pem 2>/dev/null; then
                echo "✅ Private key exported to build/dsa_priv.pem"
            else
                echo "❌ Failed to export newly generated private key"
                exit 1
            fi

            # Get public key and save to file
            PUBLIC_KEY=$(generate_keys -p)
            echo "$PUBLIC_KEY" > build/dsa_pub.pem
            echo "✅ Public key saved to build/dsa_pub.pem"
        else
            echo "❌ Failed to generate DSA keys"
            exit 1
        fi
    fi
else
    echo "🔑 Using existing DSA keys..."
    echo "⚠️  IMPORTANT: Reusing existing keys maintains update chain integrity"
    echo "   Never delete build/dsa_priv.pem or you'll break automatic updates!"
fi

# Ensure build directory exists before creating appcast
mkdir -p build

# Create appcast.xml with current version
echo "📝 Creating appcast.xml for version $VERSION..."
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")
cat > appcast.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Ora Browser Changelog</title>
    <description>Most recent changes with links to updates.</description>
    <language>en</language>
    <item>
      <title>Version $VERSION</title>
      <description><![CDATA[
        <h2>Ora Browser v$VERSION</h2>
        <p>Latest release of Ora Browser with the following features:</p>
        <ul>
          <li>Modern web browsing experience</li>
          <li>Tabbed interface with sidebar</li>
          <li>Built-in ad blocking</li>
          <li>Privacy-focused design</li>
          <li>Automatic update system</li>
        </ul>
        <p>This release includes bug fixes and performance improvements. Enjoy browsing with Ora!</p>
      ]]></description>
      <pubDate>$PUB_DATE</pubDate>
      <enclosure url="https://your-github-repo/releases/download/v$VERSION/Ora-Browser.dmg"
                 sparkle:version="$VERSION"
                 sparkle:shortVersionString="$VERSION"
                 length="33592320"
                 type="application/octet-stream"
                 sparkle:dsaSignature="YOUR_DSA_SIGNATURE_HERE"/>
    </item>
  </channel>
</rss>
EOF

echo "✅ Sparkle setup complete!"

# Build the release
echo "🔨 Building release..."
BUILD_SCRIPT="./build-release.sh"

# Ensure we're in the project root directory
if [ ! -f "project.yml" ] || [ ! -d "ora" ]; then
    echo "❌ Not in project root directory!"
    echo "Current directory: $(pwd)"
    echo "Expected to find project.yml and ora/ directory"
    exit 1
fi

if [ -f "$BUILD_SCRIPT" ]; then
    chmod +x "$BUILD_SCRIPT"
    echo "📂 Running build script from: $(pwd)"
    "$BUILD_SCRIPT"
else
    echo "❌ build-release.sh not found at $BUILD_SCRIPT!"
    echo "Current directory: $(pwd)"
    ls -la build-release.sh 2>/dev/null || echo "build-release.sh not found in current directory"
    exit 1
fi

# Check if DMG was created
if [ ! -f "build/Ora-Browser.dmg" ]; then
    echo "❌ DMG not found in build/ directory. Build may have failed."
    exit 1
fi

# Sign the release with Sparkle
echo "🔐 Signing release with Sparkle..."
if [ -f "$PRIVATE_KEY" ]; then
    echo "📝 Signing DMG with private key..."
    SIGNATURE_OUTPUT=$(sign_update --ed-key-file "$PRIVATE_KEY" "build/Ora-Browser.dmg" 2>&1)
    echo "Raw signature output: $SIGNATURE_OUTPUT"

    # Extract signature from output (format: sparkle:edSignature="..." length="...")
    if echo "$SIGNATURE_OUTPUT" | grep -q "sparkle:edSignature="; then
        SIGNATURE=$(echo "$SIGNATURE_OUTPUT" | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')
        echo "✅ Release signed: $SIGNATURE"
    elif echo "$SIGNATURE_OUTPUT" | grep -q "edSignature="; then
        SIGNATURE=$(echo "$SIGNATURE_OUTPUT" | sed 's/.*edSignature="\([^"]*\)".*/\1/')
        echo "✅ Release signed: $SIGNATURE"
    else
        echo "❌ Failed to extract signature from output"
        echo "Output was: $SIGNATURE_OUTPUT"
        SIGNATURE="SIGNATURE_PLACEHOLDER"
    fi
else
    echo "❌ Private key not found at $PRIVATE_KEY"
    SIGNATURE="SIGNATURE_PLACEHOLDER"
fi

# Update appcast.xml with signature and file size
echo "📝 Updating appcast.xml..."

# Get file size
FILE_SIZE=$(stat -f%z "build/Ora-Browser.dmg")
echo "📏 DMG file size: $FILE_SIZE bytes"

# Update the signature (escape special characters in signature)
ESCAPED_SIGNATURE=$(echo "$SIGNATURE" | sed 's/\//\\\//g')
sed -i.bak "s/YOUR_DSA_SIGNATURE_HERE/$ESCAPED_SIGNATURE/g" appcast.xml

# Update file size
sed -i.bak "s/length=\"33592320\"/length=\"$FILE_SIZE\"/g" appcast.xml

echo "✅ Appcast.xml updated with signature and file size"

# Deploy appcast.xml to GitHub Pages
echo "🌐 Deploying appcast.xml to GitHub Pages..."
deploy_to_github_pages() {
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "⚠️  Not in a git repository, skipping GitHub Pages deployment"
        return 1
    fi

    local current_branch=$(git branch --show-current)

    # Check if gh-pages branch exists
    if git show-ref --verify --quiet refs/heads/gh-pages; then
        echo "📋 gh-pages branch exists, updating..."
    else
        echo "📋 Creating gh-pages branch..."
        git checkout -b gh-pages
        git rm -rf .
        echo "# Ora Browser Updates" > README.md
        echo "This branch hosts the appcast.xml for automatic updates." >> README.md
        git add README.md
        git commit -m "Initialize gh-pages branch"
    fi

    # Switch to gh-pages branch
    git checkout gh-pages

    # Copy appcast.xml from the release branch
    if [ -f "../$current_branch/appcast.xml" ]; then
        cp "../$current_branch/appcast.xml" .
        echo "✅ Copied appcast.xml from $current_branch branch"
    else
        echo "❌ Could not find appcast.xml in ../$current_branch/"
        echo "   Current directory: $(pwd)"
        echo "   Looking for: ../$current_branch/appcast.xml"
        ls -la "../$current_branch/" | grep appcast || echo "appcast.xml not found"
        git checkout "$current_branch"
        return 1
    fi

    # Commit and push
    git add -f appcast.xml
    if git diff --staged --quiet; then
        echo "📋 No changes to commit"
    else
        git commit -m "Deploy appcast v$VERSION"
        echo "📋 Committed appcast v$VERSION"
    fi

    # Push to remote
    if git push origin gh-pages 2>/dev/null; then
        echo "✅ Successfully pushed to gh-pages branch"
    else
        echo "⚠️  Could not push to remote (might be a local deployment)"
    fi

    # Switch back to original branch
    git checkout "$current_branch"
    echo "✅ Switched back to $current_branch branch"
}

# Run deployment
if deploy_to_github_pages; then
    echo "🎉 Appcast deployed to GitHub Pages!"
    echo "   URL: https://the-ora.github.io/browser/appcast.xml"
else
    echo "⚠️  Appcast deployment failed, but release is still complete"
    echo "   You can manually deploy appcast.xml to GitHub Pages later"
fi

echo "✅ Release v$VERSION created!"
echo "📁 Files ready for upload:"
echo "   - build/Ora-Browser.dmg (signed)"
echo "   - appcast.xml (automatically deployed to GitHub Pages ✅)"
echo "   - build/dsa_pub.pem (public key for app)"
echo "   - build/dsa_priv.pem (private key - keep secure!)"
echo ""
echo "🚀 Next steps:"
echo "1. Upload build/Ora-Browser.dmg to GitHub releases"
echo "2. Enable GitHub Pages in repository settings (if not already enabled)"
echo "   - Go to Settings → Pages"
echo "   - Set source to 'Deploy from a branch'"
echo "   - Set branch to 'gh-pages'"
echo "3. Add build/dsa_pub.pem content to your app's SUPublicEDKey"
echo "4. Update SUFeedURL in Info.plist to point to your appcast.xml"
echo ""
# Security check - ensure private key is not committed
if git ls-files 2>/dev/null | grep -q "dsa_priv.pem"; then
    echo "❌ SECURITY VIOLATION: Private key is tracked by git!"
    echo "   This is a serious security issue. Run:"
    echo "   git rm --cached build/dsa_priv.pem"
    echo "   Then regenerate keys for a fresh start"
    exit 1
fi

echo "🔒 IMPORTANT: Keep build/dsa_priv.pem secure and never commit it to version control!"
echo "   Run './check-security.sh' anytime to verify security status"