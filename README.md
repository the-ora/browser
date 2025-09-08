<div align="center">
  <img width="250" height="250" src="/assets/icon.png" alt="Ora Browser Logo">
  <h1><b>Ora Browser</b></h1>
  <p>
    Ora is a fast, secure, and beautiful browser built for macOS. Inspired by Safari and Arc, Ora delivers a clean, native experience that feels at home on macOS—without unnecessary bloat.
    <br>
    <i>Compatible with macOS 14.0 and later</i>
  </p>
</div>

<p align="center">
    <a href="https://www.apple.com/macos/"><img src="https://badgen.net/badge/macOS/14+/blue" alt="macOS"></a>
    <a href="https://developer.apple.com/xcode/"><img src="https://badgen.net/badge/Xcode/15+/blue" alt="Xcode"></a>
    <a href="https://swift.org"><img src="https://badgen.net/badge/Swift/5.9/orange" alt="Swift Version"></a>
    <a href="https://brew.sh"><img src="https://badgen.net/badge/Homebrew/required/yellow" alt="Homebrew"></a>
    <a href="LICENSE.md"><img src="https://badgen.net/badge/License/MIT/green" alt="License: MIT"></a>
</p>

> **⚠️ Disclaimer**  
Ora is currently in early stages of development and **not yet ready for day-to-day use**. An alpha version with core functionalities will be released soon.

## Support

If you would like to support the project, please consider donating:

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://buymeacoffee.com/orabrowser)

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

## Wiki

See the [Wiki](wiki/) for comprehensive documentation, guides, and project information.

## Installation

1. Clone the repository and run setup:
   ```bash
   git clone https://github.com/the-ora/browser.git
   cd browser
   ./setup.sh
   ```

2. Open and build:
   ```bash
   open Ora.xcodeproj
   ```

For detailed setup instructions, see [CONTRIBUTING.md](CONTRIBUTING.md).


## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code style guidelines, and pull request process.

Also see our [Code of Conduct](CODE_OF_CONDUCT.md) for community guidelines.


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

## Contact

Questions or support? Join the community on [Discord](https://discord.gg/9aZWH52Zjm).

## License

Ora is open source and licensed under the [MIT License](LICENSE.md).  
Feel free to use, modify, and distribute it under the terms of the MIT License.
