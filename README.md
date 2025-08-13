## Ora Browser

Ora is a fast, secure, and beautiful browser built for macOS. Inspired by Safari and Arc, Ora delivers a clean, native experience that feels at home on macOS — without unnecessary bloat.

> **⚠️ Disclaimer**  
> Ora is currently in active development and **not yet ready for day-to-day use**.  
> An alpha version with core features will be released soon. Use at your own discretion.

## Features

### Core Capabilities

- Native macOS UI built with SwiftUI/AppKit
- Fast, responsive browsing powered by WebKit
- Privacy-first browsing with built-in content blocker for tracking prevention and ad blocking
- Multiple search engine support
- URL auto-completion and search suggestions
- Quick Launcher for instant navigation and search
- Developer mode

### Way to Beta Version

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

## Requirements

- macOS 14.0 or later
- Xcode 15 or later (Swift 5.9)
- Homebrew (for developer tooling)
- Tools: `xcodegen`, `swiftlint`, `swiftformat` (installed by the setup script)
- Optional: `xcbeautify` (for prettier CLI build output)

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
