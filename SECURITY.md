# Ora Browser Security Guide

## 🔐 Update Key Management

Ora Browser uses Ed25519 cryptographic keys to sign and verify app updates for security.

### Public Key (Committed to Git)
- **File**: `ora_public_key.pem`
- **Purpose**: Verifies update signatures in the app
- **Status**: Committed to git repository
- **Safety**: Public keys are safe to share

### Private Key (Never Commit!)
- **File**: `.env` (contains `ORA_PRIVATE_KEY`)
- **Purpose**: Signs app updates during release
- **Status**: Never committed to git
- **Safety**: Keep secure and private

### Setup Process
1. **First machine**: Keys auto-generated and saved appropriately
2. **Additional machines**: Copy `.env` file from first machine
3. **Release process**: `./create-release.sh` handles key management automatically

### Security Notes
- `.env` is in `.gitignore` - it will never be committed
- Public key is committed - this is safe and required
- Never share your private key with anyone
- If private key is lost, you'll need to regenerate keys (breaks update chain)

## 🔐 DSA Key Management

### Private Key Security
- **NEVER** commit `build/dsa_priv.pem` to version control
- **NEVER** share the private key with anyone
- **NEVER** delete the private key once you've published releases with it

### Key Generation & Reuse
- Generate DSA keys **once** when setting up Sparkle updates
- **Reuse the same keys** for all future releases
- Deleting and regenerating keys will break the update chain for existing users

### Security Checks
Run `./check-security.sh` to verify:
- Private key exists but is not tracked by git
- Public key is available for app integration
- `.gitignore` properly excludes sensitive files

### Release Process
1. Run `./create-release.sh <version>` - reuses existing keys automatically
2. Upload `build/Ora-Browser.dmg` to GitHub releases
3. Host `build/appcast.xml` at a public URL
4. Add `build/dsa_pub.pem` content to app's `SUPublicEDKey` in Info.plist

### Files to Keep Secure
- `build/dsa_priv.pem` - **KEEP PRIVATE, NEVER COMMIT**
- `build/dsa_pub.pem` - Safe to commit if needed for CI/CD
- `build/appcast.xml` - Contains signatures, safe to host publicly

### Emergency Key Regeneration
If private key is compromised:
1. Delete `build/dsa_priv.pem` and `build/dsa_pub.pem`
2. Run `./create-release.sh <new-version>` to generate fresh keys
3. Update app's `SUPublicEDKey` with new public key
4. Existing users will need to download fresh installers

## 🚨 Security Violations
If you see any of these, stop immediately:
- `dsa_priv.pem` appears in `git status`
- Private key is committed to repository
- Private key is shared or transmitted insecurely