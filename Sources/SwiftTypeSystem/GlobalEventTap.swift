import Foundation
import AppKit
import ApplicationServices
import SwiftTypeCore

/// Global Quartz Event Tap monitoring keystrokes across all macOS applications.
public final class GlobalEventTap: @unchecked Sendable {
    public static let shared = GlobalEventTap()
    private let lock = NSLock()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false

    private var currentWordBuffer = ""
    private var contextHistory = [String]()
    private var isAtStartOfLineOrSentence: Bool = true
    
    public var engine: SmartCorrectionEngine?
    public var settings: SettingsManager?
    public var statistics: StatisticsService?
    public var autoLearning: AutoLearningManager?
    private let spellingGate = SystemSpellingGate()

    public init() {}

    public func configure(engine: SmartCorrectionEngine, settings: SettingsManager, statistics: StatisticsService, autoLearning: AutoLearningManager) {
        lock.lock()
        self.engine = engine
        self.settings = settings
        self.statistics = statistics
        self.autoLearning = autoLearning
        lock.unlock()
    }

    /// Starts monitoring global keyboard events if Accessibility permissions are granted.
    @discardableResult
    public func start() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if isRunning { return true }
        guard AccessibilityCoordinator.shared.isTrusted else { return false }

        let mask = (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: GlobalEventTap.eventCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return false
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.isRunning = true
        return true
    }

    /// Stops monitoring keyboard events.
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard isRunning, let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        self.eventTap = nil
        self.runLoopSource = nil
        self.isRunning = false
    }

    public var isMonitoring: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRunning
    }

    // MARK: - CGEvent Callback
    private static let eventCallback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
        let tap = Unmanaged<GlobalEventTap>.fromOpaque(refcon).takeUnretainedValue()
        return tap.handleEvent(proxy: proxy, type: type, event: event)
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let flags = event.flags
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)

        // 1. Check for immediate Cmd+Z (keycode 0x06 = Z)
        if flags.contains(.maskCommand) && keycode == 0x06 {
            if UndoManagerService.shared.hasUndoableCorrection,
               let db = engine?.database, let stats = statistics {
                let success = UndoManagerService.shared.revertLatestCorrection(database: db, statistics: stats)
                if success {
                    return nil // Consume Cmd+Z so active application doesn't double undo!
                }
            }
            clearBuffer()
            return Unmanaged.passUnretained(event)
        }

        // 2. Ignore other command/control/option shortcuts or navigation keys
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            clearBuffer()
            return Unmanaged.passUnretained(event)
        }

        // 3. Handle Backspace (0x33)
        if keycode == 0x33 {
            lock.lock()
            if !currentWordBuffer.isEmpty {
                currentWordBuffer.removeLast()
            }
            lock.unlock()
            UndoManagerService.shared.clearRecentCorrection()
            return Unmanaged.passUnretained(event)
        }

        // 4. Handle Escape (0x35) or Arrow keys (0x7B - 0x7E)
        if keycode == 0x35 || (keycode >= 0x7B && keycode <= 0x7E) {
            clearBuffer()
            return Unmanaged.passUnretained(event)
        }

        // 5. Decode unicode character
        var charBuffer = [UniChar](repeating: 0, count: 4)
        var actualLength = 0
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &actualLength, unicodeString: &charBuffer)
        guard actualLength > 0 else { return Unmanaged.passUnretained(event) }

        let chars = String(utf16CodeUnits: charBuffer, count: actualLength)
        guard let firstChar = chars.first else { return Unmanaged.passUnretained(event) }

        // 6. Check for completion triggers: Space, Tab, Return, period, comma, colon, semicolon, brackets, quotes
        let triggerSet: Set<Character> = [" ", "\t", "\r", "\n", ".", ",", ":", ";", ")", "]", "}", "\"", "'"]
        if triggerSet.contains(firstChar) {
            lock.lock()
            let wordToEvaluate = currentWordBuffer
            currentWordBuffer = ""
            let startOfLineOrSentence = isAtStartOfLineOrSentence || contextHistory.isEmpty || contextHistory.last?.hasSuffix(".") == true || contextHistory.last?.hasSuffix("!") == true || contextHistory.last?.hasSuffix("?") == true
            lock.unlock()

            if wordToEvaluate.count >= 1 {
                let startTime = DispatchTime.now()
                let spellingAssessment = spellingGate.assess(wordToEvaluate)
                if let engine = self.engine, let settings = self.settings {
                    let threshold = correctionThreshold(base: settings.confidenceThreshold, spellingAssessment: spellingAssessment)
                    let candidate = engine.evaluate(
                        word: wordToEvaluate,
                        contextBefore: contextHistory,
                        threshold: threshold,
                        isStartOfSentenceOrLine: startOfLineOrSentence,
                        externalCandidates: spellingAssessment.guesses
                    )
                    let best = acceptedCandidate(candidate, spellingAssessment: spellingAssessment)

                    if let best {
                    
                        let endTime = DispatchTime.now()
                        let latencyMs = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000.0

                        let completionStr = String(firstChar)
                        // Perform replacement
                        let replaced = AccessibilityCoordinator.shared.replaceWordInstantaneous(
                            originalLength: wordToEvaluate.count,
                            correctedWord: best.word,
                            completionChar: completionStr,
                            useSimulatedKeystrokes: true
                        )

                        if replaced {
                            if let id = try? engine.database.recordHistory(originalWord: wordToEvaluate, correctedWord: best.word) {
                                UndoManagerService.shared.recordCorrection(id: id, originalWord: wordToEvaluate, correctedWord: best.word, completionChar: completionStr)
                            }
                            statistics?.recordCorrection(latencyMs: latencyMs, learnedWord: false)
                            
                            lock.lock()
                            contextHistory.append(best.word)
                            if contextHistory.count > 5 { contextHistory.removeFirst() }
                            if firstChar == "\n" || firstChar == "\r" || firstChar == "." || firstChar == "!" || firstChar == "?" {
                                isAtStartOfLineOrSentence = true
                            } else {
                                isAtStartOfLineOrSentence = false
                            }
                            lock.unlock()

                            // Since our replacement via simulated keystrokes posted the completionStr already, we consume the original trigger event!
                            return nil
                        }
                    }
                }

                // No correction performed -> check auto-learning and transition state
                recordUncorrectedWord(wordToEvaluate, completionChar: firstChar)

                if wordToEvaluate.count >= 2 {
                    if spellingAssessment.status == .misspelled {
                        try? engine?.database.recordMissedCorrection(originalWord: wordToEvaluate, suggestions: spellingAssessment.guesses)
                    } else {
                        autoLearning?.observeUncorrectedWord(wordToEvaluate)
                    }
                }
            } else {
                lock.lock()
                if firstChar == "\n" || firstChar == "\r" || firstChar == "." || firstChar == "!" || firstChar == "?" {
                    isAtStartOfLineOrSentence = true
                }
                lock.unlock()
            }
            return Unmanaged.passUnretained(event)
        }

        // 7. Normal letter/digit typing -> append to buffer
        if firstChar.isLetter || firstChar.isNumber || firstChar == "-" || firstChar == "_" {
            lock.lock()
            currentWordBuffer.append(firstChar)
            if currentWordBuffer.count > 35 { currentWordBuffer.removeFirst() }
            lock.unlock()
            UndoManagerService.shared.clearRecentCorrection()
        } else {
            clearBuffer()
        }

        return Unmanaged.passUnretained(event)
    }

    private func clearBuffer() {
        lock.lock()
        currentWordBuffer = ""
        lock.unlock()
        UndoManagerService.shared.clearRecentCorrection()
    }

    private func recordUncorrectedWord(_ word: String, completionChar: Character) {
        lock.lock()
        if !word.isEmpty {
            contextHistory.append(word)
            if contextHistory.count > 5 { contextHistory.removeFirst() }
        }
        if completionChar == "\n" || completionChar == "\r" || completionChar == "." || completionChar == "!" || completionChar == "?" {
            isAtStartOfLineOrSentence = true
        } else {
            isAtStartOfLineOrSentence = false
        }
        lock.unlock()
    }

    private func correctionThreshold(base: Double, spellingAssessment: SystemSpellingAssessment) -> Double {
        switch spellingAssessment.status {
        case .misspelled:
            return base
        case .valid, .notCheckable:
            return max(base, 0.99)
        }
    }

    private func acceptedCandidate(_ candidate: CorrectionCandidate?, spellingAssessment: SystemSpellingAssessment) -> CorrectionCandidate? {
        guard let candidate else { return nil }
        switch spellingAssessment.status {
        case .misspelled:
            return candidate
        case .valid, .notCheckable:
            return isHighTrustWithoutSystemMisspelling(candidate) ? candidate : nil
        }
    }

    private func isHighTrustWithoutSystemMisspelling(_ candidate: CorrectionCandidate) -> Bool {
        switch candidate.sourceStage {
        case "IgnoreRule", "AutoCapitalization", "Stage1_ExactLookup":
            return candidate.confidence >= 0.99
        default:
            return false
        }
    }
}

