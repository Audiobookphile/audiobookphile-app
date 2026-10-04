# Audiobookphile Privacy Policy

**Effective Date:** 2026-08-12

Audiobookphile is a completely free and open-source application designed to interface with your own self-hosted Audiobookphile ecosystem. We believe your library is your private property.

## 1. Data Collection
**We collect no personal data.** Audiobookphile does not contain any third-party tracking APIs, analytics SDKs, or advertising technology. We do not track your reading habits, IP address, or usage statistics.

## 2. Crash Reporting (Opt-out)
To keep the app reliable, Audiobookphile may send **anonymous crash and error reports** to Sentry (sentry.io) when the app crashes or fails. These reports contain:
- A random, salted installation ID (never your email or device serial)
- The crash/error message and stack trace
- App version and platform

No library contents, book titles, playback history, or account identifiers are included. Reports are disabled when the app is built without a Sentry configuration, and you can disable them at any time from the app's Settings screen.

## 3. Server Communication
The app only communicates directly with the URL of the self-hosted Audiobookphile backend that you explicitly provide. No data is ever routed through, intercepted by, or stored on our servers, because we do not have any servers.

## 4. Local Storage (UserDefaults)
To function, the app stores your server URL, authentication tokens (if applicable), and local preferences (like playback speed or sleep timer configurations) securely on your device using Apple's standard `UserDefaults` and `Keychain` APIs. This data never leaves your device except to communicate with your specified server.

## 5. Open Source Transparency
Our entire codebase is public. You can verify every line of code to ensure there are no hidden trackers by visiting our [GitHub Repository](https://github.com/Audiobookphile/audiobookphile-app).

## 6. Contact
If you have any questions or concerns about this privacy policy, please open an issue on our GitHub repository.
