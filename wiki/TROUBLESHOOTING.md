# Troubleshooting

Common issues and solutions when working with Ora.

## Development Issues

### XcodeGen, SwiftFormat, or SwiftLint not found
**Solution**: Run the setup script or install manually via Homebrew:
```bash
./setup.sh
# OR
brew install xcodegen swiftformat swiftlint
```

### Code signing issues (CLI builds)
**Solution**: The helper script disables signing for Debug builds. In Xcode, use automatic signing or adjust target settings.

### Missing `Ora.xcodeproj`
**Solution**: Run XcodeGen to regenerate from `project.yml`:
```bash
xcodegen
# OR
./setup.sh
```

### CLI build output is hard to read
**Solution**: Install `xcbeautify` to get prettier build output:
```bash
brew install xcbeautify
# The pipe is already configured in xcbuild-debug.sh
```

## Runtime Issues

### App won't start
- Check minimum macOS version (14.0+)
- Try deleting derived data in Xcode
- Clean build folder (⌘⇧K in Xcode)

### Database errors
- Try resetting the local database (see [Data Persistence](DATA_PERSISTENCE.md))
- Check Application Support directory permissions

## Build Issues

### Dependencies won't resolve
- Check internet connection
- Try deleting Package.resolved and re-resolving in Xcode
- Verify Sparkle package URL is accessible

### Git hooks not working
- Re-run setup script: `./setup.sh`
- Check git hooks permissions: `ls -la .githooks/`
- Manually install hooks if needed

## Getting Help

If these solutions don't work:
1. Check existing [GitHub Issues](https://github.com/the-ora/browser/issues)
2. Search the [Discord community](https://discord.gg/9aZWH52Zjm)
3. Open a new issue with detailed information