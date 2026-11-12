---
name: liquid-glass-mobile
description: SwiftUI and Skip cross-platform patterns for the Liquid Glass aesthetic on iOS and Android.
---

# Liquid Glass Mobile Standards (Audiobookphile App)

The mobile client (`audiobookphile-app`) delivers a native Liquid Glass (LG) experience on iOS and Android via Swift and Skip.

## Key Principles

1. **Native Materials & Translucency**:
   - iOS: Utilize native `.ultraThinMaterial` and custom shaders in `Sources/Audiobookphile/LiquidGlass/`.
   - Android (Skip): Transpiles to equivalent Jetpack Compose surface brushes with blur fallbacks.
2. **Cross-Platform Safety (`BleedingEdgeModifiers.swift`)**:
   - Always wrap platform-specific APIs:
     ```swift
     #if os(iOS) && !SKIP
     // iOS native effect
     #elseif SKIP
     // Android Compose effect
     #endif
     ```
   - Use `SmartAsyncImage` for image loading with URLRequest caching.
3. **Dynamic Palette Extraction**:
   - Extract primary and secondary hues from cover art to drive background aura gradients (`FluidAuraBackground`).
4. **Haptics and Motion**:
   - Use `.applySensoryFeedback(trigger:)` for subtle tactile feedback during chapter scrubs and play/pause transitions.
