#!/bin/bash

echo "🔒 Checking Ora Browser Security..."

# Check if private key exists
if [ -f "build/dsa_priv.pem" ]; then
    echo "✅ DSA private key found in build/dsa_priv.pem"

    # Check if it's in git (it shouldn't be)
    if git ls-files | grep -q "dsa_priv.pem"; then
        echo "❌ SECURITY ISSUE: Private key is tracked by git!"
        echo "   Run: git rm --cached build/dsa_priv.pem"
        exit 1
    else
        echo "✅ Private key is not tracked by git"
    fi
else
    echo "⚠️  DSA private key not found - will be generated on next release"
fi

# Check if public key exists
if [ -f "build/dsa_pub.pem" ]; then
    echo "✅ DSA public key found in build/dsa_pub.pem"
else
    echo "⚠️  DSA public key not found"
fi

# Check .gitignore
if grep -q "dsa_priv.pem" .gitignore; then
    echo "✅ Private key is properly ignored in .gitignore"
else
    echo "❌ SECURITY ISSUE: Private key not in .gitignore!"
    exit 1
fi

echo ""
echo "🔐 Security check complete!"
echo "Remember: Never commit build/dsa_priv.pem to version control!"