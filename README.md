<div align="center">
  <img width="270" height="270" src="/assets/icon.png" alt="Ora Browser Logo">
  <h1><b>Ora Browser</b></h1>
  <p>
    Ora is a fast, secure, and beautiful browser built for macOS. Inspired by Safari and Arc, Ora delivers a clean, native experience that feels at home on macOS—without unnecessary bloat.
    <br>
    <i>Compatible with macOS 14.0 and later</i>
  </p>
</div>

> **⚠️ Disclaimer**  
Ora is currently in early stages of development and **not yet ready for day-to-day use**. An alpha version with core functionalities will be released soon.

## Requirements

- **macOS 14.0** or later
- **Xcode 15** or later (Swift 5.9)
- **Homebrew** (for developer tooling)

If you would like to support the project, please consider donating via [Buy Me A Coffee](https://buymeacoffee.com/orabrowser).
[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://buymeacoffee.com/orabrowser)

## Features

### Core Capabilities

- Native macOS UI built with SwiftUI/AppKit
- Fast, responsive browsing powered by WebKit
- Privacy-first browsing with built-in content blocker for tracking prevention and ad blocking
- Multiple search engine support
- URL auto-completion and search suggestions
- Quick Launcher for instant navigation and search
- Developer mode

<details>
<summary><h2>Way to Beta Version</h2></summary>

- [x] Tab management with
  - containers (spaces),
  - pinning and reordering
  - floating tab switcher
  - [ ] auto-closing
- [x] Vertical Sidebar
- [x] Session restore after app restart or crash
- [x] Keyboard shortcuts for navigation and tabs
- [x] Picture in Picture
- [x] Developer Tools
- [ ] Download manager with pause/resume support
- [ ] iCloud Keychain password autofill
- [ ] Private browsing mode
- [ ] Bookmark management with folders and search
- [ ] Extensions — (App Store & Chrome extensions)
- [ ] Split tabs — multiple tabs open side by side
- [ ] Reader mode with adjustable font and themes
- [ ] Web notifications

</details>


## Security

Ora Browser uses cryptographic signing for secure updates. See [Security & Key Management](docs/SECURITY_KEY_MANAGEMENT.md) for details.

## Installation

1. Clone the repository.

```
git clone https://github.com/the-ora/browser.git
cd browser
```

2. Run the setup script to install tools, configure git hooks, and generate the Xcode project:
   ```bash
   ./setup.sh
   ```
3. Open in Xcode and run:
   ```bash
   open Ora.xcodeproj
   ```
   - In Xcode: select the `ora` scheme and Run (⌘R). Build (⌘B). Test (⌘U).

### Command-line build (optional)

- Debug build via helper script (uses `xcodebuild`; piping to `xcbeautify` if installed):
  ```bash
  ./xcbuild-debug.sh
  ```
  If you do not have `xcbeautify`, remove the final pipe or install it via Homebrew.

## Project structure

```
browser/
├─ ora/                             # application sources
│  ├─ Modules/                      # feature modules (Browser, Launcher, Find, Settings, Sidebar, SplitView, EmojiPicker, TabSwitch)
│  ├─ UI/                           # shared, reusable UI components
│  ├─ Services/                     # app-wide services (TabManager, HistoryManager, DownloadManager, PrivacyService, SearchEngineService)
│  ├─ Common/                       # shared resources, extensions, constants, representables, utilities
│  ├─ Models/                       # SwiftData models and related data
│  ├─ Resources/                    # app resources and auxiliary files
│  ├─ Assets.xcassets/              # asset catalog
│  ├─ Capsule.xcassets/             # asset catalog
│  └─ oraApp.swift                  # app entry point
├─ project.yml                      # XcodeGen project definition
├─ .swiftformat                     # formatting configuration
├─ .githooks/                       # git hooks (pre-commit, pre-push)
├─ setup.sh                         # tooling bootstrap and project generation
├─ xcbuild-debug.sh                 # CLI debug build helper
├─ LICENSE.md                       # license
├─ oraTests/                        # unit tests
└─ oraUITests/                      # UI tests
```

## Data and persistence

The app uses SwiftData with a single `ModelContainer` storing `TabContainer`, `History`, and `Download` models. The default store is under the app's Application Support directory as `OraData.sqlite`.

To reset the local store during development, you can delete the file under Application Support. Example path (your user folder will vary):

```bash
rm -f "$(getconf DARWIN_USER_DIR 2>/dev/null || echo "$HOME/Library/Application Support")/OraData.sqlite"*
```

> **⚠️ Caution: Use with care—this permanently clears tabs/history/download metadata.**

## Development

### Formatting and linting

- Run formatting:
  ```bash
  swiftformat . --quiet
  ```
- Run linting:
  ```bash
  swiftlint --quiet
  ```
- Pre-commit hook runs both automatically (installed by `./setup.sh`).

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

### Regenerating the Xcode project

- Update `project.yml` as needed, then:
  ```bash
  xcodegen
  ```

### Running tests

- In Xcode: Product → Test (⌘U)
- Via CLI:
  ```bash
  xcodebuild test -scheme ora -destination "platform=macOS"
  ```

Keyboard shortcuts: see `ora/Common/Constants/KeyboardShortcuts.swift`.

## Documentation

- **[Quick Start Guide](docs/QUICK_START.md)** - 5-minute setup for hosting and updates
- **[Hosting Setup Guide](docs/HOSTING_SETUP.md)** - Complete guide for update hosting and deployment
- **[Documentation Index](docs/README.md)** - All documentation organized by topic

## Contributing

Contributions are welcome! To propose changes:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m 'Add some feature'`
4. Push the branch: `git push origin feature/my-feature`
5. Open a Pull Request

## Troubleshooting

- XcodeGen, SwiftFormat, or SwiftLint not found
  - Run `./setup.sh` or install via Homebrew: `brew install xcodegen swiftformat swiftlint`
- Code signing issues (CLI builds)
  - The helper script disables signing for Debug builds. In Xcode, use automatic signing or adjust target settings.
- Missing `Ora.xcodeproj`
  - Run `xcodegen` (or `./setup.sh`) to regenerate from `project.yml`.
- CLI build output is hard to read
  - Install `xcbeautify` (`brew install xcbeautify`) and keep the pipe in `xcbuild-debug.sh`.

## Contact

Questions or support? Join the community on [Discord](https://discord.gg/9aZWH52Zjm).

## License

Ora is open source and licensed under the [MIT License](LICENSE.md).  
Feel free to use, modify, and distribute it under the terms of the MIT License.
Ora is open source and licensed under the [MIT License](LICENSE.md).  
Feel free to use, modify, and distribute it under the terms of the MIT License.
