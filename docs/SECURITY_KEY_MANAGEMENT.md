# Security & Key Management

Ora Browser uses Ed25519 cryptographic keys to sign and verify app updates for security:

## Public Key (Committed to Git)
- **File**: `ora_public_key.pem`
- **Purpose**: Verifies update signatures in the app
- **Status**: Committed to git repository
- **Safety**: Public keys are safe to share

## Private Key (Never Commit!)
- **File**: `.env` (contains `ORA_PRIVATE_KEY`)
- **Purpose**: Signs app updates during release
- **Status**: Never committed to git
- **Safety**: Keep secure and private

## Setup Process
1. **First machine**: Keys auto-generated and saved appropriately
2. **Additional machines**: Copy `.env` file from first machine
3. **Release process**: `./create-release.sh` handles key management automatically

## Security Notes
- `.env` is in `.gitignore` - it will never be committed
- Public key is committed - this is safe and required
- Never share your private key with anyone
- If private key is lost, you'll need to regenerate keys (breaks update chain)

## See Also
- [Release Process](RELEASE_PROCESS.md)
- [Hosting Setup](HOSTING_SETUP.md)
- [Security Guide](../SECURITY.md)