import Foundation
import SQLite3

/// Error types for SQLite operations.
public enum SQLiteError: Error, LocalizedError, Equatable {
    case openFailed(Int32, String)
    case prepareFailed(Int32, String)
    case executeFailed(Int32, String)
    case bindFailed(Int32, String)
    case notFound
    
    public var errorDescription: String? {
        switch self {
        case .openFailed(let code, let msg): return "SQLite open failed (\(code)): \(msg)"
        case .prepareFailed(let code, let msg): return "SQLite prepare failed (\(code)): \(msg)"
        case .executeFailed(let code, let msg): return "SQLite execute failed (\(code)): \(msg)"
        case .bindFailed(let code, let msg): return "SQLite bind failed (\(code)): \(msg)"
        case .notFound: return "SQLite record not found"
        }
    }
}

/// Represents an ignored or forced replacement rule.
public enum IgnoreType: String, Sendable, Codable {
    case once = "once"
    case forever = "forever"
    case neverSuggest = "never_suggest"
    case alwaysReplace = "always_replace"
}

/// Models for History and Statistics records.
public struct CorrectionHistoryItem: Sendable, Identifiable, Equatable {
    public let id: Int64
    public let originalWord: String
    public let correctedWord: String
    public let timestamp: TimeInterval
    public var undone: Bool

    public init(id: Int64 = 0, originalWord: String, correctedWord: String, timestamp: TimeInterval = Date().timeIntervalSince1970, undone: Bool = false) {
        self.id = id
        self.originalWord = originalWord
        self.correctedWord = correctedWord
        self.timestamp = timestamp
        self.undone = undone
    }
}

public struct StatisticsSnapshot: Sendable, Equatable {
    public var correctionsToday: Int
    public var correctionsLifetime: Int
    public var wordsLearned: Int
    public var falseCorrections: Int
    public var totalLatencyMs: Double
    public var totalLatencyCount: Int
    public var lastDate: String
    
    public var averageLatencyMs: Double {
        guard totalLatencyCount > 0 else { return 0.0 }
        return totalLatencyMs / Double(totalLatencyCount)
    }
    
    public var accuracyPercentage: Double {
        guard correctionsLifetime > 0 else { return 100.0 }
        let correct = max(0, correctionsLifetime - falseCorrections)
        return (Double(correct) / Double(correctionsLifetime)) * 100.0
    }
    
    public var totalCorrections: Int { correctionsLifetime }
    public var totalKeystrokesSaved: Int { correctionsLifetime * 3 }
    public var estimatedSecondsSaved: Double { Double(totalKeystrokesSaved) * 0.2 }
    public var estimatedWPMBoost: Double {
        guard correctionsLifetime > 0 else { return 0.0 }
        return min(25.0, Double(correctionsLifetime) * 0.05)
    }
    
    public init(correctionsToday: Int = 0, correctionsLifetime: Int = 0, wordsLearned: Int = 0, falseCorrections: Int = 0, totalLatencyMs: Double = 0.0, totalLatencyCount: Int = 0, lastDate: String = "") {
        self.correctionsToday = correctionsToday
        self.correctionsLifetime = correctionsLifetime
        self.wordsLearned = wordsLearned
        self.falseCorrections = falseCorrections
        self.totalLatencyMs = totalLatencyMs
        self.totalLatencyCount = totalLatencyCount
        self.lastDate = lastDate
    }
}

