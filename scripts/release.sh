#!/bin/bash
set -euo pipefail

# release.sh — Single entry point to build and publish an Ora Browser release.
#
# Usage:
#   ./scripts/release.sh              # auto-increment patch (0.2.12 → 0.2.13)
#   ./scripts/release.sh 0.3.0        # explicit version
#   ./scripts/release.sh --minor      # bump minor (0.2.12 → 0.3.0)
#   ./scripts/release.sh --major      # bump major (0.2.12 → 1.0.0)
#   ./scripts/release.sh -y           # skip changelog confirmation
#
# Runs: preflight checks → version bump → build.sh → publish.sh
#
# You can also run build.sh and publish.sh independently:
#   ./scripts/build.sh                # just build, sign, notarize
#   ./scripts/publish.sh              # just publish (after build.sh)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

SKIP_CONFIRM=false
VERSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)  SKIP_CONFIRM=true; shift ;;
        --minor)   VERSION="__MINOR__"; shift ;;
        --major)   VERSION="__MAJOR__"; shift ;;
        -h|--help) sed -n '3,16p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *)         VERSION="$1"; shift ;;
    esac
done

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

step "Preflight checks"

[[ -f "project.yml" ]] || die "project.yml not found. Run from the project root."
[[ -d "ora" ]]         || die "ora/ directory not found. Run from the project root."

load_env APPLE_ID TEAM_ID SIGNING_IDENTITY DEVELOPER_ID_PROFILE APP_SPECIFIC_PASSWORD_KEYCHAIN ORA_PRIVATE_KEY

MISSING_TOOLS=()
command -v xcodegen   >/dev/null || MISSING_TOOLS+=(xcodegen)
command -v create-dmg >/dev/null || MISSING_TOOLS+=(create-dmg)
command -v gh         >/dev/null || MISSING_TOOLS+=(gh)
MISSING_CASKS=()

setup_sparkle_tools || prime_sparkle_tools_from_xcode || MISSING_CASKS+=(sparkle)

if [[ ${#MISSING_TOOLS[@]} -gt 0 || ${#MISSING_CASKS[@]} -gt 0 ]]; then
    command -v brew >/dev/null || die "Homebrew is required to install missing release tooling."
fi

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    echo "Installing missing tools: ${MISSING_TOOLS[*]}"
    HOMEBREW_NO_AUTO_UPDATE=1 brew install "${MISSING_TOOLS[@]}"
fi

if [[ ${#MISSING_CASKS[@]} -gt 0 ]]; then
    echo "Installing missing casks: ${MISSING_CASKS[*]}"
    HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask "${MISSING_CASKS[@]}"
    setup_sparkle_tools || prime_sparkle_tools_from_xcode || die "generate_appcast not found after installing Sparkle or resolving package dependencies."
fi

[[ -f "ora_public_key.pem" ]] || die "ora_public_key.pem not found."
git diff --quiet --exit-code || die "Uncommitted changes. Commit or stash first."

green "All checks passed."

# ---------------------------------------------------------------------------
# Version resolution
# ---------------------------------------------------------------------------

CURRENT_VERSION=$(grep "MARKETING_VERSION:" project.yml | sed 's/.*MARKETING_VERSION: //' | tr -d ' ')
CURRENT_BUILD=$(grep "CURRENT_PROJECT_VERSION:" project.yml | sed 's/.*CURRENT_PROJECT_VERSION: //' | tr -d ' ')

IFS='.' read -r V_MAJOR V_MINOR V_PATCH <<< "$CURRENT_VERSION"

if [[ -z "$VERSION" ]]; then
    VERSION="${V_MAJOR}.${V_MINOR}.$((V_PATCH + 1))"
elif [[ "$VERSION" == "__MINOR__" ]]; then
    VERSION="${V_MAJOR}.$((V_MINOR + 1)).0"
elif [[ "$VERSION" == "__MAJOR__" ]]; then
    VERSION="$((V_MAJOR + 1)).0.0"
fi

BUILD_VERSION=$(( ${CURRENT_BUILD:-0} + 1 ))

bold "Ora Browser v${VERSION} (build ${BUILD_VERSION})"
echo "  Current: v${CURRENT_VERSION} (build ${CURRENT_BUILD})"

# ---------------------------------------------------------------------------
# Changelog preview
# ---------------------------------------------------------------------------

LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
echo ""
if [[ -n "$LAST_TAG" ]]; then
    echo "Changes since $LAST_TAG:"
    git log --pretty=format:"  %s" --no-merges "$LAST_TAG"..HEAD | grep -Ev "^  (release: v|chore\\(release\\): v)" || true
else
    echo "Recent changes:"
    git log --pretty=format:"  %s" --no-merges --max-count=20 | grep -Ev "^  (release: v|chore\\(release\\): v)" || true
fi

if [[ "$SKIP_CONFIRM" != true ]]; then
    echo ""
    read -r -p "Release v${VERSION}? [Y/n]: " CONFIRM
    if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# ---------------------------------------------------------------------------
# Bump version
# ---------------------------------------------------------------------------

step "Bumping version to ${VERSION} (build ${BUILD_VERSION})"

sed -i '' "s/MARKETING_VERSION: .*/MARKETING_VERSION: $VERSION/" project.yml
sed -i '' "s/CURRENT_PROJECT_VERSION: .*/CURRENT_PROJECT_VERSION: $BUILD_VERSION/" project.yml

# ---------------------------------------------------------------------------
# Build → Publish
# ---------------------------------------------------------------------------

"$SCRIPT_DIR/build.sh"
"$SCRIPT_DIR/publish.sh"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

DMG_NAME="Ora-Browser-${VERSION}.dmg"
echo ""
green "========================================"
green "  Release v${VERSION} published!"
green "========================================"
echo ""
echo "  DMG:     build/${DMG_NAME} ($(du -h "build/${DMG_NAME}" | cut -f1))"
echo "  Release: https://github.com/the-ora/browser/releases/tag/v$VERSION"
echo "  Appcast: https://the-ora.github.io/browser/appcast.xml"
echo ""
