#!/bin/bash
set -e

# create-release.sh
# Build, sign, and publish a new Ora Browser release.
#
# Prerequisites:
#   1. Update MARKETING_VERSION and CURRENT_PROJECT_VERSION in project.yml
#   2. git commit -m "release: vX.Y.Z"
#   3. git tag vX.Y.Z
#   4. Run this script
#
# Key management:
#   Public key:  ora_public_key.pem (committed to git)
#   Private key: ORA_PRIVATE_KEY in .env (never commit this)

REPO="the-ora/browser"
DOWNLOAD_URL_PREFIX="https://github.com/$REPO/releases/download"

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

if [ ! -f "project.yml" ] || [ ! -d "ora" ]; then
    echo "error: Must be run from the project root (expected project.yml and ora/)." >&2
    exit 1
fi

VERSION=$(grep "MARKETING_VERSION:" project.yml | sed 's/.*MARKETING_VERSION: //' | tr -d ' ')
BUILD_VERSION=$(grep "CURRENT_PROJECT_VERSION:" project.yml | sed 's/.*CURRENT_PROJECT_VERSION: //' | tr -d ' ')

if [ -z "$VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "error: Could not read MARKETING_VERSION or CURRENT_PROJECT_VERSION from project.yml." >&2
    exit 1
fi

if ! git tag -l "v$VERSION" | grep -q "v$VERSION"; then
    echo "error: Git tag v$VERSION not found. Create it first:" >&2
    echo "  git tag v$VERSION" >&2
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "error: Working tree is not clean. Commit or stash changes first." >&2
    exit 1
fi

echo "Creating Ora Browser release v$VERSION (build $BUILD_VERSION)..."

# ---------------------------------------------------------------------------
# Sparkle setup
# ---------------------------------------------------------------------------

locate_sparkle_bin() {
    local sparkle_root="/opt/homebrew/Caskroom/sparkle"
    if [ -d "$sparkle_root" ]; then
        local ver
        ver=$(ls "$sparkle_root" | sort -V | tail -1)
        echo "$sparkle_root/$ver/bin"
    fi
}

SPARKLE_BIN="$(locate_sparkle_bin)"
if [ -n "$SPARKLE_BIN" ]; then
    export PATH="$SPARKLE_BIN:$PATH"
fi

if ! command -v generate_appcast >/dev/null 2>&1; then
    echo "Sparkle not found. Installing via Homebrew..."
    brew install sparkle
    SPARKLE_BIN="$(locate_sparkle_bin)"
    if [ -n "$SPARKLE_BIN" ]; then
        export PATH="$SPARKLE_BIN:$PATH"
    fi
fi

if ! command -v generate_appcast >/dev/null 2>&1; then
    echo "error: generate_appcast not found in PATH after install." >&2
    exit 1
fi

echo "Sparkle tools ready."

# ---------------------------------------------------------------------------
# Private key setup
# ---------------------------------------------------------------------------

if [ ! -f ".env" ]; then
    echo "error: .env file not found." >&2
    exit 1
fi

PRIVATE_KEY_CONTENT=$(grep "ORA_PRIVATE_KEY=" ".env" | cut -d'=' -f2-)
if [ -z "$PRIVATE_KEY_CONTENT" ]; then
    echo "error: ORA_PRIVATE_KEY not found in .env." >&2
    exit 1
fi

mkdir -p build
echo "$PRIVATE_KEY_CONTENT" > build/temp_private_key.pem

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
    # Get the tag before the current one
    git describe --tags --abbrev=0 "v$VERSION^" 2>/dev/null || true
}

generate_changelog() {
    local last_tag commits
    last_tag="$(get_last_tag)"

    if [ -n "$last_tag" ]; then
        commits=$(git log --pretty=format:"%s%x1F%an%x1F%ae" --no-merges "$last_tag"..HEAD)
    else
        commits=$(git log --pretty=format:"%s%x1F%an%x1F%ae" --no-merges --max-count=50)
    fi

    if [ -z "$commits" ]; then
        return
    fi

    local -a feat_list=() fix_list=() perf_list=() docs_list=() chore_list=() other_list=()
    local -a contributors=()

    while IFS=$'\x1F' read -r subject author email; do
        [ -z "$subject" ] || [ "$subject" = "-" ] && continue
        [[ "$subject" =~ ^[Uu]pdate\ to\ v[0-9]+(\.[0-9]+){1,2} ]] && continue
        [[ "$subject" =~ ^[Rr]elease:\ v[0-9]+(\.[0-9]+){1,2} ]] && continue

        # Extract GitHub username from noreply email, fall back to author name
        local gh_user="$author"
        if [[ "$email" =~ ^([0-9]+\+)?([^@]+)@users\.noreply\.github\.com$ ]]; then
            gh_user="${BASH_REMATCH[2]}"
        fi

        # Collect unique contributors
        local already_listed=false
        for c in "${contributors[@]+${contributors[@]}}"; do
            [ "$c" = "$gh_user" ] && already_listed=true && break
        done
        $already_listed || contributors+=("$gh_user")

        local entry_md entry_html
        entry_md="$subject — $author"
        entry_html="$(html_escape "$subject") — $(html_escape "$author")"

        case "$subject" in
            feat*|Feat*|FEAT*)    feat_list+=("$entry_md|$entry_html")  ;;
            fix*|Fix*|FIX*)       fix_list+=("$entry_md|$entry_html")   ;;
            perf*|Perf*|PERF*)    perf_list+=("$entry_md|$entry_html")  ;;
            docs*|Docs*|DOCS*)    docs_list+=("$entry_md|$entry_html")  ;;
            chore*|Chore*|CHORE*) chore_list+=("$entry_md|$entry_html") ;;
            *)                    other_list+=("$entry_md|$entry_html") ;;
        esac
    done <<EOF_COMMITS
