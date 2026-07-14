import Foundation
import Combine

/// Service that coordinates application statistics and metrics tracking with SQLiteDatabase.
public final class StatisticsService: ObservableObject, @unchecked Sendable {
    private let db: SQLiteDatabase
    private let lock = NSLock()

    @Published public private(set) var snapshot: StatisticsSnapshot

    public init(database: SQLiteDatabase) {
        self.db = database
        self.snapshot = database.getStatistics()
    }

    public func refresh() {
        lock.lock()
        let fresh = db.getStatistics()
        lock.unlock()
        DispatchQueue.main.async {
            self.snapshot = fresh
        }
    }

    public func recordCorrection(latencyMs: Double, learnedWord: Bool = false) {
        lock.lock()
        try? db.recordCorrectionEvent(latencyMs: latencyMs, learnedWord: learnedWord)
        let fresh = db.getStatistics()
        lock.unlock()
        
        DispatchQueue.main.async {
            self.snapshot = fresh
        }
    }

    public func recordFalseCorrection() {
        lock.lock()
        try? db.incrementFalseCorrections()
        let fresh = db.getStatistics()
        lock.unlock()
        
        DispatchQueue.main.async {
            self.snapshot = fresh
        }
    }
}
