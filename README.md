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

- **macOS 13.0 Ventura** or later (macOS 15.0 Sequoia recommended)
- **Xcode 16.0+** / **Swift 6.0+ Toolchain** (`swift --version`) if compiling from source

---

## 📦 Installation

### Option 1: Homebrew Cask (Recommended)

You can easily install SwiftType via our Homebrew tap:

```bash
brew tap VariableThe/SwiftType https://github.com/VariableThe/SwiftType
brew install --cask swifttype
```

Our Homebrew Cask automatically clears macOS Gatekeeper quarantine flags (`xattr -cr`) during postflight installation.

### Option 2: Manual Download (`.zip`)

1. Download the latest `SwiftType.zip` release from [GitHub Releases](https://github.com/VariableThe/SwiftType/releases).
2. Unzip the archive and move `SwiftType.app` to your `/Applications` folder:
   ```bash
   unzip SwiftType.zip
   mv build/SwiftType.app /Applications/
   ```
3. **Clear macOS Gatekeeper Quarantine (`xattr`)**:
   Because SwiftType is distributed as a self-hosted binary outside the Mac App Store, macOS Gatekeeper may flag it. Run the following terminal command to remove the quarantine attribute before launching:
   ```bash
   xattr -cr /Applications/SwiftType.app
   ```
4. Launch SwiftType:
   ```bash
   open /Applications/SwiftType.app
   ```

### Option 3: Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/VariableThe/SwiftType.git
   cd SwiftType
   ```

2. Build and bundle the macOS application using our build script:
   ```bash
   chmod +x scripts/bundle_app.sh
   ./scripts/bundle_app.sh 1.0.0
   ```
   This will produce `build/SwiftType.app` and `build/SwiftType.zip`.

3. Run directly or move `build/SwiftType.app` to `/Applications/`.

---

### Granting Accessibility Permissions

Upon first launch, SwiftType will display an onboarding window prompting you to grant **Accessibility (`AXIsProcessTrusted`)** permissions in `System Settings -> Privacy & Security -> Accessibility`. This permission is strictly required for `CGEventTap` to observe typed characters and `AXUIElement` to replace misspelled words instantaneously across macOS.

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
