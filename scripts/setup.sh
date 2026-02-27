#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "Checking dependencies..."

ensure_formula() {
    local cmd="$1"
    local formula="$2"

    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  $cmd: ok"
        return 0
    fi

    if ! command -v brew >/dev/null 2>&1; then
        echo "error: Homebrew is required. Install it from https://brew.sh" >&2
        exit 1
    fi

    echo "  Installing $formula..."
    brew list --formula "$formula" >/dev/null 2>&1 || brew install "$formula"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "error: Failed to install $cmd" >&2
        exit 1
    fi
    echo "  $cmd: ok"
}

ensure_formula xcodegen xcodegen
ensure_formula swiftlint swiftlint
ensure_formula swiftformat swiftformat
ensure_formula xcbeautify xcbeautify
ensure_formula lefthook lefthook

lefthook install
echo "Git hooks installed."

xcodegen
echo "Xcode project generated."

echo ""
echo "Setup complete."
