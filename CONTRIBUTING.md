# Contributing to Audiobookphile Mobile App

Thank you for your interest in contributing to the Audiobookphile Mobile App! This application provides a native, cross-platform mobile experience for iOS and Android built with Swift, SwiftUI, and [Skip](https://skip.dev).

---

## Code of Conduct

All contributors and participants are expected to adhere to the [Code of Conduct](./CODE_OF_CONDUCT.md).

---

## Architecture & Cross-Platform Rules

1. **Unified Swift Codebase**: The entire app is written in Swift and SwiftUI. The [Skip framework](https://skip.dev) transpiles the business logic and SwiftUI views into native Kotlin and Jetpack Compose for Android.
2. **Platform Divergence Safety**:
   - Always avoid iOS-exclusive proprietary APIs unless wrapped with `#if !SKIP` compiler directives.
   - When introducing platform-specific native functionality (e.g., WidgetKit on iOS or AppWidgets on Android), provide clean parallel implementations for both platforms.
3. **Keychain & State Security**: User tokens and sensitive credentials must always be stored in the platform Keychain (iOS) or EncryptedSharedPreferences (Android).

---

## Getting Started

### Prerequisites

- macOS running with **Xcode 15+** installed.
- **Skip CLI**: Install via Homebrew:
  ```bash
  brew install skiptools/skip/skip
  ```
- **Android Studio & Android SDK** (for Android build and testing).
- **Bun** (for design token synchronization).

### Development Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Audiobookphile/audiobookphile-app.git
   cd audiobookphile-app
   ```

2. **Configure environment:**
   ```bash
   cp Skip.env.example Skip.env
   ```
   Edit `Skip.env` to configure your Supabase URL, Anon Key, and local developer settings.
   > **Note:** Never commit `Skip.env` to git.

3. **Open and Run in Xcode:**
   Open `Package.swift` in Xcode. Select an iOS simulator or Android emulator and press Run (`Cmd + R`).

4. **Verify Skip Transpilation:**
   Run the Skip test suite to ensure Swift-to-Kotlin transpilation succeeds:
   ```bash
   skip test
   ```

---

## Submitting a Pull Request

1. **Create a topic branch:**
   ```bash
   git checkout -b feat/your-feature-name
   ```
2. **Follow Conventional Commits:**
   - `feat(player): add sleep timer custom interval`
   - `fix(downloads): improve offline cache resilience`
   - `chore(deps): update Skip packages`
3. **Push to your fork and submit a PR:**
   - Describe the changes and indicate whether they affect iOS, Android, or both.
   - Include screenshots or screen recordings for any visual changes.