/// High-performance, thread-safe wrapper around C `sqlite3` for SwiftType storage.
public final class SQLiteDatabase: @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()
    public let databasePath: String

    public init(path: String? = nil) throws {
        if let path = path {
            self.databasePath = path
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let swiftTypeDir = appSupport.appendingPathComponent("SwiftType", isDirectory: true)
            try FileManager.default.createDirectory(at: swiftTypeDir, withIntermediateDirectories: true)
            self.databasePath = swiftTypeDir.appendingPathComponent("swifttype.sqlite").path
        }
        try openDatabase()
        try createTables()
        try configureOptimizations()
    }

    /// Initializes an in-memory database ideal for unit tests.
    public static func inMemory() throws -> SQLiteDatabase {
        try SQLiteDatabase(path: ":memory:")
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    private func openDatabase() throws {
        var opDb: OpaquePointer?
        let status = sqlite3_open(databasePath, &opDb)
        guard status == SQLITE_OK, let opDb = opDb else {
            let msg = opDb != nil ? String(cString: sqlite3_errmsg(opDb)) : "Unknown open error"
            if opDb != nil { sqlite3_close(opDb) }
            throw SQLiteError.openFailed(status, msg)
        }
        self.db = opDb
    }

    private func configureOptimizations() throws {
        try execute("PRAGMA journal_mode = WAL;")
        try execute("PRAGMA synchronous = NORMAL;")
        try execute("PRAGMA cache_size = -10000;") // ~10MB cache
    }

    private func createTables() throws {
        let schema = """
        CREATE TABLE IF NOT EXISTS Words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT UNIQUE NOT NULL,
            dictionary TEXT NOT NULL,
            frequency INTEGER DEFAULT 1
        );
        CREATE INDEX IF NOT EXISTS idx_words_word ON Words(word);
        CREATE INDEX IF NOT EXISTS idx_words_dict ON Words(dictionary);

        CREATE TABLE IF NOT EXISTS Frequency (
            word TEXT PRIMARY KEY,
            count INTEGER DEFAULT 1,
            normalized_score REAL DEFAULT 0.0
        );

        CREATE TABLE IF NOT EXISTS Corrections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            typo TEXT UNIQUE NOT NULL,
            correction TEXT NOT NULL,
            confidence REAL DEFAULT 1.0
        );
        CREATE INDEX IF NOT EXISTS idx_corrections_typo ON Corrections(typo);

        CREATE TABLE IF NOT EXISTS Ignored (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT UNIQUE NOT NULL,
            ignore_type TEXT NOT NULL,
            replacement_word TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_ignored_word ON Ignored(word);

        CREATE TABLE IF NOT EXISTS UserWords (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT UNIQUE NOT NULL,
            added_at REAL NOT NULL,
            use_count INTEGER DEFAULT 1
        );
        CREATE INDEX IF NOT EXISTS idx_userwords_word ON UserWords(word);

        CREATE TABLE IF NOT EXISTS Statistics (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            corrections_today INTEGER DEFAULT 0,
            corrections_lifetime INTEGER DEFAULT 0,
            words_learned INTEGER DEFAULT 0,
            false_corrections INTEGER DEFAULT 0,
            total_latency_ms REAL DEFAULT 0.0,
            total_latency_count INTEGER DEFAULT 0,
            last_date TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS History (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            original_word TEXT NOT NULL,
            corrected_word TEXT NOT NULL,
            timestamp REAL NOT NULL,
            undone INTEGER DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_history_timestamp ON History(timestamp DESC);

        CREATE TABLE IF NOT EXISTS Settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        INSERT OR IGNORE INTO Statistics (id, corrections_today, corrections_lifetime, words_learned, false_corrections, total_latency_ms, total_latency_count, last_date)
        VALUES (1, 0, 0, 0, 0, 0.0, 0, date('now'));
        """
        try execute(schema)
    }

    public func execute(_ sql: String) throws {
        lock.lock()
        defer { lock.unlock() }
        var errMsg: UnsafeMutablePointer<Int8>?
        let status = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if status != SQLITE_OK {
            let msg = errMsg != nil ? String(cString: errMsg!) : "Unknown exec error"
            if errMsg != nil { sqlite3_free(errMsg) }
            throw SQLiteError.executeFailed(status, msg)
        }
    }

    // MARK: - Transaction Helper
    public func transaction(_ block: () throws -> Void) throws {
        try execute("BEGIN TRANSACTION;")
        do {
            try block()
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    // MARK: - Words / Built-in & Dictionary storage
    public func insertWord(_ word: String, dictionary: String, frequency: Int = 1) throws {
        let sql = "INSERT OR REPLACE INTO Words (word, dictionary, frequency) VALUES (?, ?, ?);"
        try runQuery(sql, bindings: [word.lowercased(), dictionary, frequency])
    }

    public func getWordFrequency(_ word: String) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        let sql = "SELECT frequency FROM Words WHERE word = ?;"
        guard let stmt = prepareStatement(sql) else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (word.lowercased() as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int64(stmt, 0))
        }
        return nil
    }

    public func containsWord(_ word: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let lower = word.lowercased()
        // Check UserWords first, then Words
        let sql = "SELECT 1 FROM UserWords WHERE word = ? UNION SELECT 1 FROM Words WHERE word = ? LIMIT 1;"
        guard let stmt = prepareStatement(sql) else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (lower as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, (lower as NSString).utf8String, -1, SQLITE_TRANSIENT)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    public func allWords(inDictionary dictionary: String? = nil) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        var results = [String]()
        let sql = dictionary != nil ? "SELECT word FROM Words WHERE dictionary = ?;" : "SELECT word FROM Words;"
        guard let stmt = prepareStatement(sql) else { return results }
        defer { sqlite3_finalize(stmt) }
        if let dict = dictionary {
            sqlite3_bind_text(stmt, 1, (dict as NSString).utf8String, -1, SQLITE_TRANSIENT)
        }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cStr = sqlite3_column_text(stmt, 0) {
                results.append(String(cString: cStr))
            }
        }
        return results
    }

    // MARK: - UserWords (Personal Dictionary)
    public func addUserWord(_ word: String) throws {
        let sql = "INSERT OR REPLACE INTO UserWords (word, added_at, use_count) VALUES (?, ?, 1);"
        try runQuery(sql, bindings: [word.lowercased(), Date().timeIntervalSince1970])
    }

    public func removeUserWord(_ word: String) throws {
        let sql = "DELETE FROM UserWords WHERE word = ?;"
        try runQuery(sql, bindings: [word.lowercased()])
    }

    public func getAllUserWords() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        var results = [String]()
        let sql = "SELECT word FROM UserWords ORDER BY word ASC;"
        guard let stmt = prepareStatement(sql) else { return results }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cStr = sqlite3_column_text(stmt, 0) {
                results.append(String(cString: cStr))
            }
        }
        return results
    }

    public func incrementUserWordUseCount(_ word: String) throws {
        let sql = "UPDATE UserWords SET use_count = use_count + 1 WHERE word = ?;"
        try runQuery(sql, bindings: [word.lowercased()])
    }

    // MARK: - User Frequency Model (e.g. Raycast vs Raycats)
    public func recordWordUsage(_ word: String) throws {
        let lower = word.lowercased()
        let sql = """
        INSERT INTO Frequency (word, count, normalized_score) VALUES (?, 1, 1.0)
        ON CONFLICT(word) DO UPDATE SET count = count + 1, normalized_score = log(count + 1);
        """
        try runQuery(sql, bindings: [lower])
    }

    public func getUserFrequencyCount(_ word: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let sql = "SELECT count FROM Frequency WHERE word = ?;"
        guard let stmt = prepareStatement(sql) else { return 0 }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (word.lowercased() as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int64(stmt, 0))
        }
        return 0
    }

    // MARK: - Ignored Words & Always Replace Rules
    public func setIgnoreRule(for word: String, type: IgnoreType, replacement: String? = nil) throws {
        let sql = "INSERT OR REPLACE INTO Ignored (word, ignore_type, replacement_word) VALUES (?, ?, ?);"
        try runQuery(sql, bindings: [word.lowercased(), type.rawValue, replacement as Any])
    }

    public func getIgnoreRule(for word: String) -> (type: IgnoreType, replacement: String?)? {
        lock.lock()
        defer { lock.unlock() }
        let sql = "SELECT ignore_type, replacement_word FROM Ignored WHERE word = ?;"
        guard let stmt = prepareStatement(sql) else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (word.lowercased() as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_ROW {
            guard let typeStr = sqlite3_column_text(stmt, 0),
                  let type = IgnoreType(rawValue: String(cString: typeStr)) else { return nil }
            var repl: String? = nil
            if let replStr = sqlite3_column_text(stmt, 1) {
                repl = String(cString: replStr)
            }
            return (type, repl)
        }
        return nil
    }

    public func removeIgnoreRule(for word: String) throws {
        let sql = "DELETE FROM Ignored WHERE word = ?;"
        try runQuery(sql, bindings: [word.lowercased()])
    }

    public func getAllIgnoredWords() -> [(word: String, type: IgnoreType, replacement: String?)] {
        lock.lock()
        defer { lock.unlock() }
        var results = [(word: String, type: IgnoreType, replacement: String?)]()
        let sql = "SELECT word, ignore_type, replacement_word FROM Ignored ORDER BY word ASC;"
        guard let stmt = prepareStatement(sql) else { return results }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let wordStr = sqlite3_column_text(stmt, 0),
               let typeStr = sqlite3_column_text(stmt, 1),
               let type = IgnoreType(rawValue: String(cString: typeStr)) {
                let word = String(cString: wordStr)
                var repl: String? = nil
                if let replStr = sqlite3_column_text(stmt, 2) {
                    repl = String(cString: replStr)
                }
                results.append((word, type, repl))
            }
        }
        return results
    }

    // MARK: - Correction History & Undo
    public func recordHistory(originalWord: String, correctedWord: String, timestamp: TimeInterval = Date().timeIntervalSince1970) throws -> Int64 {
        let sql = "INSERT INTO History (original_word, corrected_word, timestamp, undone) VALUES (?, ?, ?, 0);"
        try runQuery(sql, bindings: [originalWord, correctedWord, timestamp])
        lock.lock()
        defer { lock.unlock() }
        return sqlite3_last_insert_rowid(db)
    }

    public func markHistoryUndone(id: Int64) throws {
        let sql = "UPDATE History SET undone = 1 WHERE id = ?;"
        try runQuery(sql, bindings: [id])
    }

    public func getLatestHistoryItem() -> CorrectionHistoryItem? {
        lock.lock()
        defer { lock.unlock() }
        let sql = "SELECT id, original_word, corrected_word, timestamp, undone FROM History ORDER BY id DESC LIMIT 1;"
        guard let stmt = prepareStatement(sql) else { return nil }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return CorrectionHistoryItem(
                id: sqlite3_column_int64(stmt, 0),
                originalWord: String(cString: sqlite3_column_text(stmt, 1)!),
                correctedWord: String(cString: sqlite3_column_text(stmt, 2)!),
                timestamp: sqlite3_column_double(stmt, 3),
                undone: sqlite3_column_int(stmt, 4) == 1
            )
        }
        return nil
    }

    public func getRecentHistory(limit: Int = 50) -> [CorrectionHistoryItem] {
        lock.lock()
        defer { lock.unlock() }
        var results = [CorrectionHistoryItem]()
        let sql = "SELECT id, original_word, corrected_word, timestamp, undone FROM History ORDER BY id DESC LIMIT \(limit);"
        guard let stmt = prepareStatement(sql) else { return results }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(CorrectionHistoryItem(
                id: sqlite3_column_int64(stmt, 0),
                originalWord: String(cString: sqlite3_column_text(stmt, 1)!),
                correctedWord: String(cString: sqlite3_column_text(stmt, 2)!),
                timestamp: sqlite3_column_double(stmt, 3),
                undone: sqlite3_column_int(stmt, 4) == 1
            ))
        }
        return results
    }

    // MARK: - Statistics
    public func getStatistics() -> StatisticsSnapshot {
        lock.lock()
        defer { lock.unlock() }
        let sql = "SELECT corrections_today, corrections_lifetime, words_learned, false_corrections, total_latency_ms, total_latency_count, last_date FROM Statistics WHERE id = 1;"
        guard let stmt = prepareStatement(sql) else { return StatisticsSnapshot() }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return StatisticsSnapshot(
                correctionsToday: Int(sqlite3_column_int64(stmt, 0)),
                correctionsLifetime: Int(sqlite3_column_int64(stmt, 1)),
                wordsLearned: Int(sqlite3_column_int64(stmt, 2)),
                falseCorrections: Int(sqlite3_column_int64(stmt, 3)),
                totalLatencyMs: sqlite3_column_double(stmt, 4),
                totalLatencyCount: Int(sqlite3_column_int64(stmt, 5)),
                lastDate: String(cString: sqlite3_column_text(stmt, 6)!)
            )
        }
        return StatisticsSnapshot()
    }

    public func recordCorrectionEvent(latencyMs: Double, learnedWord: Bool = false) throws {
        let formatter = ISO8601DateFormatter()
        let today = String(formatter.string(from: Date()).prefix(10))
        let stats = getStatistics()
        
        let newToday = (stats.lastDate == today) ? stats.correctionsToday + 1 : 1
        let newLifetime = stats.correctionsLifetime + 1
        let newLearned = learnedWord ? stats.wordsLearned + 1 : stats.wordsLearned
        let newTotalMs = stats.totalLatencyMs + latencyMs
        let newCount = stats.totalLatencyCount + 1

        let sql = """
        UPDATE Statistics SET
            corrections_today = ?,
            corrections_lifetime = ?,
            words_learned = ?,
            total_latency_ms = ?,
            total_latency_count = ?,
            last_date = ?
        WHERE id = 1;
        """
        try runQuery(sql, bindings: [newToday, newLifetime, newLearned, newTotalMs, newCount, today])
    }

    public func incrementFalseCorrections() throws {
        let sql = "UPDATE Statistics SET false_corrections = false_corrections + 1 WHERE id = 1;"
        try runQuery(sql, bindings: [])
    }

    // MARK: - Settings
    public func setSetting(key: String, value: String) throws {
        let sql = "INSERT OR REPLACE INTO Settings (key, value) VALUES (?, ?);"
        try runQuery(sql, bindings: [key, value])
    }

    public func getSetting(key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        let sql = "SELECT value FROM Settings WHERE key = ?;"
        guard let stmt = prepareStatement(sql) else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_ROW {
            if let cStr = sqlite3_column_text(stmt, 0) {
                return String(cString: cStr)
            }
        }
        return nil
    }

    // MARK: - Private Helpers
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private func prepareStatement(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            return stmt
        }
        return nil
    }

    private func runQuery(_ sql: String, bindings: [Any]) throws {
        lock.lock()
        defer { lock.unlock() }
        var stmt: OpaquePointer?
        let prepStatus = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard prepStatus == SQLITE_OK, let stmt = stmt else {
            let msg = db != nil ? String(cString: sqlite3_errmsg(db)) : "Prepare failed"
            if stmt != nil { sqlite3_finalize(stmt) }
            throw SQLiteError.prepareFailed(prepStatus, msg)
        }
        defer { sqlite3_finalize(stmt) }

        for (index, binding) in bindings.enumerated() {
            let col = Int32(index + 1)
            if let str = binding as? String {
                sqlite3_bind_text(stmt, col, (str as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else if let int = binding as? Int {
                sqlite3_bind_int64(stmt, col, Int64(int))
            } else if let int64 = binding as? Int64 {
                sqlite3_bind_int64(stmt, col, int64)
            } else if let double = binding as? Double {
                sqlite3_bind_double(stmt, col, double)
            } else if isNil(binding) {
                sqlite3_bind_null(stmt, col)
            } else {
                sqlite3_bind_text(stmt, col, ("\(binding)" as NSString).utf8String, -1, SQLITE_TRANSIENT)
            }
        }

        let stepStatus = sqlite3_step(stmt)
        if stepStatus != SQLITE_DONE && stepStatus != SQLITE_ROW {
            let msg = db != nil ? String(cString: sqlite3_errmsg(db)) : "Execute failed"
            throw SQLiteError.executeFailed(stepStatus, msg)
        }
    }

    private func isNil(_ value: Any) -> Bool {
        if value is NSNull { return true }
        let mirror = Mirror(reflecting: value)
        return mirror.displayStyle == .optional && mirror.children.isEmpty
    }
}
