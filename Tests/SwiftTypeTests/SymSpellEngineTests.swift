import XCTest
@testable import SwiftTypeCore

final class SymSpellEngineTests: XCTestCase {
    var symSpell: SymSpellEngine!

    override func setUp() {
        super.setUp()
        symSpell = SymSpellEngine(maxEditDistance: 2)
    }

    override func tearDown() {
        symSpell.clear()
        symSpell = nil
        super.tearDown()
    }

    func testIndexingAndLookup() {
        let words = ["garbage", "apple", "swiftui", "recommend", "definitely"]
        symSpell.indexWords(words)

        // 1 edit distance
        let matchesGarabage = symSpell.lookup("garabage")
        XCTAssertTrue(matchesGarabage.contains("garbage"))

        // 2 edit distance
        let matchesSwftu = symSpell.lookup("swftu")
        XCTAssertTrue(matchesSwftu.contains("swiftui"))

        // Exact match
        let matchesApple = symSpell.lookup("apple")
        XCTAssertTrue(matchesApple.contains("apple"))
    }

    func testDynamicIndexWord() {
        symSpell.indexWord("raycast")
        let matches = symSpell.lookup("raycst")
        XCTAssertTrue(matches.contains("raycast"))
    }

    func testDamerauLevenshteinDistance() {
        XCTAssertEqual(SymSpellEngine.damerauLevenshteinDistance("teh", "the"), 1) // 1 transposition
        XCTAssertEqual(SymSpellEngine.damerauLevenshteinDistance("garbage", "garabage"), 1) // 1 insertion
        XCTAssertEqual(SymSpellEngine.damerauLevenshteinDistance("apple", "appl"), 1) // 1 deletion
        XCTAssertEqual(SymSpellEngine.damerauLevenshteinDistance("swift", "rust"), 4) // multiple subs
    }
}
