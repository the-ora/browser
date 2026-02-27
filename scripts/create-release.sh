#!/bin/bash
set -e

# create-release.sh
# Build, sign, and publish a new Ora Browser release.
#
# Key management:
#   Public key:  ora_public_key.pem (committed to git)
#   Private key: ORA_PRIVATE_KEY in .env (never commit this)
#   New Ed25519 keys are generated automatically if none exist.
#
# Usage: $0 [version]
#   If version is omitted the patch component is auto-incremented.
#   Example: $0 0.0.36

# ---------------------------------------------------------------------------
# Version resolution
# ---------------------------------------------------------------------------

if [ $# -lt 1 ]; then
    if [ ! -f "project.yml" ]; then
        echo "error: project.yml not found; cannot auto-increment version." >&2
        exit 1
    fi
    CURRENT_VERSION=$(grep "MARKETING_VERSION:" project.yml | sed 's/.*MARKETING_VERSION: //' | tr -d ' ')
    if [ -z "$CURRENT_VERSION" ]; then
        echo "error: MARKETING_VERSION not found in project.yml." >&2
        exit 1
    fi
    VERSION=$(echo "$CURRENT_VERSION" | awk -F. '{print $1"."$2"."($3+1)}')
    echo "Auto-incrementing version: $CURRENT_VERSION -> $VERSION"
else
    VERSION=$1
fi

if [ -f "project.yml" ]; then
    CURRENT_BUILD_VERSION=$(grep "CURRENT_PROJECT_VERSION:" project.yml | sed 's/.*CURRENT_PROJECT_VERSION: //' | tr -d ' ')
    BUILD_VERSION=$(( ${CURRENT_BUILD_VERSION:-0} + 1 ))
else
    BUILD_VERSION=$(echo "$VERSION" | awk -F. '{print $NF + 0}')
fi

echo "Creating Ora Browser release v$VERSION (build $BUILD_VERSION)..."

# ---------------------------------------------------------------------------
# Changelog generation
# ---------------------------------------------------------------------------

html_escape() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    s="${s//\"/&quot;}"
    printf '%s' "$s"
}

get_last_tag() {
    git describe --tags --abbrev=0 2>/dev/null || true
}

generate_changelog_html() {
    local last_tag commits
    last_tag="$(get_last_tag)"

    if [ -n "$last_tag" ]; then
        commits=$(git log --pretty=format:"%s%x1F%an" --no-merges "$last_tag"..HEAD)
    else
        commits=$(git log --pretty=format:"%s%x1F%an" --no-merges --max-count=50)
    fi

    if [ -z "$commits" ]; then
        printf '<div class="changelog"><p>No changes recorded since last release.</p></div>\n'
        return
    fi

    local -a feat_list=() fix_list=() perf_list=() docs_list=() chore_list=() other_list=()

    while IFS=$'\x1F' read -r subject author; do
        [ -z "$subject" ] || [ "$subject" = "-" ] && continue
        [[ "$subject" =~ ^[Uu]pdate\ to\ v[0-9]+(\.[0-9]+){1,2} ]] && continue

        local entry
        entry="$(html_escape "$subject") — $(html_escape "$author")"

        case "$subject" in
            feat*|Feat*|FEAT*)    feat_list+=("$entry")  ;;
            fix*|Fix*|FIX*)       fix_list+=("$entry")   ;;
            perf*|Perf*|PERF*)    perf_list+=("$entry")  ;;
            docs*|Docs*|DOCS*)    docs_list+=("$entry")  ;;
            chore*|Chore*|CHORE*) chore_list+=("$entry") ;;
            *)                    other_list+=("$entry")  ;;
        esac
    done <<EOF_COMMITS
