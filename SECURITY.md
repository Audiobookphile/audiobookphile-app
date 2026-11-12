# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it by opening a [GitHub Security Advisory](https://github.com/Audiobookphile/audiobookphile-app/security/advisories/new) or by emailing the maintainer directly. All reports will be reviewed promptly.

Please include the following in your report:

- Type of issue (e.g., XSS, SQL injection, authentication bypass, insecure direct object reference)
- The affected file, component, or endpoint
- Step-by-step instructions to reproduce the issue
- Potential impact of the vulnerability

## Scope

This repository covers the native mobile application for iOS and Android (Swift/Skip).

### Key Security Boundaries

- Authentication sessions (access tokens and refresh tokens) are securely persisted in the platform Keychain (iOS) and EncryptedSharedPreferences (Android).
- Biometric authentication (Face ID / Touch ID / Passkeys) integrates with platform-level biometric prompts (`LocalAuthentication` / `BiometricManager`).
- Network requests communicate exclusively over HTTPS and WSS with App Transport Security (ATS) enforcement.
- Sentry telemetry is scrubbed of PII and can be completely disabled by leaving `SENTRY_DSN` empty in `Skip.env`.

## Supported Versions

Security updates are provided for the latest release on the `main` branch.

## Acknowledgements

We appreciate the work of security researchers who help keep this project and its users safe.
