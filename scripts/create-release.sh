#!/bin/bash
set -e

# Create Release Script for Ora Browser
# This script creates a signed release and updates the appcast
#
# Key Management:
# - Public key: Stored in ora_public_key.pem (committed to git)
# - Private key: Stored in .env file (NEVER commit this!)
# - If keys don't exist, new Ed25519 keys are generated
# - If private key missing, build fails with clear instructions
#
# Usage: $0 [version]
# If no version is provided, it will auto-increment the patch version from project.yml
# Example: $0 0.0.36

# Handle version argument
if [ $# -lt 1 ]; then
    # Auto-increment version
    if [ -f "project.yml" ]; then
        CURRENT_VERSION=$(grep "MARKETING_VERSION:" project.yml | sed 's/.*MARKETING_VERSION: //' | tr -d ' ')
        if [ -n "$CURRENT_VERSION" ]; then
            # Increment the last number
            VERSION=$(echo "$CURRENT_VERSION" | awk -F. '{print $1"."$2"."($3+1)}')
            echo "Auto-incrementing version from $CURRENT_VERSION to $VERSION"
        else
            echo "Could not find MARKETING_VERSION in project.yml"
            exit 1
        fi
    else
        echo "project.yml not found for auto-increment"
        exit 1
    fi
else
    VERSION=$1
fi

# Set BUILD_VERSION to current + 1
if [ -f "project.yml" ]; then
    CURRENT_BUILD_VERSION=$(grep "CURRENT_PROJECT_VERSION:" project.yml | sed 's/.*CURRENT_PROJECT_VERSION: //' | tr -d ' ')
    if [ -n "$CURRENT_BUILD_VERSION" ]; then
        BUILD_VERSION=$((CURRENT_BUILD_VERSION + 1))
        echo "Setting BUILD_VERSION to $BUILD_VERSION (from $CURRENT_BUILD_VERSION + 1)"
    else
        BUILD_VERSION=$(echo $VERSION | awk -F. '{print $NF + 0}')
    fi
else
    BUILD_VERSION=$(echo $VERSION | awk -F. '{print $NF + 0}')
fi

# Private key will be determined by the key management section above
# PRIVATE_KEY is set dynamically based on available keys

# Save original directory
ORIGINAL_DIR="$(pwd)"

echo "🚀 Creating Ora Browser Release v$VERSION..."

# Helper: Get last git tag (if any)
get_last_tag() {
    if git describe --tags --abbrev=0 >/dev/null 2>&1; then
        git describe --tags --abbrev=0 2>/dev/null || true
    else
        echo ""
    fi
}

# HTML-escape helper
html_escape() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    s="${s//\"/&quot;}"
    printf '%s' "$s"
}

# Helper: Generate changelog HTML from commits since last tag
generate_changelog_html() {
    local last_tag
    last_tag="$(get_last_tag)"

    local commits
    if [ -n "$last_tag" ]; then
        commits=$(git log --pretty=format:"%s%x1F%an" --no-merges "$last_tag"..HEAD)
    else
        commits=$(git log --pretty=format:"%s%x1F%an" --no-merges --max-count=50)
    fi

    if [ -z "$commits" ]; then
        cat <<'EOT'
        <div class="changelog">
          <p>No changes recorded since last release.</p>
        </div>
EOT
        return
    fi

    declare -a feat_list=()
    declare -a fix_list=()
    declare -a perf_list=()
    declare -a docs_list=()
    declare -a chore_list=()
    declare -a other_list=()
    while IFS=$'\x1F' read -r subject author; do
        # skip empty or stray dashes
        if [ -z "$subject" ] || [ "$subject" = "-" ]; then
            continue
        fi
        # skip version bump commits
        if [[ "$subject" =~ ^[Uu]pdate\ to\ v[0-9]+(\.[0-9]+){1,2}(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
            continue
        fi
        local safe_subject safe_author
        safe_subject=$(html_escape "$subject")
        safe_author=$(html_escape "$author")
        entry="${safe_subject} — ${safe_author}"
        case "$subject" in
            feat*|Feat*|FEAT*) feat_list+=("$entry") ;;
            fix*|Fix*|FIX*) fix_list+=("$entry") ;;
            perf*|Perf*|PERF*) perf_list+=("$entry") ;;
            docs*|Docs*|DOCS*) docs_list+=("$entry") ;;
            chore*|Chore*|CHORE*) chore_list+=("$entry") ;;
            *) other_list+=("$entry") ;;
        esac
    done <<EOF_COMMITS
