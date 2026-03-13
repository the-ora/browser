# Contributing to Ora

This guide covers the workflow and expectations for contributing to Ora Browser.

## Before You Start

- Search existing issues and pull requests before starting work.
- For large features, architecture changes, or user-facing behavior changes, open an issue first so the approach can be discussed.
- Keep pull requests focused. Small, reviewable changes move faster than broad refactors.

## Development Setup

### Requirements

- macOS 15 or later
- Xcode 15 or later
- Homebrew

### Getting Started

```bash
git clone https://github.com/the-ora/browser.git
cd browser
./scripts/setup.sh
open Ora.xcodeproj
```

The setup script installs required tooling, installs git hooks, and generates the Xcode project.

If you change project configuration, edit `project.yml` and regenerate the project with:

```bash
xcodegen
```

## Development Workflow

1. Create a branch from `main`.
2. Make focused changes that follow the existing SwiftUI, AppKit, and WebKit patterns in the codebase.
3. Commit using conventional commit messages.
4. Open a pull request with a clear description of the change and its motivation.

## Code Quality

- `lefthook` installs the project hooks during setup.
- Pre-commit hooks run `swiftformat` and `swiftlint` on staged Swift files.
- Pre-push runs a debug build through `./scripts/xcbuild-debug.sh`.
- Prefer existing patterns and project structure over introducing new abstractions without a clear need.
- The current deployment target is macOS 15. Use availability checks if a change depends on newer APIs.
- Use the project logger instead of `print`.

You can run the main checks manually:

```bash
swiftformat . --quiet
swiftlint lint --fix
./scripts/xcbuild-debug.sh
xcodebuild test -scheme ora -destination "platform=macOS"
```

You can also run tests in Xcode with `Product > Test`.

## Pull Requests

Before opening a pull request, make sure the change builds cleanly and includes tests when behavior changes or new functionality is added.

Each pull request should:

- explain what changed and why
- reference related issues when applicable
- include screenshots or recordings for UI changes
- stay scoped to a single change where possible

## AI Assistance

If you use AI assistance for code generation, documentation, issue comments, or pull request content, disclose that use and describe the extent of the assistance. Contributors are still expected to understand and stand behind the submitted work.

## Security and Conduct

- Never commit secrets, signing keys, or other sensitive data.
- Review [SECURITY.md](SECURITY.md) for security-specific guidance.
- Follow the standards in [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Questions

If you are unsure whether a change is a good fit, open an issue before investing significant time. For general discussion, you can also join the [Discord community](https://discord.gg/9aZWH52Zjm).
