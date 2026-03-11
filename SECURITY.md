# Ora Browser Security Guide

## 🛡️ Reporting Security Vulnerabilities

If you discover a security vulnerability in Ora Browser, **please report it responsibly**.

**Email: [security@orabrowser.com](mailto:security@orabrowser.com)**

> **⚠️ Do NOT create a public issue, pull request, or discussion about security vulnerabilities.** Public disclosure gives attackers a window to exploit the issue before a fix is available. Always report security concerns privately via the email above.

When reporting, please include:
- A description of the vulnerability
- Steps to reproduce the issue
- Any relevant screenshots or logs
- The potential impact of the vulnerability

We will acknowledge your report promptly and work with you to understand and address the issue.

---

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