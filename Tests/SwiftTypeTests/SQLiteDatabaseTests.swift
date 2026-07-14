import XCTest
@testable import SwiftTypeCore

final class SQLiteDatabaseTests: XCTestCase {
    var db: SQLiteDatabase!

    override func setUpWithError() throws {
        try super.setUpWithError()
        db = try SQLiteDatabase.inMemory()
    }

    override func tearDownWithError() throws {
        db = nil
        try super.tearDownWithError()
    }

    func testInMemoryInitialization() throws {
        XCTAssertNotNil(db)
        XCTAssertEqual(db.databasePath, ":memory:")
    }

    func testWordInsertionAndQuery() throws {
        try db.insertWord("swiftui", dictionary: "Programming", frequency: 500)
        try db.insertWord("apple", dictionary: "English", frequency: 1000)

        XCTAssertEqual(db.getWordFrequency("swiftui"), 500)
        XCTAssertEqual(db.getWordFrequency("SWIFTUI"), 500) // Case-insensitive storage check
        XCTAssertTrue(db.containsWord("swiftui"))
        XCTAssertFalse(db.containsWord("nonexistentword"))

        let programmingWords = db.allWords(inDictionary: "Programming")
        XCTAssertEqual(programmingWords, ["swiftui"])
    }

    func testUserWordsCRUD() throws {
        try db.addUserWord("raycats")
        XCTAssertTrue(db.containsWord("raycats"))
        XCTAssertEqual(db.getAllUserWords(), ["raycats"])

        try db.incrementUserWordUseCount("raycats")
        
        try db.removeUserWord("raycats")
        XCTAssertFalse(db.containsWord("raycats"))
        XCTAssertTrue(db.getAllUserWords().isEmpty)
    }

    func testUserFrequencyTracking() throws {
        XCTAssertEqual(db.getUserFrequencyCount("raycast"), 0)
        try db.recordWordUsage("Raycast")
        try db.recordWordUsage("raycast")
        try db.recordWordUsage("Raycast")
        XCTAssertEqual(db.getUserFrequencyCount("raycast"), 3)
    }

    func testIgnoredRules() throws {
        try db.setIgnoreRule(for: "teh", type: .alwaysReplace, replacement: "the")
        try db.setIgnoreRule(for: "foobar", type: .neverSuggest, replacement: nil)

        let tehRule = db.getIgnoreRule(for: "teh")
        XCTAssertNotNil(tehRule)
        XCTAssertEqual(tehRule?.type, .alwaysReplace)
        XCTAssertEqual(tehRule?.replacement, "the")

        let foobarRule = db.getIgnoreRule(for: "foobar")
        XCTAssertEqual(foobarRule?.type, .neverSuggest)
        XCTAssertNil(foobarRule?.replacement)

        let allIgnored = db.getAllIgnoredWords()
        XCTAssertEqual(allIgnored.count, 2)

        try db.removeIgnoreRule(for: "teh")
        XCTAssertNil(db.getIgnoreRule(for: "teh"))
    }

    func testHistoryAndUndo() throws {
        let id1 = try db.recordHistory(originalWord: "teh", correctedWord: "the")
        let id2 = try db.recordHistory(originalWord: "becuase", correctedWord: "because")

        XCTAssertTrue(id2 > id1)

        let latest = db.getLatestHistoryItem()
        XCTAssertNotNil(latest)
        XCTAssertEqual(latest?.originalWord, "becuase")
        XCTAssertEqual(latest?.correctedWord, "because")
        XCTAssertFalse(latest?.undone ?? true)

        try db.markHistoryUndone(id: id2)
        let updatedLatest = db.getLatestHistoryItem()
        XCTAssertTrue(updatedLatest?.undone ?? false)

        let recent = db.getRecentHistory(limit: 10)
        XCTAssertEqual(recent.count, 2)
    }

    func testStatisticsUpdating() throws {
        let initial = db.getStatistics()
        XCTAssertEqual(initial.correctionsToday, 0)
        XCTAssertEqual(initial.correctionsLifetime, 0)

        try db.recordCorrectionEvent(latencyMs: 1.5, learnedWord: true)
        try db.recordCorrectionEvent(latencyMs: 2.5, learnedWord: false)
        try db.incrementFalseCorrections()

        let updated = db.getStatistics()
        XCTAssertEqual(updated.correctionsToday, 2)
        XCTAssertEqual(updated.correctionsLifetime, 2)
        XCTAssertEqual(updated.wordsLearned, 1)
        XCTAssertEqual(updated.falseCorrections, 1)
        XCTAssertEqual(updated.totalLatencyCount, 2)
        XCTAssertEqual(updated.totalLatencyMs, 4.0, accuracy: 0.001)
        XCTAssertEqual(updated.averageLatencyMs, 2.0, accuracy: 0.001)
        XCTAssertEqual(updated.accuracyPercentage, 50.0, accuracy: 0.001)
    }

    func testSettingsCRUD() throws {
        try db.setSetting(key: "testKey", value: "testValue")
        XCTAssertEqual(db.getSetting(key: "testKey"), "testValue")
        XCTAssertNil(db.getSetting(key: "missingKey"))
    }

    func testTransactionsAndRollbacks() throws {
        do {
            try db.transaction {
                try db.insertWord("txword1", dictionary: "Tx")
                try db.insertWord("txword2", dictionary: "Tx")
                throw SQLiteError.notFound // trigger rollback
            }
        } catch {
            // Expected throw
        }
        XCTAssertFalse(db.containsWord("txword1"))
        XCTAssertFalse(db.containsWord("txword2"))

        try db.transaction {
            try db.insertWord("txword3", dictionary: "Tx")
        }
        XCTAssertTrue(db.containsWord("txword3"))
    }
}
