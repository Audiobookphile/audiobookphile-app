# Audiobookphile Mobile App

Audiobookphile is a premium, serverless audiobook and podcast client that connects to the Audiobookphile ecosystem.

This mobile application is built natively for both **iOS** and **Android** using **Swift** and the [Skip framework](https://skip.dev). Skip allows us to write the app completely in Swift and SwiftUI, and it transpiles the logic and UI into native Kotlin/Compose for Android, providing a unified codebase with true native performance on both platforms.

<img alt="Screenshot" src="assets/audiobooth-audiobooks-player.png" />

## Architecture

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (iOS) / Compose (Android via Skip)
- **Backend:** Supabase (Postgres + Auth + Storage)
- **Cross-Platform Bridge:** Skip

## Prerequisites

To build and run this project, you need a macOS environment with the following installed:

1. **Xcode 15+** (for iOS development)
2. **Android Studio** and the Android SDK (for Android development)
3. **Homebrew** (for installing Skip tools)

## Getting Started

1. **Install the Skip CLI:**
   ```bash
   brew install skiptools/skip/skip
   ```

2. **Clone the Repository:**
   ```bash
   git clone https://github.com/Audiobookphile/audiobookphile-app.git
   cd audiobookphile-app
   ```

3. **Configure Environment Variables:**
   Copy the example environment file and fill in your Supabase configuration and Apple Developer Team ID:
   ```bash
   cp Skip.env.example Skip.env
   ```
   > **Note:** Do NOT commit your `Skip.env` to version control. It should remain ignored.

4. **Open the Project:**
   Open `Package.swift` in Xcode. Alternatively, open the generated `.xcodeproj` or `.xcworkspace`.

5. **Build and Run:**
   - **For iOS:** Select an iOS Simulator or connected device in Xcode and press Run (`Cmd + R`).
   - **For Android:** Ensure you have an Android emulator running or a device connected via ADB. Skip integrates with the Xcode build process to compile the Android app simultaneously.

## Localization

Thank you to [Weblate](https://hosted.weblate.org/engage/audiobookphile/) for hosting our localization infrastructure pro-bono. If you want to see Audiobookphile in your language, please help us localize. <a href="https://hosted.weblate.org/engage/audiobookphile/"> <img src="https://hosted.weblate.org/widget/audiobookphile/abs-mobile-app/horizontal-auto.svg" alt="Translation status" /> </a>

## Xcode Cloud Build Pipeline

The iOS client uses **Xcode Cloud** for automated TestFlight building and distribution. During the build process, a custom `ci_post_clone.sh` script dynamically generates a `Skip.env` file from Xcode Cloud environment variables.

To ensure your TestFlight builds are properly code-signed and connected to the correct Supabase instance, you **MUST** configure the following environment variables in your Xcode Cloud Workflow settings (under the **Environment** tab):

| Variable | Description |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Your Supabase Project API URL (e.g. `https://xxxx.supabase.co`) |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Your Supabase publishable anonymous key |
| `TEAM_ID` | Your 10-character Apple Developer Team ID (Required for code signing) |
| `PRODUCT_BUNDLE_IDENTIFIER` | Your app's Bundle ID (e.g. `club.yourdomain.audiobookphile`) |
| `SENTRY_DSN` | Optional. Enables crash/error reporting (Settings → opt-out toggle). Leave unset to ship without telemetry. |

If these are not set, the build will use generic fallback values which will cause code signing to fail.

## UI Tests (Maestro)

E2E UI tests live in `.maestro/flows/` and run on the iOS simulator (CI: `.github/workflows/mobile-e2e.yml`). See [docs/MAESTRO.md](docs/MAESTRO.md) for setup, credentials, and flow inventory. Run locally:

```bash
.maestro/run.sh smoke            # launch smoke tests (no credentials)
.maestro/run.sh e2e              # login + library + settings (needs .maestro/.env)
.maestro/run.sh                  # smoke + e2e (the CI set)
```

## Design Tokens

The shared design system lives at the monorepo root: `design-system/tokens.json` — edit and run `bun design-system/sync-design-tokens.mjs` to regenerate `Sources/Audiobookphile/Core/Design/DesignTokens.swift` and the web's `tokens.generated.css`. See `docs/design-tokens.md`.

## Credits

Audiobookphile's mobile client descends from the [Audiobookshelf iOS app](https://github.com/advplyr/audiobookshelf-app). We forked it in 2025 to build a serverless architecture (Supabase backend) that Audiobookshelf's self-hosted model never needed, and have since diverged significantly — this repository is a standalone project and no longer tracks upstream.

## Contributing

Pull requests are highly encouraged! When contributing to the Swift codebase, keep in mind that the code must be compatible with Skip's transpilation process. Avoid using iOS-only proprietary APIs unless you surround them with `#if !SKIP` compiler directives and provide an Android alternative.

Join us on [Discord](https://discord.gg/pJsjuNCKRq) to discuss features and development.
