# Contributing to Ora 

## 🚀 Development Setup

### Prerequisites

- **macOS 14.0** or later
- **Xcode 15** or later (Swift 5.9)
- **Homebrew** (for developer tooling)

### Getting Started

1. Fork the repository and clone your fork:
   ```bash
   git clone https://github.com/the-ora/browser.git
   cd browser
   ```

2. Run the setup script to install tools, configure git hooks, and generate the Xcode project:
   ```bash
   ./setup.sh
   ```

3. Open in Xcode and build:
   ```bash
   open Ora.xcodeproj
   ```
   In Xcode: select the `ora` scheme and Run (⌘R)

## 📝 Code Style & Standards

### Formatting & Linting

Code formatting and linting are automatically enforced via git hooks (installed by `./setup.sh`):

- **SwiftFormat**: Handles code formatting
- **SwiftLint**: Enforces coding standards

You can run these manually:
```bash
swiftformat . --quiet
swiftlint --quiet
```

### Conventions

- Follow existing SwiftUI/AppKit patterns in the codebase
- Use the established file organization structure
- **Prefer modern Swift/SwiftUI APIs** when possible

### Compatibility & OS Versions

- **Maintain backward compatibility**: The current minimum deployment target is **macOS 14.0**
- New features requiring newer OS versions should use `@available` or `#if available` checks to preserve compatibility
- **Discuss before raising minimum version**: If a feature would significantly benefit from raising the minimum OS version, open an issue to discuss the trade-offs before implementation

### Project Configuration

This project uses **XcodeGen**. If you need to modify project settings:

1. Edit `project.yml`
2. Regenerate the project: `xcodegen`

## 🧪 Testing & Quality

### Running Tests

- **In Xcode**: Product → Test (⌘U)
- **Via CLI**:
  ```bash
  xcodebuild test -scheme ora -destination "platform=macOS"
  ```

### Requirements

- All new features should include appropriate tests
- Existing tests must continue to pass
- Code should build without warnings

## 🔒 Security & Safety

- **Never commit private keys or sensitive data** - see [SECURITY.md](SECURITY.md) for details
- Be mindful of user privacy and data handling
- Follow secure coding practices for web content handling

## 📋 Pull Request Process

### Before You Start

1. **Check for duplicates**: Search existing issues and PRs to ensure no one is already working on the same feature or bug
2. **Avoid duplicate work**: Comment on relevant issues to indicate you're working on them
3. For major changes, consider opening an issue first to discuss the approach

### Submitting Changes

1. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes, ensuring:
   - Code follows style guidelines (enforced by git hooks)
   - Tests pass
   - New functionality includes tests where appropriate

3. Commit your changes with clear, descriptive messages

4. Push to your fork and create a Pull Request

### PR Requirements

- [ ] Code builds successfully
- [ ] Tests pass
- [ ] Code follows formatting standards (automatic via git hooks)
- [ ] **Descriptive title and description**: Clearly explain what changes were made and why
- [ ] References related issues if applicable
- [ ] No duplicate functionality (checked existing codebase)

## 🐛 Issue Reporting

### Bug Reports

**Be descriptive and thorough**. Include:
- macOS version
- Ora Browser version
- Clear steps to reproduce the issue
- Expected vs actual behavior
- Screenshots if applicable
- Relevant console/error messages

### Feature Requests

**Provide detailed context**. Include:
- Clear description of the feature and its use case
- Explain how it fits with Ora's goals (fast, secure, beautiful)
- Consider implementation complexity and user impact
- Check that similar functionality doesn't already exist

## 💬 Community Guidelines

- Be respectful and constructive
- Help maintain a welcoming environment for all contributors
- Focus on the code and ideas, not individuals

## 📚 Additional Resources

- [Security Guide](SECURITY.md) - Key management and security practices
- [Wiki](wiki/) - Comprehensive project documentation
- [Quick Start Guide](wiki/QUICK_START.md) - 5-minute setup for releases/updates

## Release Process

### Releases and Updates

Ora uses [Sparkle](https://sparkle-project.org/) for automatic updates. All build artifacts are organized in the `build/` directory.

1. **Add Sparkle dependency:**
   - Open `Ora.xcodeproj` in Xcode
   - Go to File → Add Packages...
   - Add `https://github.com/sparkle-project/Sparkle` (version 2.6.3+)
   - Add Sparkle to your target

2. **Setup Sparkle tools:**
   ```bash
   brew install --cask sparkle
   ./setup-sparkle-tools.sh
   ./setup-sparkle.sh
   ```
   This generates DSA keys in `build/` directory.

3. **Configure signing:**
   - Copy the public key from `build/dsa_pub.pem` to your `Info.plist` as `SUPublicEDKey`
   - Keep `build/dsa_priv.pem` secure for signing releases
   - Add `SUFeedURL` to Info.plist pointing to your appcast.xml URL

4. **Create a release:**
   ```bash
   ./create-release.sh 0.0.2 build/dsa_priv.pem
   ```
   This builds, signs, and prepares release files in `build/`.

5. **Host appcast.xml:**
   - Upload `build/appcast.xml` to a public URL (e.g., GitHub Pages)
   - Update `SUFeedURL` in `Info.plist` to point to your appcast.xml

6. **Publish release:**
   - Upload `build/Ora-Browser.dmg` to GitHub releases
   - Users will automatically receive update notifications

The app includes automatic update checking in Settings > General.

### Release Requirements

- [ ] Version number incremented appropriately
- [ ] All tests pass
- [ ] Code is properly signed
- [ ] Appcast.xml is updated with correct signatures
- [ ] DMG is uploaded to GitHub releases

For detailed hosting setup, see [wiki/HOSTING_SETUP.md](wiki/HOSTING_SETUP.md).

## Questions?

Join the community on [Discord](https://discord.gg/9aZWH52Zjm) or open an issue for discussion.

---

By contributing to Ora Browser, you agree that your contributions will be licensed under the [MIT License](LICENSE.md).
