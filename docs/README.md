# Audiobookphile Mobile Client Documentation 📱

Welcome to the documentation for [`audiobookphile-app`](https://github.com/Audiobookphile/audiobookphile-app), the native dual-platform (iOS & Android) mobile client for the Audiobookphile ecosystem.

---

## 🎯 Architecture & Technology

Audiobookphile App is built natively in **Swift** and **SwiftUI**, compiled for iOS and transpiled to Kotlin / Jetpack Compose for Android using **Skip**.

- **iOS Target**: Native Swift, AVFoundation, iOS Liquid Glass design, Dynamic Island, Lock Screen widgets, Siri App Intents.
- **Android Target**: Native Kotlin / Jetpack Compose via Skip transpilation.
- **Backend**: Connects directly to the serverless Audiobookphile Supabase backend and Backblaze B2 streaming storage.
- **Production Status**: Version `1.0` (Build `302`) in App Store Connect (`WAITING_FOR_REVIEW`).

---

## 📚 Documentation Index

### Core Architecture & Developer Guides
- [**AI Agent Context (`AGENTS.md`)**](./AGENTS.md) - Deep guidelines, architectural constraints, and Skip transpilation rules for AI assistants.
- [**API Reference (`API-REFERENCE.md`)**](./API-REFERENCE.md) - Backend endpoint mapping, audio streaming payloads, and sync thresholds.
- [**Critical Features Review (`CRITICAL-FEATURES-REVIEW.md`)**](./CRITICAL-FEATURES-REVIEW.md) - Audio engine features, chapter marks, bookmarking, and offline download caching.
- [**UI/UX Benchmark & Liquid Glass (`UI-UX-BENCHMARK.md`)**](./UI-UX-BENCHMARK.md) - Design standards, spring physics, dynamic cover art palette extraction, and glassmorphism.
- [**Native iOS Quickstart (`native-ios-quickstart.md`)**](./native-ios-quickstart.md) - Local development setup, Xcode schemes, and simulator workflows.
- [**Build & Release Checklist (`BUILD-CHECKLIST.md`)**](./BUILD-CHECKLIST.md) - Pre-release validation, App Store Connect distribution, and signing.
- [**Maestro E2E Testing (`MAESTRO.md`)**](./MAESTRO.md) - Automated end-to-end user flows and testing commands.

---

## 🚀 Quick Reference Commands

```bash
# Verify Swift Package manifest
swift package describe

# Vendor or update agent skills
bash scripts/update-agent-skills.sh

# Build & validate with Skip
skip check
```
