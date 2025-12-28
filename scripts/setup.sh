#!/bin/bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

echo "🔍 Checking dependencies..."

ensure_formula() {
  local cmd_name="$1"
  local formula_name="$2"

  if command -v "$cmd_name" >/dev/null 2>&1; then
    echo "✅ $cmd_name already installed"
    return 0
  fi

  echo "⬇️  Installing $cmd_name..."

  if ! command -v brew >/dev/null 2>&1; then
    echo "❌ Homebrew is not installed. Please install Homebrew first to proceed: https://brew.sh"
    exit 1
  fi

  # Install the formula if it's not already present
  if ! brew list --formula "$formula_name" >/dev/null 2>&1; then
    brew install "$formula_name"
  fi

  if command -v "$cmd_name" >/dev/null 2>&1; then
    echo "✅ $cmd_name installed"
  else
    echo "❌ Failed to install $cmd_name"
    exit 1
  fi
}

ensure_formula Xcodegen xcodegen
ensure_formula Swiftlint swiftlint
ensure_formula Swiftformat swiftformat
ensure_formula Xcbeautify xcbeautify

git config core.hooksPath .githooks
if [ -d .githooks ]; then
  chmod -R +x .githooks || true
fi
echo "✅ Git hooks installed!"

cd ..
xcodegen
echo "✅ Xcodegen generated successfully!"

echo "🎉 Setup complete."
