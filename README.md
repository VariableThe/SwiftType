# SwiftType ⚡️

**Fast, Local, Intelligent, System-Wide Autocorrect for macOS.**

[![Swift 6](https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift)](https://swift.org)
[![Platform macOS](https://img.shields.io/badge/macOS-15.0%2B-000000?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![License MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg?style=flat-square)]()

SwiftType is a native, privacy-first macOS menu bar application engineered to provide instantaneous ($O(1)$) system-wide autocorrect comparable to modern smartphone keyboards (such as iOS and Gboard), but optimized for developers, technical writers, and power users on desktop macOS.

---

## ✨ Features

- **⚡️ Instantaneous Latency (< 5ms)**: Powered by a hybrid **Symmetric Delete (`SymSpell`)** $O(1)$ dictionary lookup and a **Burkhard-Keller (`BK-Tree`)** metric space engine.
- **🔒 Privacy-First & 100% Offline**: All keystroke monitoring, typo correction, and statistical learning run entirely locally on your machine. **Zero network calls. Zero telemetry.**
- **💻 Technical Vocabulary Modules**: Includes specialized dictionaries for:
  - **Programming & CLI**: `Swift`, `Rust`, `Python`, `Go`, `Docker`, `Git`, `Kubernetes`, `POSIX`
  - **Systems & Architecture**: `Wayland`, `Arch`, `Homebrew`, `SQLite`, `x86_64`, `ARM64`
  - **Scientific & Medical Terminology**: `genome`, `mitochondria`, `pLDDT`, `macrophage`
- **🧠 Adaptive Auto-Learning**: Automatically observes words you type frequently without correction and promotes them to your custom dictionary after a configurable threshold ($N$ uses).
- **↩️ Instant `Cmd+Z` Undo**: Tracks corrections in real-time. Pressing `Cmd+Z` within 5 seconds of an autocorrect event instantaneously restores your original typed text.
- **🛡 UI Element & Password Protection**: Automatically detects secure fields (`AXSecureTextField`) and bypasses monitoring on password inputs.
- **📊 Real-Time Performance Dashboard**: Track total keystrokes saved, estimated time/seconds gained, word accuracy percentage, and average correction latency.

---

## 🏗 Architecture Overview

SwiftType is organized into cleanly decoupled modules under Swift Package Manager (SPM):

```
SwiftType/
├── Sources/
│   ├── SwiftTypeCore/    # Engine, Dictionaries, SymSpell, BK-Tree, Models & SQLite Storage
│   ├── SwiftTypeSystem/  # Accessibility Coordinator (AXUIElement), GlobalEventTap (CGEventTap), UndoService
│   ├── SwiftTypeUI/      # MenuBarController, SettingsView, StatisticsDashboardView, OnboardingView
│   └── SwiftType/        # Application Entrypoint (@main SwiftTypeApp, AppDelegate)
└── Tests/
    └── SwiftTypeTests/   # Comprehensive XCTest Suite across all modules
```

For detailed technical design, mathematical ranking formulas, and pipeline stage breakdowns, see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## 🚀 Getting Started

### Prerequisites

- **macOS 15.0 Sequoia** or later
- **Xcode 16.0+** / **Swift 6.0+ Toolchain** (`swift --version`)

### Building & Running

1. Clone the repository:
   ```bash
   git clone https://github.com/aditya/SwiftType.git
   cd SwiftType
   ```

2. Build the project using Swift Package Manager:
   ```bash
   swift build -c release
   ```

3. Run the application:
   ```bash
   swift run SwiftType
   ```

4. **Grant Accessibility Permissions**:
   Upon first launch, SwiftType will display an onboarding window prompting you to grant **Accessibility (`AXIsProcessTrusted`)** permissions in `System Settings -> Privacy & Security -> Accessibility`. This permission is strictly required for `CGEventTap` to observe typed characters and `AXUIElement` to replace misspelled words.

---

## 🧪 Testing

SwiftType includes an exhaustive test suite covering database transactions, symmetric delete indexing, BK-Tree bounds, QWERTY key distances, undo expiration, and concurrent access:

```bash
swift test
```

---

## ⚙️ Configuration & Customization

Click the `⌨️` icon in your macOS menu bar to access:
- **Pause/Resume Autocorrect**: Quick toggle shortcut (`KeyEquivalent: t`).
- **Statistics Dashboard**: Visual overview of productivity gains (`KeyEquivalent: d`).
- **Settings & Preferences**: Customize confidence thresholds ($0.70 - 1.00$), specialized vocabulary toggles, user custom word lists, and auto-learning frequency rules (`KeyEquivalent: ,`).

---

## 🤝 Contributing

We welcome contributions from developers, technical writers, and keyboard enthusiasts! Please check out our [CONTRIBUTING.md](CONTRIBUTING.md) and [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) before opening issues or pull requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
