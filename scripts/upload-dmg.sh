#!/bin/bash
set -e

REPO="the-ora/browser"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <version> [dmg_file]" >&2
    echo "Example: $0 0.0.18 build/Ora-Browser-0.0.18.dmg" >&2
    exit 1
fi

VERSION=$1
DMG_FILE=${2:-"build/Ora-Browser.dmg"}

echo "Uploading Ora Browser v$VERSION to GitHub releases..."

if ! command -v gh >/dev/null 2>&1; then
    echo "error: GitHub CLI not found. Install it:" >&2
    echo "  brew install gh && gh auth login" >&2
    exit 1
fi

if [ ! -f "$DMG_FILE" ]; then
    echo "error: DMG not found: $DMG_FILE" >&2
    exit 1
fi

if gh release view "v$VERSION" --repo "$REPO" >/dev/null 2>&1; then
    echo "Release v$VERSION already exists; uploading to it..."
    gh release upload "v$VERSION" "$DMG_FILE" --repo "$REPO" --clobber
else
    echo "Creating release v$VERSION..."
    gh release create "v$VERSION" "$DMG_FILE" \
        --repo "$REPO" \
        --title "Ora Browser v$VERSION" \
        --notes "Release v$VERSION of Ora Browser" \
        --generate-notes
fi

echo "Uploaded $DMG_FILE to GitHub release v$VERSION"
echo "Release URL: https://github.com/$REPO/releases/tag/v$VERSION"
