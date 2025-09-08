# Releases and Updates

Ora uses [Sparkle](https://sparkle-project.org/) for automatic updates to provide users with seamless, secure updates.

## How It Works

### Update System Architecture
- **Sparkle Framework**: Handles automatic update checking and installation
- **Cryptographic Signing**: Updates are signed with Ed25519 keys for security
- **Appcast Feed**: XML feed that tells the app about available updates
- **Background Checks**: App periodically checks for updates automatically

### User Experience
- Updates are checked automatically in the background
- Users see update notifications when new versions are available
- Updates can be triggered manually in Settings > General
- Installation is seamless - users just click "Install and Restart"

### Security
- All updates are cryptographically signed to prevent tampering
- Users can't install unsigned or malicious updates
- The signing process ensures updates come from trusted sources

## File Structure

Updates involve these key files:
- `appcast.xml` - Update feed (hosted publicly)
- `Ora-Browser.dmg` - App installer (hosted on GitHub Releases)
- `ora_public_key.pem` - Public key for verification (in app bundle)
- Private key - Signs updates (kept secure, never committed)

## For Developers

See the [Release Process section in CONTRIBUTING.md](../CONTRIBUTING.md#release-process) for technical details on creating releases.

## Related Documentation

- [Hosting Setup Guide](HOSTING_SETUP.md) - Complete guide for update hosting
- [Quick Start Guide](QUICK_START.md) - 5-minute setup for releases  
- [Security Guide](../SECURITY.md) - Key management and security practices