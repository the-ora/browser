# Ora Browser Documentation

This directory contains documentation for Ora Browser development, deployment, and maintenance.

## 📚 Documentation Index

### 🚀 Getting Started
- **[QUICK_START.md](QUICK_START.md)** - 5-minute setup guide for hosting and updates
- **[../README.md](../README.md)** - Main project README with installation instructions

### 📦 Hosting & Deployment
- **[HOSTING_SETUP.md](HOSTING_SETUP.md)** - Complete guide for setting up update hosting
- **[../.github/workflows/release.yml](../.github/workflows/release.yml)** - GitHub Actions for automated releases

### 🔧 Development
- **[../ora/Services/UpdateService.swift](../ora/Services/UpdateService.swift)** - Update service implementation
- **[../ora/Modules/Settings/Sections/GeneralSettingsView.swift](../ora/Modules/Settings/Sections/GeneralSettingsView.swift)** - Settings UI with update controls
- **[../project.yml](../project.yml)** - XcodeGen project configuration

### 🏗️ Build & Release
- **[../build-release.sh](../build-release.sh)** - Release build script
- **[../create-release.sh](../create-release.sh)** - Complete release creation script (auto-increments versions)
- **[../setup-sparkle.sh](../setup-sparkle.sh)** - Sparkle key generation setup

## 🎯 Key Files for Updates

### Configuration Files
- `appcast.xml` - Update feed (host publicly)
- `dsa_priv.pem` - Private key (keep secure!)
- `dsa_pub.pem` - Public key (add to app)

### App Files
- `Ora-Browser.dmg` - Release installer (upload to GitHub Releases)
- `ora/Services/UpdateService.swift` - Update checking logic
- `ora/Modules/Settings/Sections/GeneralSettingsView.swift` - Update UI

## 🔄 Update Flow

1. **Build:** `./create-release.sh` (auto-increments version) or `./create-release.sh 1.0.0` (manual version)
2. **Sign:** Use `dsa_priv.pem` to sign DMG
3. **Host:** Upload `appcast.xml` to public web server
4. **Release:** Upload DMG to GitHub Releases
5. **Configure:** Update `SUFeedURL` in app
6. **Test:** Users get automatic update notifications

## 📞 Support

- **Sparkle Documentation:** https://sparkle-project.org/documentation/
- **GitHub Pages:** https://docs.github.com/en/pages
- **Code Signing:** https://developer.apple.com/support/code-signing/

## 📝 Contributing

When updating documentation:
1. Keep `QUICK_START.md` for 5-minute setup
2. Use `HOSTING_SETUP.md` for detailed procedures
3. Update this README when adding new docs

---

**Ora Browser** | *Fast, secure, and beautiful browser for macOS*</content>
</xai:function_call: write>
<parameter name="filePath">/Users/keni/code/ora/browser/docs/README.md