#!/bin/bash
set -euo pipefail

# publish.sh — Generate changelogs, build the Sparkle appcast, create a GitHub
# release, and deploy the feed.
#
# Usage: ./scripts/publish.sh
#
# Expects build/Ora-Browser-<version>.dmg to exist (run build.sh first).
# Reads version from project.yml. Expects .env with: ORA_PRIVATE_KEY
# Optional changelog env vars:
#   ORA_CHANGELOG_MODEL   Override the Codex model used for changelog rewriting
#   ORA_CHANGELOG_REVIEW  Set to 1 to open generated notes in $EDITOR
#   ORA_CHANGELOG_NO_LLM  Set to 1 to force deterministic fallback notes

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

REPO="the-ora/browser"

load_env ORA_PRIVATE_KEY

VERSION=$(grep "MARKETING_VERSION:" project.yml | sed 's/.*MARKETING_VERSION: //' | tr -d ' ')
DMG_NAME="Ora-Browser-${VERSION}.dmg"
DMG_FILE="build/${DMG_NAME}"
SPARKLE_ARCHIVES_DIR="build/sparkle"
CHANGELOG_DIR="build/release-notes"
CHANGELOG_FILE="${CHANGELOG_DIR}/Ora-Browser-${VERSION}.md"
RELEASE_NOTES_FILE="${SPARKLE_ARCHIVES_DIR}/Ora-Browser-${VERSION}.html"
APPCAST_FILE="${SPARKLE_ARCHIVES_DIR}/appcast.xml"

[[ -f "$DMG_FILE" ]] || die "DMG not found at $DMG_FILE. Run ./scripts/build.sh first."

rm -rf "$SPARKLE_ARCHIVES_DIR"
rm -rf "$CHANGELOG_DIR"
mkdir -p "$CHANGELOG_DIR"
mkdir -p "$SPARKLE_ARCHIVES_DIR"

# --- Changelog generation ---

step "Generating changelog"

LAST_TAG=$(git describe --tags --abbrev=0 --exclude "v$VERSION" 2>/dev/null || true)
[[ -n "$LAST_TAG" ]] || die "No previous tag found. Create a release tag before publishing."

CHANGELOG_ARGS=(
    "$SCRIPT_DIR/generate-changelog.py"
    "$LAST_TAG"
    "v$VERSION"
    "$REPO"
    --output-markdown "$CHANGELOG_FILE"
    --output-html "$RELEASE_NOTES_FILE"
)

[[ "${ORA_CHANGELOG_REVIEW:-0}" == "1" ]] && CHANGELOG_ARGS+=(--review)
[[ "${ORA_CHANGELOG_NO_LLM:-0}" == "1" ]] && CHANGELOG_ARGS+=(--no-llm)

python3 "${CHANGELOG_ARGS[@]}"

# --- Sparkle appcast ---

step "Sparkle appcast"

setup_sparkle_tools || prime_sparkle_tools_from_xcode || die "generate_appcast not found. Install Sparkle with: brew install --cask sparkle or resolve package dependencies with xcodebuild."

cp "$DMG_FILE" "$SPARKLE_ARCHIVES_DIR/"
[[ -f appcast.xml ]] && cp appcast.xml "$APPCAST_FILE"

printf '%s' "$ORA_PRIVATE_KEY" | generate_appcast \
    --ed-key-file - \
    --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" \
    --full-release-notes-url "https://github.com/$REPO/releases/tag/v$VERSION" \
    --link "https://github.com/$REPO" \
    --embed-release-notes \
    "$SPARKLE_ARCHIVES_DIR"

[[ -f "$APPCAST_FILE" ]] || die "Appcast generation failed."
cp "$APPCAST_FILE" appcast.xml

# --- Commit & push ---

step "Committing & pushing"

git add project.yml appcast.xml
git commit -m "chore(release): v$VERSION"
git push origin main

# --- GitHub Release ---

step "GitHub release"

if gh release view "v$VERSION" --repo "$REPO" >/dev/null 2>&1; then
    gh release edit "v$VERSION" \
        --repo "$REPO" \
        --title "v$VERSION" \
        --notes-file "$CHANGELOG_FILE"
    gh release upload "v$VERSION" "$DMG_FILE" --repo "$REPO" --clobber
else
    gh release create "v$VERSION" "$DMG_FILE" \
        --repo "$REPO" \
        --title "v$VERSION" \
        --notes-file "$CHANGELOG_FILE"
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
    git commit -m "chore(appcast): initialize gh-pages"
fi

cp /tmp/ora_appcast_deploy.xml appcast.xml
rm -f /tmp/ora_appcast_deploy.xml
git add -f appcast.xml
git diff --staged --quiet || git commit -m "chore(appcast): deploy v$VERSION"
git push origin gh-pages

git checkout "$CURRENT_BRANCH"
git stash pop 2>/dev/null || true

green "Published! Appcast: https://the-ora.github.io/browser/appcast.xml"
