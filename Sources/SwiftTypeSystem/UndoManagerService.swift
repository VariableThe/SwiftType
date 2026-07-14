import Foundation
import AppKit
import SwiftTypeCore

/// Service managing recent correction history and immediate `Cmd+Z` restoration.
public final class UndoManagerService: @unchecked Sendable {
    public static let shared = UndoManagerService()
    private let lock = NSLock()

    private var lastCorrection: (id: Int64, originalWord: String, correctedWord: String, completionChar: String, timestamp: TimeInterval)?
    private let undoWindowSeconds: TimeInterval = 10.0 // Allow Cmd+Z within 10 seconds of correction

    public init() {}

    /// Records a successful correction event for immediate undo capability.
    public func recordCorrection(id: Int64, originalWord: String, correctedWord: String, completionChar: String) {
        lock.lock()
        defer { lock.unlock() }
        self.lastCorrection = (id, originalWord, correctedWord, completionChar, Date().timeIntervalSince1970)
    }

    /// Clears recent correction state when user types a non-undo keystroke or moves cursor away.
    public func clearRecentCorrection() {
        lock.lock()
        defer { lock.unlock() }
        self.lastCorrection = nil
    }

    /// Checks if a correction was performed recently and is eligible for immediate `Cmd+Z` undo.
    public var hasUndoableCorrection: Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let item = lastCorrection else { return false }
        return (Date().timeIntervalSince1970 - item.timestamp) <= undoWindowSeconds
    }

    /// Reverts the most recent autocorrect replacement back to the original word.
    public func revertLatestCorrection(database: SQLiteDatabase, statistics: StatisticsService, coordinator: AccessibilityCoordinator = .shared) -> Bool {
        lock.lock()
        guard let item = lastCorrection else {
            lock.unlock()
            return false
        }
        self.lastCorrection = nil
        lock.unlock()

        // We need to replace `correctedWord` + `completionChar` with `originalWord` + `completionChar`
        let success = coordinator.replaceWordInstantaneous(
            originalLength: item.correctedWord.count,
            correctedWord: item.originalWord,
            completionChar: item.completionChar,
            useSimulatedKeystrokes: true
        )

        if success {
            try? database.markHistoryUndone(id: item.id)
            statistics.recordFalseCorrection()
        }
        return success
    }
}
