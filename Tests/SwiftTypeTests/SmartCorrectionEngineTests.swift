import XCTest
@testable import SwiftTypeCore

final class SmartCorrectionEngineTests: XCTestCase {
    var db: SQLiteDatabase!
    var dicts: BuiltinDictionaries!
    var engine: SmartCorrectionEngine!

    override func setUpWithError() throws {
        try super.setUpWithError()
        db = try SQLiteDatabase.inMemory()
        dicts = BuiltinDictionaries(database: db)
        engine = SmartCorrectionEngine(database: db, dictionaries: dicts)
        engine.prepareIndexIfNeeded()
    }

    override func tearDownWithError() throws {
        db = nil
        dicts = nil
        engine = nil
        try super.tearDownWithError()
    }

    func testExactMatchNoCorrectionNeeded() {
        // "swiftui" is in programming dictionary, should return nil (no replacement needed)
        let result = engine.evaluate(word: "swiftui", threshold: 0.95)
        XCTAssertNil(result)

        // "the" is in english dictionary
        let resultThe = engine.evaluate(word: "the", threshold: 0.95)
        XCTAssertNil(resultThe)
    }

    func testSureIsNotCorrectedToWere() {
        XCTAssertNil(engine.evaluate(word: "sure", threshold: 0.95))
        XCTAssertNil(engine.evaluate(word: "Sure", threshold: 0.95))
    }

    func testSecnodCorrectsToSecond() {
        let candidate = engine.evaluate(word: "Secnod", threshold: 0.95)
        XCTAssertNotNil(candidate)
        XCTAssertEqual(candidate?.word, "Second")
    }

    func testCommonMisspellingsFlaggedBySystemSpellchecker() {
        let typos: [String: String] = [
            "goign": "going",
            "Whay": "What",
            "Whar": "What",
            "thier": "their",
            "becasue": "because",
            "definitly": "definitely"
        ]

        for (typo, expected) in typos {
            let candidate = engine.evaluate(word: typo, threshold: 0.95)
            XCTAssertNotNil(candidate, "Typo '\(typo)' should be corrected")
            XCTAssertEqual(candidate?.word, expected)
        }
    }

    func testExternalSpellcheckerCandidatesAreRanked() {
        let candidate = engine.evaluate(word: "speling", threshold: 0.95, externalCandidates: ["spelling"])
        XCTAssertNotNil(candidate)
        XCTAssertEqual(candidate?.word, "spelling")
        XCTAssertEqual(candidate?.sourceStage, "Stage0_AppleSpell")
    }

    func testCommonTypoExemptions() {
        let typos: [String: String] = [
            "teh": "the",
            "becuase": "because",
            "garabage": "garbage",
            "reccomend": "recommend",
            "definately": "definitely",
            "adress": "address",
            "occured": "occurred",
            "acommodate": "accommodate"
        ]

        for (typo, expected) in typos {
            let candidate = engine.evaluate(word: typo, threshold: 0.90)
            XCTAssertNotNil(candidate, "Typo '\(typo)' should be corrected")
            XCTAssertEqual(candidate?.word.lowercased(), expected, "Typo '\(typo)' should correct to '\(expected)'")
            XCTAssertGreaterThanOrEqual(candidate?.confidence ?? 0.0, 0.90)
        }
    }

    func testTechnicalVocabularyRecognition() {
        let techWords = ["Swift", "Rust", "Python", "JavaScript", "TypeScript", "React", "SwiftUI", "Electron", "Docker", "Git", "GitHub", "Raycast", "Homebrew", "Hyprland", "Nextcloud", "PipeWire", "Wayland", "Linux", "macOS", "CachyOS", "Arch", "Fedora", "Obsidian", "SQLite", "PostgreSQL", "Redis"]

        for word in techWords {
            // Should not attempt to correct valid technical words to generic English words!
            let candidate = engine.evaluate(word: word, threshold: 0.95)
            XCTAssertNil(candidate, "Technical word '\(word)' should not be incorrectly replaced")
        }
    }

    func testContextValidationBoost() {
        // "in the garabage" -> garbage over garage
        let candidate = engine.evaluate(word: "garabage", contextBefore: ["in", "the"], threshold: 0.95)
        XCTAssertNotNil(candidate)
        XCTAssertEqual(candidate?.word.lowercased(), "garbage")
        XCTAssertGreaterThanOrEqual(candidate?.confidence ?? 0.0, 0.95)
    }

    func testUserFrequencyOverride() throws {
        // Simulate user typing Raycast 5000 times
        for _ in 0..<50 { // We insert + update normalized score
            try db.recordWordUsage("Raycast")
        }
        
        // When user types "Raycats" (1 transposition), user preference should boost Raycast
        let candidate = engine.evaluate(word: "Raycats", threshold: 0.85)
        XCTAssertNotNil(candidate)
        XCTAssertEqual(candidate?.word.lowercased(), "raycast")
    }

    func testIgnoreAndAlwaysReplaceRules() throws {
        try db.setIgnoreRule(for: "customtypo", type: .alwaysReplace, replacement: "customfixed")
        let forced = engine.evaluate(word: "customtypo")
        XCTAssertNotNil(forced)
        XCTAssertEqual(forced?.word, "customfixed")

        try db.setIgnoreRule(for: "neversuggestthis", type: .neverSuggest, replacement: nil)
        let ignored = engine.evaluate(word: "neversuggestthis")
        XCTAssertNil(ignored)
    }

    func testConfidenceThresholdSafety() {
        // Very low confidence threshold vs very high threshold
        let strict = engine.evaluate(word: "xyzabc123qwerty", threshold: 0.95)
        XCTAssertNil(strict, "Should never replace when confidence is below threshold")
    }

    func testCasePreservationAndAutoCapitalization() {
        // 1. All-uppercase typo preservation
        let allCaps = engine.evaluate(word: "TEH", threshold: 0.90)
        XCTAssertNotNil(allCaps)
        XCTAssertEqual(allCaps?.word, "THE")

        // 2. Title case typo preservation
        let titleCase = engine.evaluate(word: "Teh", threshold: 0.90)
        XCTAssertNotNil(titleCase)
        XCTAssertEqual(titleCase?.word, "The")

        // 3. Auto-capitalization at start of line/sentence for exact match
        let startOfLineExact = engine.evaluate(word: "the", threshold: 0.90, isStartOfSentenceOrLine: true)
        XCTAssertNotNil(startOfLineExact)
        XCTAssertEqual(startOfLineExact?.word, "The")
        XCTAssertEqual(startOfLineExact?.sourceStage, "AutoCapitalization")

        // 4. No auto-capitalization in the middle of a sentence for exact match
        let midSentenceExact = engine.evaluate(word: "the", threshold: 0.90, isStartOfSentenceOrLine: false)
        XCTAssertNil(midSentenceExact, "Exact match mid-sentence should not be replaced")
    }

    func testSingleLetterIAutoCapitalization() {
        let singleI = engine.evaluate(word: "i", threshold: 0.90, isStartOfSentenceOrLine: false)
        XCTAssertNotNil(singleI)
        XCTAssertEqual(singleI?.word, "I")
    }
}
