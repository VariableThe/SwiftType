# SwiftType Developer Guide

Welcome to the **SwiftType** codebase! This guide covers development setup, testing strategies, debugging techniques, and best practices for extending the autocorrect engine.

---

## 1. Development Environment Setup

### Prerequisites
- **macOS 15.0 Sequoia** or later (running natively or in a virtual machine with full UI access).
- **Xcode 16.0+** with Swift 6.0 command-line tools installed (`xcode-select --install`).

### Repository Structure & Build Commands
SwiftType uses a standard Swift Package Manager project layout without xcodeproj clutter:

```bash
# Build all targets in Debug mode
swift build

# Run unit tests across all modules
swift test

# Build for Release with optimizations (-O)
swift build -c release
```

---

## 2. Debugging `CGEventTap` and `AXUIElement`

Because `CGEventTap` and `AXUIElement` interact directly with the macOS kernel and window server, special care is required when debugging:

### Accessibility Permissions (`AXIsProcessTrusted`)
When running `swift run SwiftType` or launching via Xcode debugger (`lldb`), macOS registers permissions against the exact binary path or Xcode/Terminal process.
- If event interception fails, open **System Settings -> Privacy & Security -> Accessibility**.
- Toggle off and back on the entry for your Terminal (`iTerm2` or `Terminal.app`) or `Xcode.app`.

### Debugging Event Taps without Freezing the System
If you set a breakpoint (`lldb`) inside `GlobalEventTap.eventTapCallback`, macOS will pause the entire event stream, which can freeze system keyboard input until the tap times out!
- **Best Practice**: Instead of blocking breakpoints inside the synchronous `eventTapCallback`, use non-blocking `OSLog` (`Logger`) or `print()` logging, or set breakpoints inside the asynchronous UI/Settings controllers (`MenuBarController`, `SettingsView`).

---

## 3. Adding New Specialized Vocabulary Dictionaries

SwiftType's dictionaries are defined cleanly inside `Sources/SwiftTypeCore/Engine/BuiltinDictionaries.swift`. To add a new domain module (e.g., *Legal & Financial*):

1. **Add Vocabulary Array**:
   Create a static array inside `BuiltinDictionaries`:
   ```swift
   public static let legalAndFinancialWords: [(word: String, freq: Int)] = [
       ("affidavit", 85000),
       ("amortization", 80000),
       ("fiduciary", 78000),
       ("jurisdiction", 92000),
       ("subpoena", 75000)
   ]
   ```

2. **Register inside `seedDefaults()`**:
   In `BuiltinDictionaries.seedDefaults()`, insert the array into the `Words` table with your new dictionary category tag:
   ```swift
   for entry in BuiltinDictionaries.legalAndFinancialWords {
       try? database.insertWord(entry.word, frequency: entry.freq, dictionary: "Legal")
   }
   ```

3. **Expose UI Toggle**:
   Add `enableLegalDict: Bool` property helper inside `SettingsManager.swift` and a corresponding toggle in `SettingsView.swift`.

---

## 4. Benchmarking Latency & Memory

SwiftType requires strict SLA adherence ($< 5\text{ms}$ latency and $< 100\text{MB}$ idle memory). When modifying core indexing algorithms (`SymSpellEngine` or `BKTreeEngine`), always run performance tests:

```bash
swift test --filter PerformanceBenchmarks
```

When implementing performance improvements, verify that lookup structures retain $O(1)$ average-case behavior and avoid heap allocation spikes during rapid keystroke bursts.