private enum SystemSpellingStatus {
    case misspelled
    case valid
    case notCheckable
}

private struct SystemSpellingAssessment {
    let status: SystemSpellingStatus
    let guesses: [String]
}

private final class SystemSpellingGate {
    private let checker = NSSpellChecker.shared
    private let documentTag: Int
    private let lock = NSLock()
    private var cache = [String: SystemSpellingAssessment]()
    private var cacheOrder = [String]()
    private let maxCacheSize = 512

    init() {
        self.documentTag = NSSpellChecker.uniqueSpellDocumentTag()
    }

    func assess(_ word: String) -> SystemSpellingAssessment {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { return SystemSpellingAssessment(status: .notCheckable, guesses: []) }
        guard clean.allSatisfy({ $0.isLetter }) else { return SystemSpellingAssessment(status: .notCheckable, guesses: []) }

        let key = clean.lowercased()
        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let nsRange = checker.checkSpelling(of: clean, startingAt: 0)
        let isMisspelled = nsRange.location != NSNotFound && nsRange.length > 0
        let guesses: [String]
        if isMisspelled {
            guesses = checker.guesses(
                forWordRange: NSRange(location: 0, length: (clean as NSString).length),
                in: clean,
                language: nil,
                inSpellDocumentWithTag: documentTag
            ) ?? []
        } else {
            guesses = []
        }
        let assessment = SystemSpellingAssessment(status: isMisspelled ? .misspelled : .valid, guesses: guesses)

        lock.lock()
        cache[key] = assessment
        cacheOrder.append(key)
        if cacheOrder.count > maxCacheSize {
            let removed = cacheOrder.removeFirst()
            cache.removeValue(forKey: removed)
        }
        lock.unlock()

        return assessment
    }
}
