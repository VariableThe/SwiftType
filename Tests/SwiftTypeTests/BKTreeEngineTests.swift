import XCTest
@testable import SwiftTypeCore

final class BKTreeEngineTests: XCTestCase {
    var bkTree: BKTreeEngine!

    override func setUp() {
        super.setUp()
        bkTree = BKTreeEngine()
    }

    override func tearDown() {
        bkTree.clear()
        bkTree = nil
        super.tearDown()
    }

    func testBatchInsertAndSearch() {
        let words = ["garbage", "garage", "garden", "guardian", "swift", "rust"]
        bkTree.insertBatch(words)

        let matches = bkTree.search(query: "garabage", maxDistance: 2)
        let matchedWords = Set(matches.map { $0.word })
        XCTAssertTrue(matchedWords.contains("garbage"))
        XCTAssertTrue(matchedWords.contains("garage"))
    }

    func testExactAndOutofBounds() {
        bkTree.insert("raycast")
        let exact = bkTree.search(query: "raycast", maxDistance: 2)
        XCTAssertEqual(exact.first?.word, "raycast")
        XCTAssertEqual(exact.first?.distance, 0)

        let far = bkTree.search(query: "completelydifferentword", maxDistance: 2)
        XCTAssertTrue(far.isEmpty)
    }
}
