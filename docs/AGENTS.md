# 🤖 AI Agent Guidelines & Context Reference

Welcome! If you are an AI coding assistant (e.g., Antigravity, Claude, Copilot, or Gemini) working on this repository, **you must read and follow this document to ensure consistency, quality, and architectural parity.**

---

## 🎯 High-Level Context

This project is a **dual-platform Skip (Swift/Kotlin) application** — a premium, serverless audiobook and podcast client for the Audiobookphile ecosystem, built natively for iOS and Android. The codebase descends from the [Audiobookshelf iOS client](https://github.com/advplyr/audiobookshelf-app) but is a **standalone project**: it no longer tracks upstream and does not target self-hosted Audiobookshelf servers.

### The Source of Truth
The authoritative functional reference is the **Audiobookphile backend** ([audiobookphile-backend](https://github.com/Audiobookphile/audiobookphile-backend)) — a Supabase (Postgres + Auth + Storage) and Backblaze B2 stack served through the `api` edge function. Feature scope, endpoints, and payloads are defined there and in the API docs in this repo.

Your goal is to **deliver all Audiobookphile functionality** with the gorgeous, premium **Liquid Glass (LG)** native visual style.

---

## 🤖 Core Directives for Agents

### 1. Functional Parity & API Syncing
*   Refer to [docs/CRITICAL-FEATURES-REVIEW.md](file:///Users/organic/dev/work/audiobookphile/audiobookphile-app/docs/CRITICAL-FEATURES-REVIEW.md) and [docs/API-REFERENCE.md](file:///Users/organic/dev/work/audiobookphile/audiobookphile-app/docs/API-REFERENCE.md) for analyzed structures of the original Capacitor JS controllers.
*   Implement real-time progress syncing (REST fallback + Socket.io WebSockets) using the same events and thresholds as the official app (e.g., 4-second chapter threshold).
*   Handle token refreshes (automatic 401 handling with Keychain credentials storage) and cellular metered network restrictions seamlessly.

### 2. Serverless Supabase Backend
*   **ARCHITECTURE**: This client connects to the serverless Audiobookphile backend (Supabase + edge functions) — NOT a self-hosted Audiobookshelf Node.js server.
*   **Authentication**: The backend uses Supabase Auth via JWTs. Requests to `/api/*` must include `Authorization: Bearer <token>`.
*   **Storage Architecture**: The backend uses a Hybrid Storage approach:
    * Small files (< 25MB, e.g., covers) are stored in Supabase Storage (`supabase://`).
    * Large files (>= 25MB, e.g., audiobooks) are stored in Backblaze B2 (`b2://`).
*   **Playback API**: The `/api/playback/start` endpoint generates signed URLs dynamically based on the hybrid storage provider. Wait for these signed URLs before initializing the AVPlayer/ExoPlayer.

### 3. Premium Design System: Liquid Glass (LG)
*   Every screen must feel premium and visually impressive. Ensure that all SwiftUI/Compose components respect the visual identity defined in [docs/UI-UX-BENCHMARK.md](file:///Users/organic/dev/work/audiobookphile/audiobookphile-app/docs/UI-UX-BENCHMARK.md).
*   Avoid basic solid layouts. Use dynamic glassmorphism (ultra-thin material blurs, light-refracting borders, and floating particles), spring-based interactive transitions, and dominant color extractions from audiobook cover art.

### 4. The Skip Dual-Platform Paradigm
*   Write your main app code in Swift inside the `Sources/Audiobookphile` directory. Skip will compile and transpile this to native Kotlin/Jetpack Compose for Android.
*   Keep the transpilation bridge in mind. Check that your code compiles on both Swift and Kotlin targets.
*   Segregate any platform-specific code (e.g., AVFoundation and Android MediaPlayer hookups) using:
    ```swift
    #if os(iOS)
    // iOS/macOS native code
    #elseif SKIP
    // Kotlin/Android transpilation code
    #endif
    ```

### 5. Verification Workflow
*   Always test compilation and execution on the booted iOS Simulator (`iPhone 17 Pro` is currently booted and verified in the development environment).
*   Run validation builds using:
    ```bash
    xcodebuild build -workspace Project.xcworkspace -scheme "Audiobookphile App" -destination "platform=iOS Simulator,id=AA6E1A1D-4141-453D-9A5F-76BCA4834AE1"
    ```
*   Ensure Xcode package plugin security bypasses are enabled globally so that compiler scripts run uninterrupted:
    ```bash
    defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidations -bool YES
    defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidations -bool YES
    ```

---

## 📚 Key Reference Files
-   [docs/UI-UX-BENCHMARK.md](file:///Users/organic/dev/work/audiobookphile/audiobookphile-app/docs/UI-UX-BENCHMARK.md) — The visual and user flow benchmark guidelines.
-   [docs/CRITICAL-FEATURES-REVIEW.md](file:///Users/organic/dev/work/audiobookphile/audiobookphile-app/docs/CRITICAL-FEATURES-REVIEW.md) — Deep-dive code reviews of NuxtJS Capacitor structures mapped to Swift.
-   [docs/API-REFERENCE.md](file:///Users/organic/dev/work/audiobookphile/audiobookphile-app/docs/API-REFERENCE.md) — The API endpoint and payload specifications.
