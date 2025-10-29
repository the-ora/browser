# Ora Browser Quick Start - Hosting Setup

## 🚀 Quick Setup (5 minutes)

**Note:** The release script now auto-increments version numbers. Just run `./scripts/create-release.sh` without arguments for patch releases.

### 1. Setup Sparkle Tools
```bash
brew install --cask sparkle
./setup-sparkle-tools.sh
./scripts/setup-sparkle.sh
```

### 2. Build & Sign Release
```bash
# Auto-increment version (recommended)
./scripts/create-release.sh

# Or specify version manually
./scripts/create-release.sh 0.0.1
```

### 3. Host Files

#### Option A: GitHub Pages (Easiest)
```bash
# Create gh-pages branch
git checkout -b gh-pages
git rm -rf .
cp ../appcast.xml .
git add appcast.xml
git commit -m "Add appcast for updates"
git push origin gh-pages

# Enable in GitHub: Settings → Pages → Source: gh-pages
```

#### Option B: GitHub Releases
- Upload `Ora-Browser.dmg` to GitHub Releases
- Upload `appcast.xml` to any web host

### 4. Update App Config
Edit `project.yml`:
```yaml
settings:
  base:
    SUFeedURL: https://the-ora.github.io/browser/appcast.xml
    SUPublicEDKey: YOUR_PUBLIC_KEY_HERE
```

### 5. Test
```bash
xcodegen
# Build and run app
# Go to Settings → General → Check for Updates
```

## 📋 What Gets Hosted Where

| File | Location | Purpose |
|------|----------|---------|
| `build/appcast.xml` | Public web server | Update feed for Sparkle |
| `build/Ora-Browser.dmg` | GitHub Releases | App installer download |
| `build/dsa_pub.pem` | App bundle | Public key for verification |

## 🔗 URLs You'll Need

- **Appcast:** `https://the-ora.github.io/browser/appcast.xml`
- **DMG:** `https://github.com/the-ora/browser/releases/download/v{VERSION}/Ora-Browser.dmg`
- **Public Key:** Copy from `dsa_pub.pem`

## ✅ Checklist

- [ ] DSA keys generated (`dsa_priv.pem`, `dsa_pub.pem`)
- [ ] Release built and signed (`Ora-Browser.dmg`)
- [ ] Appcast updated with real signature
- [ ] Appcast hosted at public URL
- [ ] DMG uploaded to GitHub Releases
- [ ] `SUFeedURL` updated in app
- [ ] `SUPublicEDKey` added to app
- [ ] Xcode project regenerated

## 🆘 Need Help?

- **Keys not working:** Run `./scripts/setup-sparkle.sh` again
- **Signature invalid:** Use `sign_update` command output exactly
- **Update not found:** Check `SUFeedURL` in Info.plist
- **DMG won't download:** Verify GitHub release is public

See `docs/HOSTING_SETUP.md` for detailed instructions.</content>
</xai:function_call: write>
<parameter name="filePath">/Users/keni/code/ora/browser/docs/QUICK_START.md