$commits
EOF_COMMITS

    echo '<div class="changelog">'

    local title items
    for section in "Features:feat_list" "Fixes:fix_list" "Performance:perf_list" "Docs:docs_list" "Chores:chore_list" "Other:other_list"; do
        title="${section%%:*}"
        local arr_name="${section##*:}"
        eval "items=(\"\${${arr_name}[@]+\${${arr_name}[@]}}\")"
        if [ ${#items[@]} -gt 0 ]; then
            echo "  <h3>$title</h3>"
            echo "  <ul>"
            for item in "${items[@]}"; do
                [ -n "$item" ] && echo "    <li>$item</li>"
            done
            echo "  </ul>"
        fi
    done

    echo '</div>'
}

mkdir -p build

echo "Generating changelog..."
CHANGELOG_HTML=$(generate_changelog_html)
if [ -z "$CHANGELOG_HTML" ]; then
    echo "error: Changelog generation failed." >&2
    exit 1
fi

echo ""
echo "-------- Generated changelog --------"
printf '%s\n' "$CHANGELOG_HTML"
echo "-------------------------------------"
echo ""

read -r -p "Proceed with this changelog? [y/N]: " CONFIRM_CHANGELOG
if [ "${CONFIRM_CHANGELOG}" != "y" ] && [ "${CONFIRM_CHANGELOG}" != "Y" ]; then
    echo "Release aborted."
    exit 1
fi

printf '%s' "$CHANGELOG_HTML" > build/generated_changelog.html
export CHANGELOG_HTML

# ---------------------------------------------------------------------------
# Update project.yml
# ---------------------------------------------------------------------------

echo "Updating project.yml (version=$VERSION, build=$BUILD_VERSION)..."
if [ -f "project.yml" ]; then
    sed -i.bak "s/MARKETING_VERSION: .*/MARKETING_VERSION: $VERSION/" project.yml
    sed -i.bak "s/CURRENT_PROJECT_VERSION: .*/CURRENT_PROJECT_VERSION: $BUILD_VERSION/" project.yml
    rm -f project.yml.bak
else
    echo "warning: project.yml not found; skipping version update"
fi

# ---------------------------------------------------------------------------
# Sparkle setup
# ---------------------------------------------------------------------------

echo "Setting up Sparkle tools..."

locate_sparkle_bin() {
    if command -v brew >/dev/null 2>&1 && brew list sparkle >/dev/null 2>&1; then
        # Find the installed version dynamically
        local sparkle_root="/opt/homebrew/Caskroom/sparkle"
        if [ -d "$sparkle_root" ]; then
            local ver
            ver=$(ls "$sparkle_root" | sort -V | tail -1)
            echo "$sparkle_root/$ver/bin"
            return
        fi
    fi
    echo ""
}

if ! command -v generate_keys >/dev/null 2>&1; then
    if ! command -v brew >/dev/null 2>&1; then
        echo "error: Homebrew is required. Install it from https://brew.sh" >&2
        exit 1
    fi
    brew install sparkle
fi

SPARKLE_BIN="$(locate_sparkle_bin)"
if [ -n "$SPARKLE_BIN" ]; then
    export PATH="$SPARKLE_BIN:$PATH"
fi

if ! command -v generate_keys >/dev/null 2>&1 || ! command -v sign_update >/dev/null 2>&1; then
    echo "error: Sparkle tools (generate_keys, sign_update) not found in PATH." >&2
    echo "  PATH=$PATH" >&2
    exit 1
fi

echo "Sparkle tools ready."

# ---------------------------------------------------------------------------
# Key management
# ---------------------------------------------------------------------------

PUBLIC_KEY_FILE="ora_public_key.pem"
PRIVATE_KEY_CONTENT=""

if [ -f "$PUBLIC_KEY_FILE" ]; then
    PUBLIC_KEY=$(cat "$PUBLIC_KEY_FILE")
    echo "Using existing public key: ${PUBLIC_KEY:0:20}..."

    # Keep project.yml in sync
    if [ -f "project.yml" ]; then
        ESCAPED_PUBLIC_KEY=$(echo "$PUBLIC_KEY" | sed 's/\//\\\//g')
        sed -i.bak "s/SUPublicEDKey: .*/SUPublicEDKey: \"$ESCAPED_PUBLIC_KEY\"/" project.yml
        rm -f project.yml.bak
    fi

    git add "$PUBLIC_KEY_FILE"

    if [ ! -f ".env" ]; then
        echo "error: .env file not found; cannot read private key." >&2
        exit 1
    fi

    PRIVATE_KEY_CONTENT=$(grep "ORA_PRIVATE_KEY=" ".env" | cut -d'=' -f2-)
    if [ -z "$PRIVATE_KEY_CONTENT" ]; then
        echo "error: ORA_PRIVATE_KEY not found in .env." >&2
        echo "  Add your private key as: ORA_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----..." >&2
        exit 1
    fi

    echo "$PRIVATE_KEY_CONTENT" > build/temp_private_key.pem
    PRIVATE_KEY="build/temp_private_key.pem"
else
    echo "No public key found; generating new Ed25519 keypair..."

    if ! generate_keys --account "ora-browser-ed25519"; then
        echo "error: Failed to generate Ed25519 keys." >&2
        exit 1
    fi

    PUBLIC_KEY=$(generate_keys --account "ora-browser-ed25519" -p)
    echo "$PUBLIC_KEY" > "$PUBLIC_KEY_FILE"
    git add "$PUBLIC_KEY_FILE"
    echo "Public key saved to $PUBLIC_KEY_FILE"

    if ! generate_keys --account "ora-browser-ed25519" -x build/temp_private_key.pem 2>/dev/null; then
        echo "error: Failed to export private key." >&2
        exit 1
    fi

    PRIVATE_KEY_CONTENT=$(cat build/temp_private_key.pem)
    echo "ORA_PRIVATE_KEY=$PRIVATE_KEY_CONTENT" > ".env"
    echo "Private key saved to .env — do not commit this file."
    PRIVATE_KEY="build/temp_private_key.pem"
fi

# ---------------------------------------------------------------------------
# Generate appcast.xml
# ---------------------------------------------------------------------------

echo "Creating appcast.xml for v$VERSION..."
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

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

if [ ! -f "project.yml" ] || [ ! -d "ora" ]; then
    echo "error: Must be run from the project root (expected project.yml and ora/)." >&2
    exit 1
fi

echo "Building release..."
chmod +x ./scripts/build-release.sh
./scripts/build-release.sh

DMG_FILE="build/Ora-Browser-${VERSION}.dmg"
if [ ! -f "$DMG_FILE" ]; then
    echo "error: DMG not found at $DMG_FILE; build may have failed." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Sign with Sparkle
# ---------------------------------------------------------------------------

# Recreate the private key file (build script cleans build/)
if [ -n "$PRIVATE_KEY_CONTENT" ]; then
    mkdir -p build
    echo "$PRIVATE_KEY_CONTENT" > build/temp_private_key.pem
    PRIVATE_KEY="build/temp_private_key.pem"
fi

if [ ! -s "$PRIVATE_KEY" ]; then
    echo "error: Private key is missing or empty at $PRIVATE_KEY" >&2
    exit 1
fi

echo "Signing release with Sparkle..."
SIGNATURE_OUTPUT=$(sign_update --ed-key-file "$PRIVATE_KEY" "$DMG_FILE" 2>&1)

if echo "$SIGNATURE_OUTPUT" | grep -q "edSignature="; then
    SIGNATURE=$(echo "$SIGNATURE_OUTPUT" | sed 's/.*edSignature="\([^"]*\)".*/\1/')
    echo "Signed: $SIGNATURE"
else
    echo "error: Sparkle signing failed." >&2
    echo "  Output: $SIGNATURE_OUTPUT" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Update appcast.xml
# ---------------------------------------------------------------------------

echo "Updating appcast.xml with signature and file size..."
FILE_SIZE=$(stat -f%z "$DMG_FILE")
ESCAPED_SIGNATURE=$(echo "$SIGNATURE" | sed 's/\//\\\//g')
sed -i.bak "s/YOUR_DSA_SIGNATURE_HERE/$ESCAPED_SIGNATURE/g" appcast.xml
sed -i.bak "s/length=\"33592320\"/length=\"$FILE_SIZE\"/g" appcast.xml
rm -f appcast.xml.bak

# ---------------------------------------------------------------------------
# Commit and deploy
# ---------------------------------------------------------------------------

echo "Committing changes for v$VERSION..."
git add project.yml appcast.xml "$PUBLIC_KEY_FILE"
git commit -m "Update to v$VERSION"

# Back up appcast before branch switch
cp appcast.xml /tmp/ora_appcast_deploy.xml

deploy_to_github_pages() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "warning: Not in a git repository; skipping GitHub Pages deployment."
        return 1
    fi

    local current_branch
    current_branch=$(git branch --show-current)

    if git ls-remote --heads origin gh-pages | grep -q gh-pages; then
        git fetch origin gh-pages
    else
        echo "Creating gh-pages branch..."
        git checkout -b gh-pages
        git rm -rf .
        echo "# Ora Browser Updates" > README.md
        echo "This branch hosts appcast.xml for automatic updates." >> README.md
        git add README.md
        git commit -m "Initialize gh-pages branch"
    fi

    git stash push -m "Stash before deploying appcast v$VERSION"
    git checkout gh-pages

    cp /tmp/ora_appcast_deploy.xml appcast.xml
    rm -f /tmp/ora_appcast_deploy.xml
    echo "Appcast version: $(grep -o 'Version [0-9.]*' appcast.xml | head -1)"

    git add -f appcast.xml
    if git diff --staged --quiet; then
        echo "No appcast changes to commit."
    else
        git commit -m "Deploy appcast v$VERSION"
    fi

    if git push origin gh-pages; then
        echo "Appcast deployed to gh-pages."
        echo "URL: https://raw.githubusercontent.com/the-ora/browser/refs/heads/gh-pages/appcast.xml"
    else
        echo "error: Failed to push to gh-pages." >&2
        git checkout "$current_branch"
        git stash pop
        return 1
    fi

    git checkout "$current_branch"
    git stash pop
}

