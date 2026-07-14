# Contributing to SwiftType

Thank you for your interest in contributing to **SwiftType**! We build fast, local, intelligent, system-wide autocorrect for macOS, and we love community collaboration.

---

## 1. Development Workflow & GitHub Flow

We strictly adhere to **GitHub Flow**:
1. **Fork & Clone**: Fork the repository on GitHub and clone your fork locally.
2. **Branch**: Never commit directly to `main`. Create a descriptive feature or bugfix branch:
   ```bash
   git checkout -b feature/support-colemak-layout
   # or
   git checkout -b fix/symspell-memory-leak
   ```
3. **Small, Atomic Commits**: Make focused, logically separated commits. Every commit must pass all builds (`swift build`) and unit tests (`swift test`).
4. **Conventional Commit Messages**: Follow the Conventional Commits format (`type(scope): description`):
   - `feat(engine): add Damerau-Levenshtein transposition check`
   - `fix(system): resolve accessibility permissions race on startup`
   - `docs(readme): update build prerequisite instructions`
   - `test(core): add edge cases for URL and email typo exemptions`
   - `refactor(ui): clean up menu bar status icon alignment`

---

## 2. Pull Request Guidelines

When opening a Pull Request against `main`, ensure your PR description includes:
- **Summary**: What does this PR accomplish and why?
- **Features / Fixes Implemented**: Bulleted breakdown of technical changes across modules.
- **Testing Performed**: Exact commands run (`swift test`) and any manual testing done on macOS.
- **Screenshots / GIFs**: Visual demonstrations of UI changes or menu bar behavior.
- **Future Improvements**: Any follow-up items or non-blocker optimizations.

---

## 3. Code Quality Standards

- **Swift 6 Strict Concurrency**: Ensure all code compiles cleanly under Swift 6 concurrency checking (`@Sendable`, `@MainActor`, `Sendable` protocols, actor isolation). Zero compiler warnings allowed.
- **Documentation & Docstrings**: Maintain comprehensive comments. Every public struct, class, enum, and method in `SwiftTypeCore` and `SwiftTypeSystem` must have a descriptive docstring (`///`).
- **Privacy First**: Never introduce external network requests, third-party analytics, or remote logging. All operations must remain 100% local and offline.
