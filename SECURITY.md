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
3. **Release process**: `./scripts/create-release.sh` handles key management automatically

### Security Notes
- `.env` is in `.gitignore` - it will never be committed
- Public key is committed - this is safe and required
- Never share your private key with anyone
- If private key is lost, you'll need to regenerate keys (breaks update chain)

## 🔍 Security Checks

Run `./scripts/check-security.sh` to verify:
- Private key exists but is not tracked by git
- Public key is available for app integration
- `.gitignore` properly excludes sensitive files

## 🚨 Security Best Practices

- **NEVER** commit private keys to version control
- **NEVER** share private keys with anyone
- **NEVER** delete private keys once you've published releases (breaks update chain)
- Use secure methods to transfer keys between machines
- Regularly audit what's in your git staging area before committing

## 🚨 Security Violations

If you see any of these, stop immediately:
- Private key files appear in `git status`
- Private keys are committed to repository
- Private keys are shared or transmitted insecurely