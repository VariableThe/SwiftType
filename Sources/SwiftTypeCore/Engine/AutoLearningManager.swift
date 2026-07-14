import Foundation
import Combine

/// Represents an unknown word candidate that has reached the threshold for learning or suggestion.
public struct PendingWordSuggestion: Sendable, Identifiable, Equatable {
    public let id = UUID()
    public let word: String
    public let useCount: Int
    public let firstObserved: TimeInterval
}

/// Tracks uncorrected unknown words and coordinates automatic learning or user prompts after N successful uses.
public final class AutoLearningManager: ObservableObject, @unchecked Sendable {
    private let database: SQLiteDatabase
    private let settings: SettingsManager
    private let engine: SmartCorrectionEngine
    private let lock = NSLock()

    private var uncorrectedCounts = [String: (count: Int, firstObserved: TimeInterval)]()
    @Published public private(set) var pendingSuggestions = [PendingWordSuggestion]()

    public init(database: SQLiteDatabase, settings: SettingsManager, engine: SmartCorrectionEngine) {
        self.database = database
        self.settings = settings
        self.engine = engine
    }

    /// Observes a word typed by the user that was NOT corrected.
    /// If the word is unknown to the built-in and user dictionaries, tracks its frequency and triggers learning after N uses.
    public func observeUncorrectedWord(_ word: String) {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard clean.count >= 2 && clean.count <= 35 && clean.rangeOfCharacter(from: CharacterSet.letters.inverted) == nil else {
            return
        }

        // Check if word is already in database
        if database.containsWord(clean) {
            // Already known, record usage for user frequency model
            try? database.recordWordUsage(clean)
            return
        }

        lock.lock()
        let threshold = settings.learningThreshold
        let isAutoLearnEnabled = settings.enableLearning

        if let existing = uncorrectedCounts[clean] {
            let newCount = existing.count + 1
            uncorrectedCounts[clean] = (newCount, existing.firstObserved)
            
            if newCount >= threshold {
                // Remove from in-memory tracker once threshold is reached
                uncorrectedCounts.removeValue(forKey: clean)
                lock.unlock()

                if isAutoLearnEnabled {
                    learnWordAutomatically(clean)
                } else {
                    addPendingSuggestion(word: clean, count: newCount, firstObserved: existing.firstObserved)
                }
                return
            }
        } else {
            uncorrectedCounts[clean] = (1, Date().timeIntervalSince1970)
        }
        lock.unlock()
    }

    /// Automatically learns a word into UserWords and updates engine indexes.
    private func learnWordAutomatically(_ word: String) {
        try? database.addUserWord(word)
        try? database.recordWordUsage(word)
        engine.indexNewWord(word)

        // Record metrics
        try? database.recordCorrectionEvent(latencyMs: 0.1, learnedWord: true)
    }

    private func addPendingSuggestion(word: String, count: Int, firstObserved: TimeInterval) {
        DispatchQueue.main.async {
            if !self.pendingSuggestions.contains(where: { $0.word == word }) {
                self.pendingSuggestions.append(PendingWordSuggestion(word: word, useCount: count, firstObserved: firstObserved))
            }
        }
    }

    /// User explicitly approves a pending suggestion ("Add to Dictionary").
    public func approveSuggestion(_ suggestion: PendingWordSuggestion) {
        try? database.addUserWord(suggestion.word)
        try? database.recordWordUsage(suggestion.word)
        engine.indexNewWord(suggestion.word)
        try? database.recordCorrectionEvent(latencyMs: 0.1, learnedWord: true)

        DispatchQueue.main.async {
            self.pendingSuggestions.removeAll(where: { $0.id == suggestion.id })
        }
    }

    /// User dismisses/rejects a pending suggestion.
    public func dismissSuggestion(_ suggestion: PendingWordSuggestion) {
        DispatchQueue.main.async {
            self.pendingSuggestions.removeAll(where: { $0.id == suggestion.id })
        }
    }
}
