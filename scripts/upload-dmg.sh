#!/bin/bash
set -e

# Upload DMG to GitHub Releases Script
# This script uploads the built DMG to GitHub releases

if [ $# -lt 1 ]; then
    echo "Usage: $0 <version> [dmg_file]"
    echo "Example: $0 0.0.18 build/Ora-Browser.dmg"
    exit 1
fi

VERSION=$1
DMG_FILE=${2:-"build/Ora-Browser.dmg"}
REPO="the-ora/browser"

echo "📤 Uploading Ora Browser v$VERSION DMG to GitHub..."

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found. Please install it first:"
    echo "   brew install gh"
    echo "   gh auth login"
    exit 1
fi

# Check if DMG file exists
if [ ! -f "$DMG_FILE" ]; then
    echo "❌ DMG file not found: $DMG_FILE"
    exit 1
fi

# Check if release already exists
if gh release view "v$VERSION" --repo "$REPO" &> /dev/null; then
    echo "📋 Release v$VERSION already exists. Uploading DMG to existing release..."
    gh release upload "v$VERSION" "$DMG_FILE" --repo "$REPO" --clobber
else
    echo "📋 Creating new release v$VERSION..."
    gh release create "v$VERSION" "$DMG_FILE" \
        --repo "$REPO" \
        --title "Ora Browser v$VERSION" \
        --notes "Release v$VERSION of Ora Browser" \
        --generate-notes
fi

echo "✅ Successfully uploaded $DMG_FILE to GitHub release v$VERSION"
echo "🔗 Release URL: https://github.com/$REPO/releases/tag/v$VERSION"