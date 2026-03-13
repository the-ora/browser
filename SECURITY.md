# Security

This document covers the repository-specific security expectations for Ora Browser contributors and maintainers.

## Secrets and Sensitive Data

- Never commit `.env`, signing credentials, private keys, notarization credentials, or any other secret material.
- Do not paste secrets into issues, pull requests, screenshots, or logs shared publicly.
- Keep local release credentials in `.env` and use `.env.example` as the template for required variables.
- Treat generated logs and exported artifacts as potentially sensitive until reviewed.

## Update Signing

Ora uses Sparkle update signing.

- `ora_public_key.pem` is the public verification key and is safe to keep in the repository.
- `ORA_PRIVATE_KEY` is the private signing key used when generating the Sparkle appcast and must never be committed or shared.
- If the private signing key is lost or replaced after releases have shipped, the existing update trust chain is broken.

## Release Credentials

The release scripts expect credentials in a local `.env` file. Depending on the workflow, this includes:

- `ORA_PRIVATE_KEY`
- `APPLE_ID`
- `TEAM_ID`
- `DEVELOPMENT_TEAM`
- `APP_SPECIFIC_PASSWORD_KEYCHAIN`
- `SIGNING_IDENTITY`
- `DEVELOPER_ID_PROFILE`

For the current release flow, see:

- `./scripts/build.sh`
- `./scripts/publish.sh`
- `./scripts/release.sh`

Contributors working on regular code or documentation changes should not need access to release credentials.

## Safe Working Practices

- Review `git status` and `git diff --cached` before every commit.
- Do not add private keys, provisioning profiles, or notarization credentials to the repository, even temporarily.
- Be careful when sharing crash logs, build logs, and environment output if they may include local paths, account identifiers, or signing details.
- Follow least-privilege access for Apple Developer and release infrastructure credentials.

## Reporting Security Issues

If you discover a security issue or accidental secret exposure, do not open a public issue with exploit details or credential contents. Contact the maintainers privately through the project Discord so the issue can be handled without further exposure.