$commits
EOF_COMMITS

    local md_out="" html_out='<div class="changelog">'

    local title items
    for section in "Features:feat_list" "Fixes:fix_list" "Performance:perf_list" "Docs:docs_list" "Chores:chore_list" "Other:other_list"; do
        title="${section%%:*}"
        local arr_name="${section##*:}"
        eval "items=(\"\${${arr_name}[@]+\${${arr_name}[@]}}\")"
        if [ ${#items[@]} -gt 0 ]; then
            md_out+=$'\n'"### $title"$'\n'
            html_out+=$'\n'"  <h3>$title</h3>"$'\n'"  <ul>"$'\n'
            for item in "${items[@]}"; do
                [ -z "$item" ] && continue
                local md_entry="${item%%|*}"
                local html_entry="${item##*|}"
                md_out+="- $md_entry"$'\n'
                html_out+="    <li>$html_entry</li>"$'\n'
            done
            html_out+="  </ul>"$'\n'
        fi
    done

    # Contributors
    if [ ${#contributors[@]} -gt 0 ]; then
        md_out+=$'\n'"### Contributors"$'\n'
        html_out+=$'\n'"  <h3>Contributors</h3>"$'\n'"  <ul>"$'\n'
        for username in "${contributors[@]}"; do
            md_out+="- @$username"$'\n'
            html_out+="    <li>$(html_escape "$username")</li>"$'\n'
        done
        html_out+="  </ul>"$'\n'
    fi

    html_out+='</div>'

    printf '%s' "$md_out" > build/release-notes.md
    printf '%s' "$html_out" > "build/Ora-Browser-${VERSION}.html"
}

echo "Generating changelog..."
generate_changelog

if [ ! -s "build/release-notes.md" ]; then
    echo "No changes found since last release."
    printf '### Release v%s\n\nNo changes recorded.\n' "$VERSION" > build/release-notes.md
    printf '<div class="changelog"><p>No changes recorded.</p></div>' > "build/Ora-Browser-${VERSION}.html"
fi

echo ""
echo "-------- Generated changelog --------"
cat build/release-notes.md
echo "-------------------------------------"
echo ""

read -r -p "Proceed with this changelog? [y/N]: " CONFIRM_CHANGELOG
if [ "${CONFIRM_CHANGELOG}" != "y" ] && [ "${CONFIRM_CHANGELOG}" != "Y" ]; then
    echo "Release aborted."
    exit 1
fi

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

echo "Building release..."
chmod +x ./scripts/build-release.sh
./scripts/build-release.sh

DMG_FILE="build/Ora-Browser-${VERSION}.dmg"
if [ ! -f "$DMG_FILE" ]; then
    echo "error: DMG not found at $DMG_FILE; build may have failed." >&2
    exit 1
fi

# Recreate private key (build script cleans build/)
mkdir -p build
echo "$PRIVATE_KEY_CONTENT" > build/temp_private_key.pem

# ---------------------------------------------------------------------------
# generate_appcast
# ---------------------------------------------------------------------------

echo "Generating appcast.xml with Sparkle..."

mkdir -p build/sparkle
cp "$DMG_FILE" "build/sparkle/"
cp "build/Ora-Browser-${VERSION}.html" "build/sparkle/"

generate_appcast build/sparkle/ \
    --ed-key-file build/temp_private_key.pem \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX/v$VERSION/" \
    --embed-release-notes

cp build/sparkle/appcast.xml build/appcast.xml
echo "appcast.xml generated."

# ---------------------------------------------------------------------------
# GitHub Release
# ---------------------------------------------------------------------------

echo "Publishing GitHub release..."

if ! command -v gh >/dev/null 2>&1; then
    echo "error: GitHub CLI not found. Install it: brew install gh && gh auth login" >&2
    exit 1
fi

if gh release view "v$VERSION" --repo "$REPO" >/dev/null 2>&1; then
    echo "Release v$VERSION already exists; uploading DMG..."
    gh release upload "v$VERSION" "$DMG_FILE" --repo "$REPO" --clobber
else
    gh release create "v$VERSION" "$DMG_FILE" \
        --repo "$REPO" \
        --title "Ora Browser v$VERSION" \
        --notes-file build/release-notes.md
fi

echo "GitHub release published."

# ---------------------------------------------------------------------------
# Deploy appcast to gh-pages
# ---------------------------------------------------------------------------

echo "Deploying appcast to GitHub Pages..."

CONTENT=$(base64 -i build/appcast.xml)
SHA=$(gh api "repos/$REPO/contents/appcast.xml?ref=gh-pages" --jq '.sha' 2>/dev/null || true)

if [ -n "$SHA" ]; then
    gh api "repos/$REPO/contents/appcast.xml" --method PUT \
        --field message="Deploy appcast v$VERSION" \
        --field content="$CONTENT" \
        --field branch="gh-pages" \
        --field sha="$SHA"
else
    gh api "repos/$REPO/contents/appcast.xml" --method PUT \
        --field message="Deploy appcast v$VERSION" \
        --field content="$CONTENT" \
        --field branch="gh-pages"
fi

echo "Appcast deployed: https://the-ora.github.io/browser/appcast.xml"

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

rm -f build/temp_private_key.pem
rm -rf build/sparkle/

# Security checks
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
echo "  GitHub: https://github.com/$REPO/releases/tag/v$VERSION"
echo "  Appcast: https://the-ora.github.io/browser/appcast.xml"
