# 🗺️ Ora Browser Roadmap

Ora Browser is currently in **early development**.  
This roadmap tracks progress toward the **Beta** milestone and beyond.

> Goal: A stable, privacy-first macOS browser with a clean native interface.

# Known issues
- [] WebViews are stacked on top of eachother to avoid UI jumping round. To acheive this opacity 0|1 is used but this creates an issue where mouse hovering over a certain webview will trigger text in title attributes of webviews wthat are hidden under it.
- [] Dragging tabs around is not smooth and can produce empty tabs or weird spacings
- [] Favicons are selected from webpages according to size, there is no logic for selecting favicons based on theme or other options
- [] When a WebView is restored if there was developer tools open it won't neither open the dev tools or adject it's size back to the way it was
- [] The try again button after a page fails to load doesn't do anything
- [] If Ora is set as the default browser and is closed when a link is clicked on other apps, it won't create a new window properly.
- 
---

## Beta Feature Targets

Below is the list of core features planned or completed for the Beta release.

### Tabs & Navigation
- [x] Spaces (containers)
- [x] Pinning and reordering
- [x] Floating tab switcher
- [x] Auto-closing inactive tabs

### Interface & Layout
- [x] Vertical tabs (sidebar)
- [x] Picture in Picture
- [ ] Split tabs (side-by-side view)
- [ ] Peek webview
- [ ] Settings
- [ ] History - [#130](https://github.com/the-ora/browser/pull/130)

### Stability & Performance
- [x] Session restore after app restart or crash
- [ ] Download manager with pause/resume support

### Privacy & Security
- [x] Private browsing mode
- [ ] iCloud Keychain password autofill
- [x] Passkeys
- [ ] Permissions [#48](https://github.com/the-ora/browser/pull/49)
- [ ] Ad Blocker
- [ ] Fingerprint

### Personalization
- [ ] Bookmark management with folders

### Developer Features
- [x] Developer Tools
- [ ] Extensions — Safari & Chrome extensions (beta) [#137](https://github.com/the-ora/browser/pull/137)

### System Integration
- [ ] Web notifications

### Power User Features
- [x] Keyboard shortcuts for navigation and tabs

---

## Milestones

| Phase | Status | Focus |
|--------|---------|--------|
| **Alpha (Current)** | 🟢 Active | Core browsing, tabs, session management, and core UIs |
| **Beta 1** | 🟡 Soon | Autofill, bookmarks(folders), downloads, peek, split tab views and more |
| **Stable 1.0** | ⚪ Future | Full extensions support, performance, UI polish |

---

## Post‑Beta Plans
- [ ] Full extensions ecosystem
- [ ] Theming

---

## 🤝 Contributing & Feedback
- 💬 Join discussions on [Discord](https://discord.gg/9aZWH52Zjm)  
- 💡 Suggest features or discuss roadmap items in our discord
- 📘 See [CONTRIBUTING.md](./CONTRIBUTING.md) for setup instructions

---

_Last updated: October 2025_
