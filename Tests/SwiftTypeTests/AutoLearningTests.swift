import XCTest
@testable import SwiftTypeCore

final class AutoLearningTests: XCTestCase {
    var db: SQLiteDatabase!
    var dicts: BuiltinDictionaries!
    var settings: SettingsManager!
    var engine: SmartCorrectionEngine!
    var learningManager: AutoLearningManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        db = try SQLiteDatabase.inMemory()
        dicts = BuiltinDictionaries(database: db)
        settings = SettingsManager(database: db)
        engine = SmartCorrectionEngine(database: db, dictionaries: dicts)
        engine.prepareIndexIfNeeded()
        learningManager = AutoLearningManager(database: db, settings: settings, engine: engine)
    }

    override func tearDownWithError() throws {
        db = nil
        dicts = nil
        settings = nil
        engine = nil
        learningManager = nil
        try super.tearDownWithError()
    }

    func testAutoLearnAfterNThreshold() {
        settings.enableLearning = true
        settings.learningThreshold = 3

        let unknownWord = "mycustomslang"
        XCTAssertFalse(db.containsWord(unknownWord))

        learningManager.observeUncorrectedWord(unknownWord)
        XCTAssertFalse(db.containsWord(unknownWord))

        learningManager.observeUncorrectedWord(unknownWord)
        XCTAssertFalse(db.containsWord(unknownWord))

        // 3rd time triggers auto-learn!
        learningManager.observeUncorrectedWord(unknownWord)
        XCTAssertTrue(db.containsWord(unknownWord))
        XCTAssertTrue(db.getAllUserWords().contains(unknownWord))
    }

    @MainActor
    func testPendingSuggestionWhenAutoLearnDisabled() async throws {
        settings.enableLearning = false
        settings.learningThreshold = 2

        let unknownWord = "pendingword"
        learningManager.observeUncorrectedWord(unknownWord)
        learningManager.observeUncorrectedWord(unknownWord)

        try await Task.sleep(nanoseconds: 60_000_000) // 60ms for main queue dispatch

        XCTAssertEqual(learningManager.pendingSuggestions.count, 1)
        XCTAssertEqual(learningManager.pendingSuggestions.first?.word, unknownWord)
        XCTAssertFalse(db.containsWord(unknownWord))

        // User approves suggestion
        if let first = learningManager.pendingSuggestions.first {
            learningManager.approveSuggestion(first)
        }
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertTrue(db.containsWord(unknownWord))
    }
}
