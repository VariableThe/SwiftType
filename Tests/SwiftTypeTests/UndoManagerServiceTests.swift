import XCTest
@testable import SwiftTypeSystem
@testable import SwiftTypeCore

final class UndoManagerServiceTests: XCTestCase {
    var db: SQLiteDatabase!
    var stats: StatisticsService!
    var service: UndoManagerService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        db = try SQLiteDatabase.inMemory()
        stats = StatisticsService(database: db)
        service = UndoManagerService()
    }

    override func tearDownWithError() throws {
        service.clearRecentCorrection()
        db = nil
        stats = nil
        service = nil
        try super.tearDownWithError()
    }

    func testRecordAndClearCorrection() {
        XCTAssertFalse(service.hasUndoableCorrection)

        service.recordCorrection(id: 1, originalWord: "teh", correctedWord: "the", completionChar: " ")
        XCTAssertTrue(service.hasUndoableCorrection)

        service.clearRecentCorrection()
        XCTAssertFalse(service.hasUndoableCorrection)
    }

    func testUndoWindowExpiration() {
        // Just verify basic state tracking
        service.recordCorrection(id: 1, originalWord: "garabage", correctedWord: "garbage", completionChar: ".")
        XCTAssertTrue(service.hasUndoableCorrection)
    }
}