$commits
EOF_COMMITS
    echo "        <div class=\"changelog\">"
    if [ ${#feat_list[@]} -gt 0 ]; then
        echo "          <h3>Features</h3>"
        echo "          <ul>"
        for i in "${feat_list[@]}"; do [ -n "$i" ] && echo "            <li>$i</li>"; done
        echo "          </ul>"
    fi
    if [ ${#fix_list[@]} -gt 0 ]; then
        echo "          <h3>Fixes</h3>"
        echo "          <ul>"
        for i in "${fix_list[@]}"; do [ -n "$i" ] && echo "            <li>$i</li>"; done
        echo "          </ul>"
    fi
    if [ ${#perf_list[@]} -gt 0 ]; then
        echo "          <h3>Performance</h3>"
        echo "          <ul>"
        for i in "${perf_list[@]}"; do [ -n "$i" ] && echo "            <li>$i</li>"; done
        echo "          </ul>"
    fi
    if [ ${#docs_list[@]} -gt 0 ]; then
        echo "          <h3>Docs</h3>"
        echo "          <ul>"
        for i in "${docs_list[@]}"; do [ -n "$i" ] && echo "            <li>$i</li>"; done
        echo "          </ul>"
    fi
    if [ ${#chore_list[@]} -gt 0 ]; then
        echo "          <h3>Chores</h3>"
        echo "          <ul>"
        for i in "${chore_list[@]}"; do [ -n "$i" ] && echo "            <li>$i</li>"; done
        echo "          </ul>"
    fi
    if [ ${#other_list[@]} -gt 0 ]; then
        echo "          <h3>Other</h3>"
        echo "          <ul>"
        for i in "${other_list[@]}"; do [ -n "$i" ] && echo "            <li>$i</li>"; done
        echo "          </ul>"
    fi
    echo "        </div>"
}

mkdir -p build

echo "📝 Generating changelog..."
CHANGELOG_HTML=$(generate_changelog_html)
if [ -z "$CHANGELOG_HTML" ]; then
    echo "❌ Changelog generation failed."
    exit 1
fi

echo ""
echo "──────── Generated Changelog ────────"
printf '%s\n' "$CHANGELOG_HTML"
echo "──────────────────────────────────────"
echo ""

read -r -p "Proceed with this changelog? [y/N]: " CONFIRM_CHANGELOG
if [ "${CONFIRM_CHANGELOG}" != "y" ] && [ "${CONFIRM_CHANGELOG}" != "Y" ]; then
    echo "❌ Release aborted by user."
    exit 1
fi

# Persist and export for later injection
printf '%s' "$CHANGELOG_HTML" > build/generated_changelog.html
export CHANGELOG_HTML="$CHANGELOG_HTML"

# Update project.yml with the release version and public key
echo "📝 Updating project.yml with version $VERSION..."
if [ -f "project.yml" ]; then
    # Update MARKETING_VERSION
    sed -i.bak "s/MARKETING_VERSION: .*/MARKETING_VERSION: $VERSION/" project.yml

    # Update CURRENT_PROJECT_VERSION
    sed -i.bak "s/CURRENT_PROJECT_VERSION: .*/CURRENT_PROJECT_VERSION: $BUILD_VERSION/" project.yml

    echo "✅ Updated project.yml: MARKETING_VERSION=$VERSION, CURRENT_PROJECT_VERSION=$BUILD_VERSION"
else
    echo "⚠️  project.yml not found, skipping version update"
fi

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

# Key management: Public key in root (committed), Private key in .env (not committed)
PUBLIC_KEY_FILE="ora_public_key.pem"
PRIVATE_KEY_FILE=".env"
PRIVATE_KEY_CONTENT=""  # Global variable to store private key content

# Check if public key exists in root directory
if [ -f "$PUBLIC_KEY_FILE" ]; then
    echo "🔑 Found existing public key in $PUBLIC_KEY_FILE"
    PUBLIC_KEY=$(cat "$PUBLIC_KEY_FILE")
    echo "✅ Using existing public key: ${PUBLIC_KEY:0:20}..."

    # Update SUPublicEDKey in project.yml now that we have the public key
    if [ -f "project.yml" ]; then
        # Escape forward slashes in PUBLIC_KEY for sed
        ESCAPED_PUBLIC_KEY=$(echo "$PUBLIC_KEY" | sed 's/\//\\\//g')
        sed -i.bak "s/SUPublicEDKey: .*/SUPublicEDKey: \"$ESCAPED_PUBLIC_KEY\"/" project.yml
        echo "✅ Updated SUPublicEDKey in project.yml: ${PUBLIC_KEY:0:20}..."
    fi

    # Add public key file to git
    git add "$PUBLIC_KEY_FILE"
    echo "✅ Added $PUBLIC_KEY_FILE to git"

    # Check if private key exists in .env file
    if [ -f "$PRIVATE_KEY_FILE" ]; then
        echo "🔑 Found private key in $PRIVATE_KEY_FILE"
        PRIVATE_KEY_CONTENT=$(grep "ORA_PRIVATE_KEY=" "$PRIVATE_KEY_FILE" | cut -d'=' -f2-)
        if [ -n "$PRIVATE_KEY_CONTENT" ]; then
            echo "✅ Private key found in .env file"
            # Store content globally and create temporary private key file for now
            echo "$PRIVATE_KEY_CONTENT" > build/temp_private_key.pem
            PRIVATE_KEY="build/temp_private_key.pem"
        else
            echo "❌ Private key not found in .env file!"
            echo "   Please add your private key to $PRIVATE_KEY_FILE in this format:"
            echo "   ORA_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----..."
            exit 1
        fi
    else
        echo "❌ Private key file (.env) not found!"
        echo "   Please create a .env file with your private key:"
        echo "   ORA_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----..."
        echo "   Or run this script from a machine that has the keys."
        exit 1
    fi
else
    echo "🔑 No public key found. Generating new Ed25519 keypair..."

    # Generate new Ed25519 keys
    if generate_keys --account "ora-browser-ed25519"; then
        echo "✅ New Ed25519 keys generated"

    # Get public key and save to root directory (will be committed)
    PUBLIC_KEY=$(generate_keys --account "ora-browser-ed25519" -p)
    echo "$PUBLIC_KEY" > "$PUBLIC_KEY_FILE"
    git add "$PUBLIC_KEY_FILE"
    echo "✅ Public key saved to $PUBLIC_KEY_FILE (added to git)"

        # Export private key and save to .env file (will NOT be committed)
        if generate_keys --account "ora-browser-ed25519" -x build/temp_private_key.pem 2>/dev/null; then
            PRIVATE_KEY_CONTENT=$(cat build/temp_private_key.pem)
            echo "ORA_PRIVATE_KEY=$PRIVATE_KEY_CONTENT" > "$PRIVATE_KEY_FILE"
            echo "✅ Private key saved to $PRIVATE_KEY_FILE (DO NOT commit this file!)"
            echo "⚠️  IMPORTANT: Add .env to your .gitignore if not already there"
            PRIVATE_KEY="build/temp_private_key.pem"
        else
            echo "❌ Failed to export private key"
            exit 1
        fi
    else
        echo "❌ Failed to generate Ed25519 keys"
        exit 1
    fi
fi

# Ensure build directory exists before creating appcast
mkdir -p build

# Create appcast.xml with current version
echo "📝 Creating appcast.xml for version $VERSION..."
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")
# Prefer AI-generated changelog if present; otherwise fall back locally
if [ -z "$CHANGELOG_HTML" ]; then
CHANGELOG_HTML=$(generate_changelog_html)
fi

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
        <p>Changes since last release:</p>
$(printf '%s' "$CHANGELOG_HTML")
      ]]></description>
      <pubDate>$PUB_DATE</pubDate>
       <enclosure url="https://github.com/the-ora/browser/releases/download/v$VERSION/Ora-Browser-$VERSION.dmg"
                  sparkle:version="$BUILD_VERSION"
                  sparkle:shortVersionString="$VERSION"
                  length="33592320"
                  type="application/octet-stream"
                   sparkle:edSignature="YOUR_DSA_SIGNATURE_HERE"/>
    </item>
  </channel>
</rss>
EOF
echo "✅ Sparkle setup complete!"

# Build the release
echo "🔨 Building release..."
BUILD_SCRIPT="./scripts/build-release.sh"

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
    ls -la scripts/build-release.sh 2>/dev/null || echo "scripts/build-release.sh not found in current directory"
    exit 1
fi

# Check if DMG was created
DMG_FILE="build/Ora-Browser-${VERSION}.dmg"
if [ ! -f "$DMG_FILE" ]; then
    echo "❌ DMG not found at $DMG_FILE. Build may have failed."
    exit 1
fi

# Recreate the private key file (build script may have cleaned it)
if [ -n "$PRIVATE_KEY_CONTENT" ]; then
    echo "🔑 Recreating private key file after build..."
    mkdir -p build
    echo "$PRIVATE_KEY_CONTENT" > build/temp_private_key.pem
    PRIVATE_KEY="build/temp_private_key.pem"
fi

# Sign the release with Sparkle
echo "🔐 Signing release with Sparkle..."
if [ -f "$PRIVATE_KEY" ] && [ -r "$PRIVATE_KEY" ] && [ -s "$PRIVATE_KEY" ]; then
    echo "📝 Signing DMG with private key..."
    SIGNATURE_OUTPUT=$(sign_update --ed-key-file "$PRIVATE_KEY" "$DMG_FILE" 2>&1)
    echo "Raw signature output: $SIGNATURE_OUTPUT"

    # Check if signing was successful
    if echo "$SIGNATURE_OUTPUT" | grep -q "sparkle:edSignature="; then
        SIGNATURE=$(echo "$SIGNATURE_OUTPUT" | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')
        echo "✅ Release signed successfully: $SIGNATURE"
    elif echo "$SIGNATURE_OUTPUT" | grep -q "edSignature="; then
        SIGNATURE=$(echo "$SIGNATURE_OUTPUT" | sed 's/.*edSignature="\([^"]*\)".*/\1/')
        echo "✅ Release signed successfully: $SIGNATURE"
    else
        echo "❌ Failed to sign release - invalid output"
        echo "Output was: $SIGNATURE_OUTPUT"
        echo "Make sure the private key is valid and the DMG exists"
        exit 1
    fi
else
    echo "❌ Private key not found, empty, or not readable at $PRIVATE_KEY"
    echo "Make sure your .env file contains a valid ORA_PRIVATE_KEY"
    exit 1
fi

# Update appcast.xml with signature and file size
echo "📝 Updating appcast.xml..."

# Get file size
FILE_SIZE=$(stat -f%z "$DMG_FILE")
echo "📏 DMG file size: $FILE_SIZE bytes"

# Update the signature (escape special characters in signature)
ESCAPED_SIGNATURE=$(echo "$SIGNATURE" | sed 's/\//\\\//g')
sed -i.bak "s/YOUR_DSA_SIGNATURE_HERE/$ESCAPED_SIGNATURE/g" appcast.xml

# Update file size
sed -i.bak "s/length=\"33592320\"/length=\"$FILE_SIZE\"/g" appcast.xml

echo "✅ Appcast.xml updated with signature and file size"

    # Commit changes before deployment
    echo "📝 Committing changes for v$VERSION..."
    git add project.yml appcast.xml "$PUBLIC_KEY_FILE"
    git commit -m "Update to v$VERSION"

# Backup appcast.xml before deployment
cp appcast.xml /tmp/appcast_backup.xml

# Deploy appcast.xml to GitHub Pages
echo "🌐 Deploying appcast.xml to GitHub Pages..."
deploy_to_github_pages() {
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "⚠️  Not in a git repository, skipping GitHub Pages deployment"
        return 1
    fi

    local current_branch=$(git branch --show-current)
    echo "📋 Current branch: $current_branch"

    # Check if gh-pages branch exists remotely
    if git ls-remote --heads origin gh-pages | grep -q gh-pages; then
        echo "📋 gh-pages branch exists remotely, updating..."
        git fetch origin gh-pages
    else
        echo "📋 Creating gh-pages branch..."
        git checkout -b gh-pages
        git rm -rf .
        echo "# Ora Browser Updates" > README.md
        echo "This branch hosts the appcast.xml for automatic updates." >> README.md
        git add README.md
        git commit -m "Initialize gh-pages branch"
    fi

    # Stash any uncommitted changes before switching
    git stash push -m "Stash before deploying appcast v$VERSION"

    # Switch to gh-pages branch
    git checkout gh-pages

    # Copy appcast.xml from the release branch
    cp /tmp/appcast_backup.xml appcast.xml
    rm /tmp/appcast_backup.xml
    echo "✅ Copied appcast.xml to gh-pages branch"

    # Show the version in the appcast
    echo "📋 Appcast version: $(grep -o 'Version [0-9.]*' appcast.xml | head -1)"

    # Commit and push
    git add -f appcast.xml
    if git diff --staged --quiet; then
        echo "📋 No changes to commit for appcast v$VERSION"
    else
        git commit -m "Deploy appcast v$VERSION"
        echo "📋 Committed appcast v$VERSION"
    fi

    # Push to remote with error handling
    echo "📤 Pushing to remote gh-pages branch..."
    if git push origin gh-pages; then
        echo "✅ Successfully pushed appcast v$VERSION to gh-pages branch"
        echo "🔗 Appcast URL: https://raw.githubusercontent.com/the-ora/browser/refs/heads/gh-pages/appcast.xml"
    else
        echo "❌ Failed to push to remote gh-pages branch"
        echo "   Check your git remote and permissions"
        return 1
    fi

    # Switch back to original branch
    git checkout "$current_branch"
    echo "✅ Switched back to $current_branch branch"

    # Restore stashed changes
    git stash pop
}

# Upload DMG to GitHub releases
echo "📤 Uploading DMG to GitHub releases..."
if [ -f "scripts/upload-dmg.sh" ]; then
    chmod +x scripts/upload-dmg.sh
    ./scripts/upload-dmg.sh "$VERSION" "$DMG_FILE"
else
    echo "⚠️  upload-dmg.sh not found, skipping automatic upload"
fi

# Run deployment after upload
if deploy_to_github_pages; then
    echo "🎉 Appcast deployed to GitHub Pages!"
    echo "   URL: https://the-ora.github.io/browser/appcast.xml"
else
    echo "⚠️  Appcast deployment failed, but release is still complete"
    echo "   You can manually deploy appcast.xml to GitHub Pages later"
fi

# Clean up temporary files
if [ -f "build/temp_private_key.pem" ]; then
    rm -f build/temp_private_key.pem
    echo "🧹 Cleaned up temporary private key file"
fi

# Security check - ensure sensitive files are not committed
echo "🔒 Security Check:"
if git ls-files 2>/dev/null | grep -q "\.env$"; then
    echo "❌ SECURITY VIOLATION: .env file is tracked by git!"
    echo "   This contains your private key! Run:"
    echo "   git rm --cached .env"
    echo "   git commit -m 'Remove .env from tracking'"
    exit 1
fi

if git ls-files 2>/dev/null | grep -q "temp_private_key.pem"; then
    echo "❌ SECURITY VIOLATION: Temporary private key file is tracked by git!"
    echo "   Run: git rm --cached build/temp_private_key.pem"
    exit 1
fi