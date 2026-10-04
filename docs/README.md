# Audiobookphile Documentation

Welcome to the Audiobookphile app documentation! This directory contains all planning, architecture, and development documentation.

---

## 📚 Documentation Index

### Planning & Strategy

- **[Native iOS Strategy](./native-ios-strategy.md)** - Complete strategy for developing native iOS app
- **[Implementation Plan](./plan/native-ios-implementation.md)** - Technical implementation details
- **[Task Breakdown](./plan/task-breakdown.md)** - Detailed task checklist
- **[Build Walkthrough](./plan/build-walkthrough.md)** - Step-by-step component guide
- **[UI-UX Benchmark](./UI-UX-BENCHMARK.md)** - Parity guidelines from the official Capacitor app
- **[AI Agent Context](./AGENTS.md)** - Instructions, guidelines, and constraints for AI coding assistants


### Code Examples

- **[Native iOS Example](./native-ios-example/)** - Complete Swift/SwiftUI code examples
  - Liquid Glass design system
  - ProMotion 120Hz support
  - Metal GPU acceleration
  - Audio player UI
  - Library views
  - Core models

---

## 🎯 Quick Links

### Current Hybrid App (Android)

- Repository: `audiobookphile-app/`
- Technology: Nuxt.js + Capacitor
- Distribution: Google Play Store
- Status: ✅ Active development

### Planned Native iOS App

- Repository: TBD (`audiobookphile-ios/` recommended)
- Technology: Swift + SwiftUI
- Distribution: Apple App Store
- Status: 📋 Planning complete, ready for development

---

## 🚀 Getting Started

### For Android Development

See main [README.md](../readme.md) in repository root.

### For iOS Native Development

1. **Read the strategy:**

   ```bash
   open docs/native-ios-strategy.md
   ```

2. **Review example code:**

   ```bash
   cd docs/native-ios-example
   # Open any .swift file in Xcode to see live previews
   ```

3. **Check implementation plan:**
   ```bash
   open docs/plan/native-ios-implementation.md
   ```

---

## 📂 Directory Structure

```
docs/
├── README.md                          # This file
├── native-ios-strategy.md             # iOS development strategy
│
├── plan/                              # Detailed planning docs
│   ├── native-ios-implementation.md   # Tech specs & architecture
│   ├── task-breakdown.md              # Task checklist
│   └── build-walkthrough.md           # Component walkthrough
│
└── native-ios-example/                # Swift code examples
    ├── README.md                      # Code documentation
    ├── Components/
    │   ├── LiquidGlass/              # Glass design system
    │   ├── Effects/                   # Advanced effects
    │   └── Books/                     # Book components
    ├── Core/
    │   ├── Graphics/                  # Metal rendering
    │   └── Animation/                 # ProMotion support
    ├── Features/
    │   ├── Player/                    # Audio player
    │   └── Library/                   # Library views
    └── Models/                        # Data models
```

---

## 🎨 Key Technologies

### Current App (Android)

- Nuxt.js 2.15.7
- Vue.js
- Capacitor 7.0
- Ionic UI components
- Tailwind CSS

### Native iOS App

- Swift 5.9+
- SwiftUI
- Metal (GPU acceleration)
- AVFoundation (audio)
- ProMotion (120Hz)
- Core Data (storage)

---

## 📊 Development Status

### Completed ✅

- [x] Native iOS strategy documented
- [x] Architecture planned
- [x] Liquid Glass design system created
- [x] ProMotion support implemented
- [x] Metal rendering foundation built
- [x] Core models defined
- [x] Audio player UI designed
- [x] Library views created
- [x] Example code repository (~3,600 lines)

### Next Steps 📋

- [ ] Create full Xcode project
- [ ] Implement API client
- [ ] Build AVFoundation audio service
- [ ] Add download manager
- [ ] Integrate WebSocket
- [ ] Add unit tests
- [ ] TestFlight beta
- [ ] App Store submission

---

## 🤝 Contributing

### For Android App

See main repository guidelines.

### For Native iOS App

Documentation being prepared. Main focus areas:

1. SwiftUI best practices
2. MVVM architecture
3. Performance optimization
4. Accessibility
5. Testing

---

## 📝 Version History

### Current

- **v0.11.0-beta** - Hybrid app (Nuxt + Capacitor)
- Android: Active development
- iOS: TestFlight (beta full)

### Planned

- **v1.0.0** - Native iOS app
- Separate App Store release
- Full feature parity with Android
- iOS-exclusive features (CarPlay, Widgets, etc.)

---

## 📞 Resources

### Documentation

- [Audiobookphile Backend](https://github.com/Audiobookphile/audiobookphile-backend)
- [Audiobookphile API](https://api.audiobookphile.org/)
- [Swift Documentation](https://swift.org/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)

### Community

- [Discord](https://discord.gg/pJsjuNCKRq)
- [Website](https://audiobookphile.org)

---

## 🎯 Goals

### Technical Excellence

- ✨ Beautiful, modern UI (Liquid Glass design)
- ⚡ High performance (120fps, <0.5s startup)
- 📱 Native platform integration
- 🔒 Security & privacy first
- ♿ Accessibility compliant

### User Experience

- 🎵 Seamless audio playback
- 📚 Easy library management
- 💾 Offline downloads
- 🔄 Cross-device sync
- 🚀 Smooth animations

### Distribution

- 📲 App Store (iOS)
- 🤖 Google Play (Android)
- 🆓 Free & open source

---

_Documentation maintained by development team_ _Last updated: December 21, 2024_
