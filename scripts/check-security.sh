#!/bin/bash
set -e

echo "Checking Ora Browser security..."

if [ -f "build/dsa_priv.pem" ]; then
    echo "  DSA private key found: build/dsa_priv.pem"
    if git ls-files | grep -q "dsa_priv.pem"; then
        echo "error: Private key is tracked by git. Remove it with:" >&2
        echo "  git rm --cached build/dsa_priv.pem" >&2
        exit 1
    fi
    echo "  Private key is not tracked by git"
else
    echo "  DSA private key not found; will be generated on next release"
fi

if [ -f "build/dsa_pub.pem" ]; then
    echo "  DSA public key found: build/dsa_pub.pem"
else
    echo "  DSA public key not found"
fi

if grep -q "dsa_priv.pem" .gitignore; then
    echo "  Private key is listed in .gitignore"
else
    echo "error: Private key is not listed in .gitignore" >&2
    exit 1
fi

echo ""
echo "Security check passed."
echo "Note: Never commit build/dsa_priv.pem to version control."
