# Ora Browser Hosting Setup Guide

This guide explains how to set up hosting for Ora Browser's automatic update system using Sparkle.

## Overview

Ora Browser uses [Sparkle](https://sparkle-project.org/) for automatic updates. The system requires:

1. **Appcast Feed** (`appcast.xml`) - Tells Sparkle about available updates
2. **App Distribution** (`Ora-Browser.dmg`) - The actual app download
3. **Digital Signatures** - Ensures update integrity and security

## What Needs to Be Hosted

### 1. Appcast XML File
**File:** `appcast.xml`
**Purpose:** Update feed that Sparkle reads to check for new versions
**Content:** Release information, download URLs, version numbers, and digital signatures

### 2. App DMG File
**File:** `Ora-Browser.dmg`
**Purpose:** The actual application installer that users download
**Content:** Signed and notarized macOS application bundle

## Hosting Options

### Option A: GitHub Pages (Recommended)

#### Step 1: Create GitHub Pages Branch
```bash
# Create and switch to gh-pages branch
git checkout -b gh-pages

# Remove all files except what we need for hosting
git rm -rf .
git reset -- docs/  # Keep docs if you want

# Copy appcast.xml
cp ../appcast.xml .

# Commit and push
git add appcast.xml
git commit -m "Add appcast.xml for Sparkle updates"
git push origin gh-pages
```

#### Step 2: Enable GitHub Pages
1. Go to your GitHub repository
2. Navigate to **Settings** → **Pages**
3. Set **Source** to "Deploy from a branch"
4. Set **Branch** to `gh-pages` and folder to `/ (root)`
5. Click **Save**

#### Step 3: Get Your URLs
- **Appcast URL:** `https://the-ora.github.io/browser/appcast.xml`
- **DMG URL:** `https://github.com/the-ora/browser/releases/download/v0.0.1/Ora-Browser.dmg`

### Option B: Your Own Web Server

#### Requirements
- Public web server with HTTPS
- Ability to upload files
- CORS headers configured (if needed)

#### Setup Steps
1. Upload `appcast.xml` to your web server
2. Ensure it's accessible via HTTPS
3. Update the enclosure URL in `appcast.xml` to point to your DMG location

#### Example URLs
- **Appcast URL:** `https://updates.yourdomain.com/appcast.xml`
- **DMG URL:** `https://downloads.yourdomain.com/Ora-Browser.dmg`

### Option C: GitHub Releases Only

#### Setup Steps
1. Upload both `appcast.xml` and `Ora-Browser.dmg` to GitHub Releases
2. Use raw GitHub URLs for both files

#### URLs
- **Appcast URL:** `https://raw.githubusercontent.com/the-ora/browser/main/appcast.xml`
- **DMG URL:** `https://github.com/the-ora/browser/releases/download/v0.0.1/Ora-Browser.dmg`

## Digital Signature Setup

### Generate DSA Keys
```bash
# Install Sparkle
brew install --cask sparkle

# Setup command-line tools
./setup-sparkle-tools.sh

# Generate keys (run once)
./setup-sparkle.sh

# This creates in build/:
# - build/dsa_priv.pem (private key - keep secure!)
# - build/dsa_pub.pem (public key - safe to share)
```

### Sign Your Release
```bash
# Sign the DMG with your private key
sign_update -f Ora-Browser.dmg -k dsa_priv.pem

# Copy the signature output
```

### Update Appcast with Real Signature
Replace the placeholder in `appcast.xml`:
```xml
<!-- Replace this placeholder: -->
sparkle:dsaSignature="PLACEHOLDER_SIGNATURE_REPLACE_WITH_ACTUAL_SIGNATURE"

<!-- With your actual signature from sign_update command -->
```

## App Configuration

### Update Info.plist
Add these keys to your `Info.plist` or `project.yml`:

```xml
<key>SUFeedURL</key>
<string>https://the-ora.github.io/browser/appcast.xml</string>

<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_HERE</string>
```

### XcodeGen Configuration
If using XcodeGen, update `project.yml`:
```yaml
settings:
  base:
    SUFeedURL: https://the-ora.github.io/browser/appcast.xml
    SUPublicEDKey: YOUR_PUBLIC_KEY_HERE
```

## Release Process

### Step 1: Build Release
```bash
# Build and package the app
./scripts/build-release.sh

# Or use the comprehensive release script (auto-increments version)
./scripts/create-release.sh
```

### Step 2: Sign Release
```bash
# Sign with Sparkle
sign_update -f Ora-Browser.dmg -k dsa_priv.pem
```

### Step 3: Update Appcast
```bash
# Update version numbers, dates, and signature in appcast.xml
# Update enclosure URL to point to your hosted DMG
```

### Step 4: Host Files
1. Upload `appcast.xml` to your chosen hosting location
2. Upload `Ora-Browser.dmg` to GitHub Releases
3. Update your app's `SUFeedURL` if needed

### Step 5: Test Updates
1. Build and run your app
2. Go to Settings → General → Updates
3. Click "Check for Updates"
4. Verify the update notification appears

## File Structure

```
your-project/
├── build/                    # Build artifacts directory
│   ├── appcast.xml          # Update feed (public)
│   ├── Ora-Browser.dmg      # App installer
│   ├── dsa_priv.pem         # Private key (keep secure!)
│   └── dsa_pub.pem          # Public key
└── docs/                    # Documentation
    ├── HOSTING_SETUP.md     # This guide
    └── QUICK_START.md       # Quick setup guide
```

## Security Considerations

### Private Key Security
- **Never commit `dsa_priv.pem`** to version control
- Store securely (password manager, secure server)
- Use different keys for different environments if needed

### HTTPS Requirement
- Always host `appcast.xml` over HTTPS
- GitHub Pages automatically provides HTTPS
- Custom servers must have valid SSL certificates

### Signature Verification
- Sparkle automatically verifies signatures
- Users cannot install updates without valid signatures
- Invalid signatures will be rejected by macOS Gatekeeper

## Troubleshooting

### Update Not Detected
1. Check `SUFeedURL` in Info.plist is correct
2. Verify `appcast.xml` is accessible via browser
3. Check signature is valid (not placeholder)
4. Verify version numbers are incrementing

### Download Fails
1. Check DMG URL in `appcast.xml` is correct
2. Verify DMG is publicly accessible
3. Check file permissions on hosting server
4. Ensure DMG is properly signed and notarized

### Signature Invalid
1. Verify you're using the correct private key
2. Check the signature was copied correctly
3. Ensure no extra whitespace in signature
4. Test with a fresh signature generation

## Maintenance

### Regular Updates
1. Build new release with incremented version
2. Sign with private key
3. Update `appcast.xml` with new version info
4. Upload new DMG to releases
5. Update appcast on hosting server

### Version Numbering
- Use semantic versioning (e.g., 1.0.0, 1.0.1, 1.1.0)
- Update both `CFBundleShortVersionString` and `CFBundleVersion`
- Ensure version numbers increment for each release

## Support

For issues with:
- **Sparkle framework:** https://sparkle-project.org/documentation/
- **GitHub Pages:** https://docs.github.com/en/pages
- **App signing:** https://developer.apple.com/support/code-signing/

## Example Appcast

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Ora Browser Changelog</title>
        <description>Most recent changes with links to updates.</description>
        <language>en</language>
        <item>
            <title>Ora Browser 0.0.1</title>
            <description>
                <![CDATA[
                <h2>Initial Release</h2>
                <p>Ora Browser is a fast, secure, and beautiful browser built for macOS.</p>
                <ul>
                    <li>Native macOS UI built with SwiftUI</li>
                    <li>Fast browsing powered by WebKit</li>
                    <li>Privacy-first with built-in content blocker</li>
                </ul>
                ]]>
            </description>
            <pubDate>Thu, 04 Sep 2025 14:51:08 +0000</pubDate>
            <enclosure url="https://github.com/the-ora/browser/releases/download/v0.0.1/Ora-Browser.dmg"
                       sparkle:version="1"
                       sparkle:shortVersionString="0.0.1"
                       length="26254848"
                       type="application/octet-stream"
                       sparkle:dsaSignature="YOUR_ACTUAL_SIGNATURE_HERE"/>
        </item>
    </channel>
</rss>
```

---

**Last Updated:** September 4, 2025
**Ora Browser Version:** 0.0.1</content>
</xai:function_call: write>
<parameter name="filePath">/Users/keni/code/ora/browser/docs/HOSTING_SETUP.md