# Upload DMG to GitHub releases
echo "Uploading DMG to GitHub releases..."
if [ -f "scripts/upload-dmg.sh" ]; then
    chmod +x scripts/upload-dmg.sh
    ./scripts/upload-dmg.sh "$VERSION" "$DMG_FILE"
else
    echo "warning: upload-dmg.sh not found; skipping upload."
fi

echo "Deploying appcast to GitHub Pages..."
if deploy_to_github_pages; then
    echo "Appcast deployed: https://the-ora.github.io/browser/appcast.xml"
else
    echo "warning: Appcast deployment failed. Deploy appcast.xml to GitHub Pages manually."
fi

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

if [ -f "build/temp_private_key.pem" ]; then
    rm -f build/temp_private_key.pem
fi

# Security check
if git ls-files 2>/dev/null | grep -q "\.env$"; then
    echo "error: .env is tracked by git. Remove it with:" >&2
    echo "  git rm --cached .env && git commit -m 'Remove .env from tracking'" >&2
    exit 1
fi

if git ls-files 2>/dev/null | grep -q "temp_private_key.pem"; then
    echo "error: Temporary private key is tracked by git." >&2
    echo "  git rm --cached build/temp_private_key.pem" >&2
    exit 1
fi

echo ""
echo "Release v$VERSION complete."
