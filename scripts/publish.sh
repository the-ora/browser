#!/bin/bash
set -euo pipefail

# publish.sh — Sign with Sparkle, commit, create GitHub release, deploy appcast.
#
# Usage: ./scripts/publish.sh
#
# Expects build/Ora-Browser-<version>.dmg to exist (run build.sh first).
# Reads version from project.yml. Expects .env with: ORA_PRIVATE_KEY

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

REPO="the-ora/browser"

load_env ORA_PRIVATE_KEY

VERSION=$(grep "MARKETING_VERSION:" project.yml | sed 's/.*MARKETING_VERSION: //' | tr -d ' ')
BUILD_VERSION=$(grep "CURRENT_PROJECT_VERSION:" project.yml | sed 's/.*CURRENT_PROJECT_VERSION: //' | tr -d ' ')
DMG_NAME="Ora-Browser-${VERSION}.dmg"
DMG_FILE="build/${DMG_NAME}"

[[ -f "$DMG_FILE" ]] || die "DMG not found at $DMG_FILE. Run ./scripts/build.sh first."

# --- Sparkle signing & appcast ---

step "Sparkle signing & appcast"

# Locate Sparkle tools
SPARKLE_BIN=$(/bin/ls -d /opt/homebrew/Caskroom/sparkle/*/bin 2>/dev/null | sort -V | tail -1 || true)
[[ -n "$SPARKLE_BIN" ]] && export PATH="$SPARKLE_BIN:$PATH"
command -v sign_update >/dev/null || die "sign_update not found. Install sparkle: brew install sparkle"

echo "$ORA_PRIVATE_KEY" > build/temp_private_key.pem
SIGNATURE_OUTPUT=$(sign_update --ed-key-file build/temp_private_key.pem "$DMG_FILE" 2>&1)
rm -f build/temp_private_key.pem

SIGNATURE=$(echo "$SIGNATURE_OUTPUT" | sed -n 's/.*edSignature="\([^"]*\)".*/\1/p')
[[ -n "$SIGNATURE" ]] || die "Sparkle signing failed: $SIGNATURE_OUTPUT"
echo "Signature: ${SIGNATURE:0:30}..."

FILE_SIZE=$(stat -f%z "$DMG_FILE")
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")

# Generate changelog from commits since last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
if [[ -n "$LAST_TAG" ]]; then
    COMMITS=$(git log --pretty=format:"%s%x1F%an" --no-merges "$LAST_TAG"..HEAD)
else
    COMMITS=$(git log --pretty=format:"%s%x1F%an" --no-merges --max-count=50)
fi

html_escape() {
    local s="$1"
    s="${s//&/&amp;}"; s="${s//</&lt;}"; s="${s//>/&gt;}"; s="${s//\"/&quot;}"
    printf '%s' "$s"
}

declare -a FEAT=() FIX=() PERF=() DOCS=() CHORE=() OTHER=()
while IFS=$'\x1F' read -r subject author; do
    [[ -z "$subject" || "$subject" == "-" ]] && continue
    [[ "$subject" =~ ^[Uu]pdate\ to\ v[0-9] ]] && continue
    entry="$(html_escape "$subject") — $(html_escape "$author")"
    case "$subject" in
        feat*|Feat*)   FEAT+=("$entry")  ;;
        fix*|Fix*)     FIX+=("$entry")   ;;
        perf*|Perf*)   PERF+=("$entry")  ;;
        docs*|Docs*)   DOCS+=("$entry")  ;;
        chore*|Chore*) CHORE+=("$entry") ;;
        *)             OTHER+=("$entry") ;;
    esac
done <<< "$COMMITS"

CHANGELOG='<div class="changelog">'
for section in "Features:FEAT" "Fixes:FIX" "Performance:PERF" "Docs:DOCS" "Chores:CHORE" "Other:OTHER"; do
    title="${section%%:*}"
    declare -n arr="${section##*:}"
    if [[ ${#arr[@]} -gt 0 ]]; then
        CHANGELOG+=$'\n'"  <h3>$title</h3>"$'\n'"  <ul>"
        for item in "${arr[@]}"; do
            [[ -n "$item" ]] && CHANGELOG+=$'\n'"    <li>$item</li>"
        done
        CHANGELOG+=$'\n'"  </ul>"
    fi
done
CHANGELOG+=$'\n'"</div>"

cat > appcast.xml << APPCAST_EOF
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
$CHANGELOG
      ]]></description>
      <pubDate>$PUB_DATE</pubDate>
      <enclosure url="https://github.com/$REPO/releases/download/v$VERSION/$DMG_NAME"
                 sparkle:version="$BUILD_VERSION"
                 sparkle:shortVersionString="$VERSION"
                 length="$FILE_SIZE"
                 type="application/octet-stream"
                 sparkle:edSignature="$SIGNATURE"/>
    </item>
  </channel>
</rss>
APPCAST_EOF

# --- Commit & push ---

step "Committing & pushing"

git add project.yml appcast.xml ora_public_key.pem
git commit -m "release: v$VERSION"
git push origin main

# --- GitHub Release ---

step "GitHub release"

if gh release view "v$VERSION" --repo "$REPO" >/dev/null 2>&1; then
    gh release upload "v$VERSION" "$DMG_FILE" --repo "$REPO" --clobber
else
    gh release create "v$VERSION" "$DMG_FILE" \
        --repo "$REPO" \
        --title "v$VERSION" \
        --generate-notes
fi

echo "Release: https://github.com/$REPO/releases/tag/v$VERSION"

# --- Deploy appcast to gh-pages ---

step "Deploying appcast"

cp appcast.xml /tmp/ora_appcast_deploy.xml
CURRENT_BRANCH=$(git branch --show-current)

git stash push -m "Stash before deploying appcast v$VERSION" 2>/dev/null || true

if git ls-remote --heads origin gh-pages | grep -q gh-pages; then
    git fetch origin gh-pages
    git checkout gh-pages
else
    git checkout --orphan gh-pages
    git rm -rf .
    echo "# Ora Browser Updates" > README.md
    git add README.md
    git commit -m "Initialize gh-pages branch"
fi

cp /tmp/ora_appcast_deploy.xml appcast.xml
rm -f /tmp/ora_appcast_deploy.xml
git add -f appcast.xml
git diff --staged --quiet || git commit -m "Deploy appcast v$VERSION"
git push origin gh-pages

git checkout "$CURRENT_BRANCH"
git stash pop 2>/dev/null || true

green "Published! Appcast: https://the-ora.github.io/browser/appcast.xml"
